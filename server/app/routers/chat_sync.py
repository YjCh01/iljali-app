from fastapi import APIRouter, Depends, Query, WebSocket, WebSocketDisconnect
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.services.chat_message_service import (
    append_message as persist_message,
    clear_messages as clear_room_messages,
    list_messages,
)
from app.services.chat_realtime_hub import chat_realtime_hub
from app.services.push_dispatch_hooks import push_chat_message

router = APIRouter(prefix="/v1/chat-sync", tags=["chat-sync"])


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
):
    normalized = role.strip().lower()
    if normalized not in {"seeker", "employer", "system"}:
        normalized = "seeker"
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
def get_messages(application_id: str, db: Session = Depends(get_db)):
    items = list_messages(db, application_id)
    return {"application_id": application_id, "messages": items}


@router.post("/{application_id}/messages")
async def append_message(
    application_id: str,
    body: ChatMessageBody,
    db: Session = Depends(get_db),
):
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
def clear_messages(application_id: str, db: Session = Depends(get_db)):
    clear_room_messages(db, application_id)
    return {"cleared": True, "application_id": application_id}
