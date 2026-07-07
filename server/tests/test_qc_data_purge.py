from app.database import Base, SessionLocal, engine
from app.services.qc_data_purge_service import purge_qc_data


def test_purge_qc_dry_run_counts_seeded_fixture():
    from app.services.admin_ops_service import bulk_import_jobs, seed_employers, seed_seekers
    import json
    from pathlib import Path

    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        seed_employers(db)
        seed_seekers(db, count=2, start_index=1)
        fixtures = Path(__file__).resolve().parents[1] / "fixtures" / "jobs.example.json"
        posts = json.loads(fixtures.read_text(encoding="utf-8"))
        bulk_import_jobs(db, posts)

        preview = purge_qc_data(db, dry_run=True)
        counts = preview["counts"]
        assert counts["qc_members"] >= 10
        assert counts["job_posts"] >= 2

        result = purge_qc_data(db, dry_run=False)
        assert result["ok"] is True

        after = purge_qc_data(db, dry_run=True)
        assert after["counts"]["qc_members"] == 0
        assert after["counts"]["job_posts"] == 0
    finally:
        db.close()
