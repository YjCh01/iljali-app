from fastapi import (
    APIRouter,
    Depends,
    Header,
    HTTPException,
    Query,
    WebSocket,
    WebSocketDisconnect,
)
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import SessionLocal, get_db
from app.job_sync_models import JobApplicationRow
from app.routers.hiring import _assert_application_participant
from app.routers.job_board import _resolve_bearer
from app.services.auth_token_service import verify_token
from app.services.chat_message_service import (
    append_message as persist_message,
    clear_messages as clear_room_messages,
    list_messages,
)
from app.services.chat_realtime_hub import chat_realtime_hub
from app.services.push_dispatch_hooks import push_chat_message

router = APIRouter(prefix="/v1/chat-sync", tags=["chat-sync"])


def _assert_chat_participant(
    db: Session, application_id: str, authorization: str | None
) -> dict:
    payload = _resolve_bearer(authorization)
    row = db.get(JobApplicationRow, application_id)
    if row is None:
        raise HTTPException(status_code=404, detail="지원 내역을 찾을 수 없습니다.")
    _assert_application_participant(payload, row)
    return payload


class ChatMessageBody(BaseModel):
    sender_role: str = Field(description="seeker | employer | system")
    sender_name: str = ""
    body: str
    message_type: str = "text"


@router.websocket("/ws/{application_id}")
async def chat_websocket(
    websocket: WebSocket,
    application_id: str,
    role: str = Query(default="seeker"),
    token: str = Query(default=""),
):
    normalized = role.strip().lower()
    if normalized not in {"seeker", "employer", "system"}:
        normalized = "seeker"

    payload = verify_token(token) if token else None
    if payload is None:
        await websocket.close(code=4401)
        return
    db = SessionLocal()
    try:
        row = db.get(JobApplicationRow, application_id)
        if row is None:
            await websocket.close(code=4404)
            return
        try:
            _assert_application_participant(payload, row)
        except HTTPException:
            await websocket.close(code=4403)
            return
    finally:
        db.close()

    await chat_realtime_hub.connect(application_id, websocket)
    try:
        while True:
            raw = await websocket.receive_text()
            await chat_realtime_hub.handle_client_text(
                application_id, websocket, raw
            )
    except WebSocketDisconnect:
        await chat_realtime_hub.disconnect(application_id, websocket)


@router.get("/{application_id}/messages")
def get_messages(
    application_id: str,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    _assert_chat_participant(db, application_id, authorization)
    items = list_messages(db, application_id)
    return {"application_id": application_id, "messages": items}


_ALLOWED_SENDER_ROLES = {
    "seeker": {"seeker", "system"},
    "employer": {"employer", "system"},
    "corporate": {"employer", "system"},
}


@router.post("/{application_id}/messages")
async def append_message(
    application_id: str,
    body: ChatMessageBody,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _assert_chat_participant(db, application_id, authorization)
    member_type = str(payload.get("member_type", ""))
    allowed = _ALLOWED_SENDER_ROLES.get(member_type, set())
    if body.sender_role not in allowed:
        raise HTTPException(
            status_code=403, detail="본인 역할로만 메시지를 보낼 수 있습니다."
        )
    row = persist_message(
        db,
        application_id=application_id,
        sender_role=body.sender_role,
        sender_name=body.sender_name,
        body=body.body,
        message_type=body.message_type,
    )
    await chat_realtime_hub.broadcast_message(application_id, row)
    push_chat_message(db, application_id=application_id, message=row)
    return row


@router.delete("/{application_id}/messages")
def clear_messages(
    application_id: str,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    _assert_chat_participant(db, application_id, authorization)
    clear_room_messages(db, application_id)
    return {"cleared": True, "application_id": application_id}
