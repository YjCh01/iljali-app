"""FCM 디바이스 토큰·알림 설정."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class DevicePushTokenRow(Base):
    __tablename__ = "device_push_tokens"
    __table_args__ = (UniqueConstraint("fcm_token", name="uq_device_push_fcm_token"),)

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    member_email: Mapped[str] = mapped_column(String(200), index=True)
    member_type: Mapped[str] = mapped_column(String(16), default="seeker", index=True)
    fcm_token: Mapped[str] = mapped_column(Text)
    platform: Mapped[str] = mapped_column(String(16), default="web")
    chat_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    job_alerts_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    application_updates_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
