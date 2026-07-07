from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy.orm import Session

from app.job_sync_models import ChatMessageRow


def row_to_dict(row: ChatMessageRow) -> dict:
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


def list_messages(db: Session, application_id: str) -> list[dict]:
    rows = (
        db.query(ChatMessageRow)
        .filter(ChatMessageRow.application_id == application_id)
        .order_by(ChatMessageRow.sent_at.asc())
        .all()
    )
    return [row_to_dict(row) for row in rows]


def append_message(
    db: Session,
    *,
    application_id: str,
    sender_role: str,
    sender_name: str = "",
    body: str,
    message_type: str = "text",
) -> dict:
    row = ChatMessageRow(
        id=f"msg_{uuid4().hex[:12]}",
        application_id=application_id,
        sender_role=sender_role,
        sender_name=sender_name,
        body=body,
        message_type=message_type,
        sent_at=datetime.now(timezone.utc).replace(tzinfo=None),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row_to_dict(row)


def clear_messages(db: Session, application_id: str) -> None:
    db.query(ChatMessageRow).filter(
        ChatMessageRow.application_id == application_id
    ).delete()
    db.commit()
