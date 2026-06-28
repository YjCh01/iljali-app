"""제재 정책 카탈로그 — 구인자(기업) 엄격 / 구직자 관대."""

from __future__ import annotations

from typing import Any

APPEAL_DAYS = 7

EMPLOYER_VIOLATIONS: dict[str, dict[str, Any]] = {
    "minor_false_ad": {
        "tier": "caution",
        "label": "허위 공고 문구",
        "examples": "과장 시급·근무조건 표현",
    },
    "slow_contact": {
        "tier": "caution",
        "label": "연락 지연",
    },
    "ignore_noshow": {
        "tier": "caution",
        "label": "No-show 무시",
    },
    "repeat_false_ad": {
        "tier": "warning",
        "label": "반복 허위 공고",
    },
    "discriminatory_hiring": {
        "tier": "warning",
        "label": "차별적 모집",
    },
    "contract_violation": {
        "tier": "warning",
        "label": "근로계약 위반",
    },
    "false_work_conditions": {
        "tier": "suspension",
        "label": "허위 근로조건",
        "default_days": 30,
    },
    "wage_theft": {
        "tier": "suspension",
        "label": "임금 체불",
        "default_days": 90,
    },
    "sexual_harassment": {
        "tier": "suspension",
        "label": "성희롱",
        "default_days": None,
        "permanent_default": True,
    },
    "illegal_dispatch": {
        "tier": "suspension",
        "label": "불법파견",
        "default_days": None,
        "permanent_default": True,
    },
}

SEEKER_VIOLATIONS: dict[str, dict[str, Any]] = {
    "noshow_1_2": {
        "tier": "caution",
        "label": "No-show 1~2회",
        "auto": True,
    },
    "fake_resume_light": {
        "tier": "caution",
        "label": "허위 이력서(경미)",
    },
    "inappropriate_chat": {
        "tier": "caution",
        "label": "부적절한 채팅",
    },
    "repeat_noshow": {
        "tier": "warning",
        "label": "반복 No-show",
        "auto": True,
    },
    "fake_resume_repeat": {
        "tier": "warning",
        "label": "반복 허위 이력서",
    },
    "harassment_chat": {
        "tier": "warning",
        "label": "욕설·성희롱",
    },
    "fake_identity": {
        "tier": "suspension",
        "label": "허위 신원",
        "default_days": 30,
    },
    "repeat_fraud": {
        "tier": "suspension",
        "label": "반복적 사기",
        "default_days": 90,
    },
    "sex_crime_related": {
        "tier": "suspension",
        "label": "성범죄 관련",
        "default_days": None,
        "permanent_default": True,
    },
}

TIER_MEASURES: dict[str, dict[str, dict[str, Any]]] = {
    "employer": {
        "caution": {
            "label": "주의 (1회)",
            "internal_alert": True,
            "job_exposure_limit_days": 1,
            "education_popup": True,
            "warning_increment": 1,
        },
        "warning": {
            "label": "경고 (2~3회 누적)",
            "job_exposure_limit_days": 7,
            "push_limit": True,
            "admin_review_required": True,
            "warning_increment": 1,
            "escalate_after_warnings": 3,
        },
        "suspension": {
            "label": "이용제재",
            "hide_all_posts": True,
            "no_refund": True,
            "default_days": 30,
        },
    },
    "seeker": {
        "caution": {
            "label": "주의 (1회)",
            "internal_alert": True,
            "apply_restriction_days": 3,
            "warning_increment": 1,
        },
        "warning": {
            "label": "경고 (3회 누적)",
            "apply_restriction_days": 14,
            "vault_limit": True,
            "push_limit": True,
            "warning_increment": 1,
            "escalate_after_warnings": 3,
        },
        "suspension": {
            "label": "이용제재",
            "default_days": 30,
        },
    },
}


def policy_catalog() -> dict:
    return {
        "appeal_days": APPEAL_DAYS,
        "employer": {
            "violations": EMPLOYER_VIOLATIONS,
            "tiers": TIER_MEASURES["employer"],
            "note": "구인자(기업) — 제재 기준 엄격 적용",
        },
        "seeker": {
            "violations": SEEKER_VIOLATIONS,
            "tiers": TIER_MEASURES["seeker"],
            "note": "구직자 — 상대적으로 관대, No-show·셔틀 연동 자동 경고",
        },
    }


def violation_catalog(member_kind: str) -> dict[str, dict]:
    if member_kind == "employer":
        return EMPLOYER_VIOLATIONS
    return SEEKER_VIOLATIONS


def tier_for_violation(member_kind: str, violation_code: str) -> str:
    catalog = violation_catalog(member_kind)
    item = catalog.get(violation_code)
    if item is None:
        raise ValueError(f"unknown violation: {violation_code}")
    return item["tier"]
