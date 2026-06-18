"""공고·지원·채팅·결제 원장 — SQLite/PostgreSQL 영속화."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class JobPostRow(Base):
    __tablename__ = "job_posts"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    title: Mapped[str] = mapped_column(String(200))
    company_name: Mapped[str] = mapped_column(String(200), default="")
    company_key: Mapped[str] = mapped_column(String(10), default="", index=True)
    warehouse_name: Mapped[str] = mapped_column(String(200), default="")
    hourly_wage: Mapped[str] = mapped_column(String(64), default="")
    work_schedule: Mapped[str] = mapped_column(String(128), default="")
    summary: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[str] = mapped_column(String(32), default="recruiting")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class JobApplicationRow(Base):
    __tablename__ = "job_applications"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    post_id: Mapped[str] = mapped_column(String(32), index=True)
    post_title: Mapped[str] = mapped_column(String(200), default="")
    company_name: Mapped[str] = mapped_column(String(200), default="")
    company_key: Mapped[str] = mapped_column(String(10), default="", index=True)
    seeker_email: Mapped[str] = mapped_column(String(200), index=True)
    seeker_name: Mapped[str] = mapped_column(String(100), default="")
    status: Mapped[str] = mapped_column(String(32), default="applied")
    work_schedule: Mapped[str] = mapped_column(String(128), default="")
    applied_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class ChatMessageRow(Base):
    __tablename__ = "chat_messages"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    application_id: Mapped[str] = mapped_column(String(32), index=True)
    sender_role: Mapped[str] = mapped_column(String(16))
    sender_name: Mapped[str] = mapped_column(String(100), default="")
    body: Mapped[str] = mapped_column(Text)
    message_type: Mapped[str] = mapped_column(String(16), default="text")
    sent_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class PaymentOrderRow(Base):
    __tablename__ = "payment_orders"

    order_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    company_key: Mapped[str | None] = mapped_column(String(10), nullable=True, index=True)
    order_name: Mapped[str] = mapped_column(String(200), default="")
    amount_krw: Mapped[int] = mapped_column(Integer)
    method: Mapped[str] = mapped_column(String(32), default="CARD")
    status: Mapped[str] = mapped_column(String(32), default="pending")
    payment_key: Mapped[str | None] = mapped_column(String(200), nullable=True)
    transaction_id: Mapped[str | None] = mapped_column(String(200), nullable=True)
    mock: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
