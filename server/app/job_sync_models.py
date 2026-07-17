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
    job_description: Mapped[str] = mapped_column(Text, default="")
    description_body_json: Mapped[str] = mapped_column(Text, default="{}")
    workplace_latitude: Mapped[float | None] = mapped_column(nullable=True)
    workplace_longitude: Mapped[float | None] = mapped_column(nullable=True)
    # 같은 물리적 근무지 식별 — 좌표/이름으로 매번 추측하지 않도록 resolve-or-create.
    workplace_id: Mapped[str | None] = mapped_column(String(32), nullable=True, index=True)
    # 지원 시 필수인 표준 자격증 id 목록(JSON 배열) — credential_definitions.id 참조.
    required_credential_ids_json: Mapped[str] = mapped_column(Text, default="[]")
    notification_settings_json: Mapped[str] = mapped_column(Text, default="{}")
    status: Mapped[str] = mapped_column(String(32), default="recruiting")
    posted_by_email: Mapped[str] = mapped_column(String(200), default="", index=True)
    posted_by_name: Mapped[str] = mapped_column(String(100), default="")
    view_count: Mapped[int] = mapped_column(Integer, default=0)
    map_impression_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class WorkplaceRow(Base):
    """같은 회사 내 물리적 근무지 — 좌표(~5m)·근무지명으로 resolve-or-create."""

    __tablename__ = "workplaces"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    company_key: Mapped[str] = mapped_column(String(10), default="", index=True)
    warehouse_name: Mapped[str] = mapped_column(String(200), default="")
    latitude: Mapped[float | None] = mapped_column(nullable=True)
    longitude: Mapped[float | None] = mapped_column(nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


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
    commute_route_id: Mapped[str] = mapped_column(String(64), default="", index=True)
    commute_route_name: Mapped[str] = mapped_column(String(200), default="")
    shuttle_stop_id: Mapped[str] = mapped_column(String(64), default="")
    shuttle_stop_label: Mapped[str] = mapped_column(String(200), default="")
    shuttle_pickup_time: Mapped[str] = mapped_column(String(32), default="")
    shuttle_shift_date: Mapped[str] = mapped_column(String(10), default="", index=True)
    # 지원 시점 스냅샷(JSON 배열) — 공고가 요구한 자격증 / 구직자가 보유한 자격증.
    required_credential_ids_json: Mapped[str] = mapped_column(Text, default="[]")
    held_credential_ids_json: Mapped[str] = mapped_column(Text, default="[]")
    applied_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    # 근무예정 합의 완료 시 확정된 근무일(YYYY-MM-DD) — 출근 1시간 전 리마인더 발송 기준.
    work_date: Mapped[str] = mapped_column(String(10), default="")
    work_reminder_sent_at: Mapped[datetime | None] = mapped_column(
        DateTime, nullable=True
    )
    # 면접 일정 상호 확인 완료 시에만 채워짐(ISO datetime) — 면접 1시간 전 리마인더 발송 기준.
    interview_at: Mapped[str] = mapped_column(String(32), default="")
    interview_reminder_sent_at: Mapped[datetime | None] = mapped_column(
        DateTime, nullable=True
    )
    # 셔틀 탑승 30분 전 리마인더 발송 기준(shuttle_pickup_time + shuttle_shift_date).
    shuttle_reminder_sent_at: Mapped[datetime | None] = mapped_column(
        DateTime, nullable=True
    )


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
    # 구매 의도 — confirmed 전환 시 이 정보로 지갑 크레딧을 자동 지급한다
    # (알림핀/PUSH 이용권 등 상품 종류에 무관하게 결제 confirm 한 곳에서만 지급).
    credit_type: Mapped[str | None] = mapped_column(String(32), nullable=True)
    credit_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    credit_location_slots: Mapped[int | None] = mapped_column(Integer, nullable=True)
    credit_granted: Mapped[bool] = mapped_column(Boolean, default=False)
