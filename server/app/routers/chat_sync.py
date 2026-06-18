from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.job_sync_models import ChatMessageRow

router = APIRouter(prefix="/v1/chat-sync", tags=["chat-sync"])


class ChatMessageBody(BaseModel):
    sender_role: str = Field(description="seeker | employer | system")
    sender_name: str = ""
    body: str
    message_type: str = "text"


def _row_to_dict(row: ChatMessageRow) -> dict:
    return {
        "id": row.id,
        "application_id": row.application_id,
        "sender_role": row.sender_role,
        "sender_name": row.sender_name,
        "body": row.body,
        "message_type": row.message_type,
        "sent_at": row.sent_at.replace(tzinfo=timezone.utc).isoformat()
        if row.sent_at
        else None,
    }


@router.get("/{application_id}/messages")
def list_messages(application_id: str, db: Session = Depends(get_db)):
    rows = (
        db.query(ChatMessageRow)
        .filter(ChatMessageRow.application_id == application_id)
        .order_by(ChatMessageRow.sent_at.asc())
        .all()
    )
    return {
        "application_id": application_id,
        "messages": [_row_to_dict(r) for r in rows],
    }


@router.post("/{application_id}/messages")
def append_message(
    application_id: str,
    body: ChatMessageBody,
    db: Session = Depends(get_db),
):
    row = ChatMessageRow(
        id=f"msg_{uuid4().hex[:12]}",
        application_id=application_id,
        sender_role=body.sender_role,
        sender_name=body.sender_name,
        body=body.body,
        message_type=body.message_type,
        sent_at=datetime.now(timezone.utc).replace(tzinfo=None),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return _row_to_dict(row)


@router.delete("/{application_id}/messages")
def clear_messages(application_id: str, db: Session = Depends(get_db)):
    db.query(ChatMessageRow).filter(
        ChatMessageRow.application_id == application_id
    ).delete()
    db.commit()
    return {"cleared": True, "application_id": application_id}
