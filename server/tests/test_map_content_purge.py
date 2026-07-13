"""지도 콘텐츠 전체 삭제."""

from __future__ import annotations

from datetime import datetime

from app.database import Base, SessionLocal, engine
from app.job_sync_models import JobPostRow
from app.qc_models import ClosedGhostPinRow, ClosedGhostRouteRow
from app.services.map_content_purge_service import purge_map_content
from app.shuttle_models import CommuteRouteRow


def test_purge_map_content_deletes_posts_ghosts_routes():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        db.add(
            JobPostRow(
                id="post_wipe_1",
                title="wipe me",
                company_key="1234567890",
                company_name="test",
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow(),
            )
        )
        db.add(
            ClosedGhostPinRow(
                id="ghost_wipe_1",
                latitude=37.5,
                longitude=127.0,
                label="ghost",
                source_post_id="",
                created_at=datetime.utcnow(),
            )
        )
        db.add(
            ClosedGhostRouteRow(
                id="ghost_route_wipe_1",
                label="route",
                workplace_latitude=37.5,
                workplace_longitude=127.0,
                stops_json="[]",
                ghost_pin_id="",
                created_at=datetime.utcnow(),
            )
        )
        db.add(
            CommuteRouteRow(
                id="commute_wipe_1",
                company_key="1234567890",
                route_json="{}",
                active=True,
                updated_at=datetime.utcnow(),
            )
        )
        db.commit()

        dry = purge_map_content(db, dry_run=True)
        assert dry["dry_run"] is True
        assert dry["deleted"]["job_posts"] >= 1
        assert dry["deleted"]["closed_ghost_pins"] >= 1
        assert dry["deleted"]["closed_ghost_routes"] >= 1
        assert dry["deleted"]["commute_routes"] >= 1

        result = purge_map_content(db, dry_run=False)
        assert result["dry_run"] is False
        assert result["deleted"]["job_posts"] >= 1

        again = purge_map_content(db, dry_run=True)
        assert again["deleted"]["job_posts"] == 0
        assert again["deleted"]["closed_ghost_pins"] == 0
        assert again["deleted"]["closed_ghost_routes"] == 0
        assert again["deleted"]["commute_routes"] == 0
    finally:
        db.close()
