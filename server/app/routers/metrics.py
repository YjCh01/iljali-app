from datetime import datetime, timedelta, timezone

from fastapi import APIRouter

router = APIRouter(prefix="/metrics", tags=["metrics"])

_BASIC_COMMISSION = 10_000
_PACKAGE_PUSH_UNIT = 5_000


@router.get("/company/{company_key}/roi-summary")
def roi_summary(company_key: str):
    """MVP ROI 집계 — 패키지·출근 수수료 기준 (레거시 tier 제거)."""
    check_ins = 3
    commission = check_ins * _BASIC_COMMISSION
    baseline = check_ins * _BASIC_COMMISSION
    push_spend = 3 * _PACKAGE_PUSH_UNIT
    subscription = 0
    total = push_spend + subscription + commission
    labor_value = check_ins * 120_000
    roi_percent = ((labor_value - total) / total * 100) if total else 0.0
    return {
        "company_key": company_key,
        "period_label": "최근 30일",
        "applications": 4,
        "check_ins": check_ins,
        "push_spend_krw": push_spend,
        "subscription_spend_krw": subscription,
        "commission_spend_krw": commission,
        "total_spend_krw": total,
        "estimated_labor_value_krw": labor_value,
        "roi_percent": round(roi_percent, 1),
        "baseline_commission_per_check_in_krw": _BASIC_COMMISSION,
        "baseline_commission_total_krw": baseline,
        "commission_savings_vs_basic_krw": max(0, baseline - commission),
        "package_push_unit_krw": _PACKAGE_PUSH_UNIT,
    }


@router.get("/company/{company_key}/company-rating-summary")
def company_rating_summary(company_key: str):
    return {
        "company_key": company_key,
        "average_stars": 4.7,
        "review_count": 3,
        "top_tags": ["급여 약속 준수", "재채용 희망", "업무 설명 명확"],
        "display_stars": "4.7★ (3)",
    }


@router.get("/company/{company_key}/branches/roi")
def branch_roi(company_key: str):
    fee = _BASIC_COMMISSION
    rows = [
        ("강남센터", "매장", 2, 1),
        ("역삼허브", "매장", 1, 1),
        ("선릉센터", "매장", 1, 1),
    ]
    result = []
    for name, level, apps, check_ins in rows:
        commission = check_ins * fee
        baseline = check_ins * _BASIC_COMMISSION
        result.append(
            {
                "branch_name": name,
                "level_label": level,
                "applications": apps,
                "check_ins": check_ins,
                "commission_spend_krw": commission,
                "savings_vs_basic_krw": max(0, baseline - commission),
            }
        )
    return {"company_key": company_key, "branches": result}


@router.post("/company-ratings")
def submit_company_rating(body: dict):
    return {
        "id": f"cr_{int(datetime.now(tz=timezone.utc).timestamp())}",
        "company_key": body.get("company_key"),
        "stars": body.get("stars", 5),
        "saved_at": datetime.now(tz=timezone.utc).isoformat(),
    }
