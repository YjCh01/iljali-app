"""QC DB 시드 — seeker 1000, 샘플 공고, 지원 분포.

Usage:
  cd server
  python scripts/seed_qc.py --seekers 1000
  python scripts/seed_qc.py --jobs fixtures/jobs.example.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.database import Base, SessionLocal, engine  # noqa: E402
from app.services.admin_ops_service import (  # noqa: E402
    bulk_import_jobs,
    distribute_applications,
    grant_wallet_credits,
    seed_employers,
    seed_qc_visual_scenario,
    seed_seekers,
)


def main() -> None:
    parser = argparse.ArgumentParser(description="Iljari QC seed")
    parser.add_argument("--seekers", type=int, default=0, help="가상 구직자 수")
    parser.add_argument("--jobs", type=str, default="", help="공고 JSON 경로")
    parser.add_argument("--wallet-brn", type=str, default="1000000001")
    parser.add_argument("--wallet-credits", type=int, default=30)
    parser.add_argument("--distribute-post", type=str, default="")
    parser.add_argument("--distribute-max", type=int, default=100)
    parser.add_argument(
        "--visual-scenario",
        action="store_true",
        help="테스트기업 알파 + QC구직자 0001 지원 시나리오",
    )
    args = parser.parse_args()

    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        if args.seekers > 0:
            result = seed_seekers(db, count=args.seekers)
            print(f"seekers: {result}")

        if args.jobs:
            path = Path(args.jobs)
            if not path.is_file():
                path = ROOT / "fixtures" / args.jobs
            payload = json.loads(path.read_text(encoding="utf-8"))
            posts = payload if isinstance(payload, list) else payload.get("posts", [])
            result = bulk_import_jobs(db, posts)
            print(f"jobs: {result}")

        if args.wallet_credits > 0 and args.wallet_brn:
            result = grant_wallet_credits(
                db,
                company_key=args.wallet_brn,
                package_credits=args.wallet_credits,
            )
            print(f"wallet: {result}")

        emp = seed_employers(db)
        print(f"employers: {emp}")

        if args.distribute_post:
            result = distribute_applications(
                db,
                post_id=args.distribute_post,
                max_applications=args.distribute_max,
            )
            print(f"applications: {result}")

        if args.visual_scenario:
            result = seed_qc_visual_scenario(db)
            print(f"visual_scenario: {result}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
