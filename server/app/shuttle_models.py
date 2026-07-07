"""통근 셔틀 — 노선·공유 동의·구직자 선택."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class CommuteRouteRow(Base):
    __tablename__ = "commute_routes"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    company_key: Mapped[str] = mapped_column(String(10), index=True)
    route_json: Mapped[str] = mapped_column(Text, default="{}")
    active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class ShuttleRouteShareConsentRow(Base):
    __tablename__ = "shuttle_route_share_consents"

    id: Mapped[str] = mapped_column(String(128), primary_key=True)
    seeker_email: Mapped[str] = mapped_column(String(200), index=True)
    company_key: Mapped[str] = mapped_column(String(10), index=True)
    company_name: Mapped[str] = mapped_column(String(200), default="")
    application_id: Mapped[str] = mapped_column(String(64), default="", index=True)
    offered_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    opted_in: Mapped[bool] = mapped_column(Boolean, default=False)
    tower_participation_consented: Mapped[bool] = mapped_column(Boolean, default=False)
    route_id: Mapped[str] = mapped_column(String(64), default="")
    stop_id: Mapped[str] = mapped_column(String(64), default="")
    pickup_time: Mapped[str] = mapped_column(String(5), default="")
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class SeekerShuttlePreferenceRow(Base):
    __tablename__ = "seeker_shuttle_preferences"

    id: Mapped[str] = mapped_column(String(256), primary_key=True)
    seeker_email: Mapped[str] = mapped_column(String(200), index=True)
    company_key: Mapped[str] = mapped_column(String(10), index=True)
    company_name: Mapped[str] = mapped_column(String(200), default="")
    route_id: Mapped[str] = mapped_column(String(64), default="")
    route_name: Mapped[str] = mapped_column(String(200), default="")
    stop_id: Mapped[str] = mapped_column(String(64), default="")
    stop_label: Mapped[str] = mapped_column(String(200), default="")
    pickup_time: Mapped[str] = mapped_column(String(8), default="")
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
