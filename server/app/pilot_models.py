"""파일럿 프로그램 — 어드민 지정 참여자."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base

BUS_LOCATION_TOWER_KEY = "bus_location_tower"


class AppPilotProgramRow(Base):
    __tablename__ = "app_pilot_programs"

    program_key: Mapped[str] = mapped_column(String(64), primary_key=True)
    seeker_email: Mapped[str] = mapped_column(String(200), default="", index=True)
    company_key: Mapped[str] = mapped_column(String(10), default="", index=True)
    company_name: Mapped[str] = mapped_column(String(200), default="")
    route_id: Mapped[str] = mapped_column(String(64), default="", index=True)
    route_name: Mapped[str] = mapped_column(String(200), default="")
    enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    note: Mapped[str] = mapped_column(Text, default="")
    work_start_time: Mapped[str] = mapped_column(String(5), default="")
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class ShuttleOfficerRequestRow(Base):
    """기업의 버스위치 공유 담당 지정 요청 — 어드민 승인 후에만 실제 반영."""

    __tablename__ = "shuttle_officer_requests"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    company_key: Mapped[str] = mapped_column(String(10), default="", index=True)
    company_name: Mapped[str] = mapped_column(String(200), default="")
    route_id: Mapped[str] = mapped_column(String(64), default="", index=True)
    route_name: Mapped[str] = mapped_column(String(200), default="")
    seeker_email: Mapped[str] = mapped_column(String(200), default="", index=True)
    seeker_name: Mapped[str] = mapped_column(String(100), default="")
    work_start_time: Mapped[str] = mapped_column(String(5), default="")
    note: Mapped[str] = mapped_column(Text, default="")
    requested_by: Mapped[str] = mapped_column(String(200), default="")
    status: Mapped[str] = mapped_column(String(16), default="pending", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    reviewed_by: Mapped[str] = mapped_column(String(200), default="")


class BusLocationTowerSessionRow(Base):
    __tablename__ = "bus_location_tower_sessions"

    id: Mapped[str] = mapped_column(String(128), primary_key=True)
    service_date: Mapped[str] = mapped_column(String(10), index=True)
    company_key: Mapped[str] = mapped_column(String(10), default="", index=True)
    company_name: Mapped[str] = mapped_column(String(200), default="")
    route_id: Mapped[str] = mapped_column(String(64), default="", index=True)
    route_name: Mapped[str] = mapped_column(String(200), default="")
    driver_email: Mapped[str] = mapped_column(String(200), default="", index=True)
    driver_name: Mapped[str] = mapped_column(String(100), default="")
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    last_latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    last_longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    last_accuracy_m: Mapped[float | None] = mapped_column(Float, nullable=True)
    last_updated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    stopped_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    work_start_time: Mapped[str] = mapped_column(String(5), default="")
    arrived_at_workplace: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
