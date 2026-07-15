"""어드민 증정 지갑·공고 entitlement 회수 (실서비스 정리)."""

from __future__ import annotations

import json
from uuid import uuid4

from sqlalchemy.orm import Session

from app.push_wallet_models import EmployerPushWalletRow
from app.qc_models import AdminAuditLogRow, JobPostEntitlementRow
from app.services.entitlement_service import normalize_brn
from app.services.push_wallet_service import get_or_create_wallet, wallet_to_response

QC_COMPANY_KEYS = frozenset({"1000000001", "1000000002"})


def _parse_detail(raw: str | None) -> dict:
    if not raw:
        return {}
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return parsed if isinstance(parsed, dict) else {}


def summarize_admin_wallet_grants(db: Session) -> dict[str, dict[str, int]]:
    """audit `wallet.grant` 합산 — company_key → 크레딧."""
    totals: dict[str, dict[str, int]] = {}
    rows = (
        db.query(AdminAuditLogRow)
        .filter(AdminAuditLogRow.action == "wallet.grant")
        .order_by(AdminAuditLogRow.created_at.asc())
        .all()
    )
    for row in rows:
        brn = normalize_brn(row.target_id)
        if not brn or brn in QC_COMPANY_KEYS:
            continue
        detail = _parse_detail(row.detail_json)
        bucket = totals.setdefault(
            brn,
            {
                "package_credits": 0,
                "shuttle_stop_credits": 0,
                "push_ticket_credits": 0,
                "location_slots": 0,
                "grant_events": 0,
            },
        )
        bucket["grant_events"] += 1
        package = int(detail.get("package_credits") or 0)
        shuttle = int(detail.get("shuttle_stop_credits") or 0)
        push = int(detail.get("push_ticket_credits") or 0)
        exposure_total = int(detail.get("exposure_total") or (package + shuttle))
        slots_raw = detail.get("location_slots")
        slots = int(slots_raw) if slots_raw is not None else exposure_total
        bucket["package_credits"] += package
        bucket["shuttle_stop_credits"] += shuttle
        bucket["push_ticket_credits"] += push
        bucket["location_slots"] += max(0, slots)
    return totals


def _admin_entitlement_post_ids(db: Session) -> dict[str, set[str]]:
    """audit `entitlement.*` 로 활성화된 공고 ID."""
    job_pins: set[str] = set()
    shuttles: set[str] = set()
    rows = (
        db.query(AdminAuditLogRow)
        .filter(AdminAuditLogRow.action.in_(["entitlement.job_pin", "entitlement.shuttle"]))
        .order_by(AdminAuditLogRow.created_at.asc())
        .all()
    )
    for row in rows:
        post_id = (row.target_id or "").strip()
        if not post_id or post_id.startswith("qc_"):
            continue
        detail = _parse_detail(row.detail_json)
        if row.action == "entitlement.job_pin":
            if detail.get("recruitment_pin_active") is True:
                job_pins.add(post_id)
            elif detail.get("recruitment_pin_active") is False:
                job_pins.discard(post_id)
        elif row.action == "entitlement.shuttle":
            if detail.get("shuttle_exposure_active") is True:
                shuttles.add(post_id)
            elif detail.get("shuttle_exposure_active") is False:
                shuttles.discard(post_id)
    return {"job_pin": job_pins, "shuttle": shuttles}


def revoke_admin_grants(db: Session, *, dry_run: bool = False) -> dict:
    """어드민 증정 지갑 크레딧·공고 entitlement 제거."""
    wallet_grants = summarize_admin_wallet_grants(db)
    entitlement_ids = _admin_entitlement_post_ids(db)

    wallet_changes: list[dict] = []
    for brn, grant in sorted(wallet_grants.items()):
        wallet = (
            db.query(EmployerPushWalletRow)
            .filter(EmployerPushWalletRow.company_key == brn)
            .first()
        )
        if wallet is None:
            continue
        exposure_revoke = grant["package_credits"] + grant["shuttle_stop_credits"]
        before = {
            "package_credits": wallet.package_credits,
            "push_ticket_credits": wallet.push_ticket_credits,
            "location_slots_from_packages": wallet.location_slots_from_packages,
        }
        after_package = max(0, wallet.package_credits - exposure_revoke)
        after_push = max(0, wallet.push_ticket_credits - grant["push_ticket_credits"])
        after_slots = max(0, wallet.location_slots_from_packages - grant["location_slots"])
        if (
            before["package_credits"] == after_package
            and before["push_ticket_credits"] == after_push
            and before["location_slots_from_packages"] == after_slots
        ):
            continue
        wallet_changes.append(
            {
                "company_key": brn,
                "before": before,
                "after": {
                    "package_credits": after_package,
                    "push_ticket_credits": after_push,
                    "location_slots_from_packages": after_slots,
                },
                "revoked": {
                    "package_credits": before["package_credits"] - after_package,
                    "push_ticket_credits": before["push_ticket_credits"] - after_push,
                    "location_slots_from_packages": before["location_slots_from_packages"]
                    - after_slots,
                },
                "grant_events": grant["grant_events"],
            }
        )
        if not dry_run:
            wallet.package_credits = after_package
            wallet.push_ticket_credits = after_push
            wallet.location_slots_from_packages = after_slots

    entitlement_changes: list[dict] = []
    affected_posts = entitlement_ids["job_pin"] | entitlement_ids["shuttle"]
    for post_id in sorted(affected_posts):
        row = db.get(JobPostEntitlementRow, post_id)
        if row is None:
            continue
        before = {
            "recruitment_pin_active": row.recruitment_pin_active,
            "shuttle_exposure_active": row.shuttle_exposure_active,
            "map_pin_tier": row.map_pin_tier,
        }
        clear_pin = post_id in entitlement_ids["job_pin"]
        clear_shuttle = post_id in entitlement_ids["shuttle"]
        if not clear_pin and not clear_shuttle:
            continue
        if (
            (not clear_pin or not row.recruitment_pin_active)
            and (not clear_shuttle or not row.shuttle_exposure_active)
            and (not clear_pin or not row.map_pin_tier)
        ):
            continue
        entitlement_changes.append(
            {
                "post_id": post_id,
                "before": before,
                "cleared_job_pin": clear_pin,
                "cleared_shuttle": clear_shuttle,
            }
        )
        if not dry_run:
            if clear_pin:
                row.recruitment_pin_active = False
                row.map_pin_tier = ""
            if clear_shuttle:
                row.shuttle_exposure_active = False

    result = {
        "dry_run": dry_run,
        "wallet_companies": len(wallet_changes),
        "wallet_changes": wallet_changes,
        "entitlement_posts": len(entitlement_changes),
        "entitlement_changes": entitlement_changes,
    }

    if dry_run:
        return result

    db.add(
        AdminAuditLogRow(
            id=f"audit_{uuid4().hex[:12]}",
            action="wallet.revoke_admin_grants",
            target_type="system",
            target_id="admin_grant_cleanup",
            detail_json=json.dumps(
                {
                    "wallet_companies": len(wallet_changes),
                    "entitlement_posts": len(entitlement_changes),
                },
                ensure_ascii=False,
            ),
        )
    )
    db.commit()
    return result


def wallet_snapshot(db: Session, company_key: str) -> dict:
    brn = normalize_brn(company_key)
    wallet = get_or_create_wallet(db, brn)
    db.commit()
    return wallet_to_response(brn, wallet, db).model_dump()
