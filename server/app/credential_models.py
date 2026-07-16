"""자격증 표준 카탈로그 — 앱 재배포 없이 항목 추가 가능하도록 서버 DB化.

씨드 데이터는 lib/features/credential/domain/entities/credential_catalog.dart의
15종을 그대로 옮긴 것. 클라이언트는 이 목록을 오프라인 기본값으로 그대로 유지하고
앱 시작 시 이 API로 덮어쓴다."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class CredentialDefinitionRow(Base):
    __tablename__ = "credential_definitions"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    label: Mapped[str] = mapped_column(String(200))
    category: Mapped[str] = mapped_column(String(64))
    aliases_json: Mapped[str] = mapped_column(Text, default="[]")
    requires_photo: Mapped[bool] = mapped_column(Boolean, default=True)
    summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    guide_document_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )


# (id, label, category, aliases, requires_photo, summary, guide_document_id)
SEED_CREDENTIAL_DEFINITIONS: list[tuple] = [
    (
        "construction_safety_basic",
        "건설업 기초안전보건교육 이수증",
        "constructionManufacturing",
        ["건설안전", "기초안전보건", "안전교육", "4시간"],
        True,
        None,
        None,
    ),
    (
        "special_health_exam",
        "특수건강진단 결과서",
        "constructionManufacturing",
        ["특수검진", "배치전검진", "야간작업", "분진", "소음", "화학물질"],
        True,
        None,
        None,
    ),
    (
        "construction_machinery_license",
        "건설기계조종사 면허증",
        "constructionManufacturing",
        ["건설기계", "굴착기", "지게차", "조종사", "구청"],
        True,
        None,
        None,
    ),
    (
        "forklift_operator_cert",
        "지게차 운전기능사",
        "constructionManufacturing",
        ["지게차", "포크리프트", "기능사"],
        True,
        None,
        None,
    ),
    (
        "driving_career_certificate",
        "운전경력증명서 (전체 경력)",
        "logisticsDriving",
        ["운전경력", "경력증명", "경찰서", "음주운전", "사고이력", "지입"],
        True,
        None,
        None,
    ),
    (
        "freight_transport_license",
        "화물운송종사 자격증",
        "logisticsDriving",
        ["화물", "화물운송", "택배", "영업용", "교통안전공단"],
        True,
        None,
        None,
    ),
    (
        "bus_driver_license",
        "버스운전자격증",
        "logisticsDriving",
        ["버스", "버스운전", "승합", "통근버스"],
        True,
        None,
        None,
    ),
    (
        "cng_gas_safety_training",
        "CNG·고압가스 안전교육 이수증",
        "logisticsDriving",
        ["CNG", "압축천연가스", "고압가스", "가스버스"],
        True,
        None,
        None,
    ),
    (
        "statutory_facility_license",
        "법정 자격증 및 선임 이력",
        "facilitySecurity",
        ["전기기사", "소방설비", "공조냉동", "안전관리자", "선임", "시설관리"],
        True,
        None,
        None,
    ),
    (
        "security_guard_training",
        "일반경비원 신임교육 이수증",
        "facilitySecurity",
        ["경비", "경비원", "신임교육", "24시간", "보안"],
        True,
        None,
        None,
    ),
    (
        "criminal_record_consent",
        "범죄경력조회 동의서",
        "facilitySecurity",
        ["범죄경력", "성범죄", "아동학대", "경비채용"],
        False,
        "경비·시설 채용 시 범죄경력 확인 동의",
        "criminal_record_consent",
    ),
    (
        "latent_tb_screening",
        "잠복결핵 검진 결과서",
        "cleaningCare",
        ["잠복결핵", "결핵", "TB", "미화", "조리"],
        True,
        None,
        None,
    ),
    (
        "caregiver_cert",
        "요양보호사 자격증",
        "cleaningCare",
        ["요양", "요양보호", "돌봄"],
        True,
        None,
        None,
    ),
    (
        "childcare_teacher_cert",
        "보육교사 자격증",
        "cleaningCare",
        ["보육", "보육교사", "어린이집", "유치원"],
        True,
        None,
        None,
    ),
    (
        "health_certificate",
        "보건증 (건강진단결과서)",
        "foodService",
        [
            "보건",
            "보건증",
            "건강진단결과서",
            "건강진단",
            "건강증명서",
            "위생교육",
            "식품위생",
            "외식",
            "조리",
            "식품",
            "식품제조",
            "요식업",
            "HACCP",
            "감염병",
            "보건소",
            "e보건소",
        ],
        True,
        "식품·요식업 종사 필수 · e보건소·보건소·병원 발급",
        None,
    ),
]
