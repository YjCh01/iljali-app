"""QC·데모 DB 정리.

Usage:
  cd server
  python scripts/purge_qc_data.py --dry-run
  python scripts/purge_qc_data.py --yes
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.database import SessionLocal  # noqa: E402
from app.services.qc_data_purge_service import purge_qc_data  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description="Purge QC seed data from DB")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="삭제 대상 건수만 출력",
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="실제 삭제 실행",
    )
    args = parser.parse_args()

    if not args.dry_run and not args.yes:
        parser.error("Specify --dry-run or --yes")

    db = SessionLocal()
    try:
        result = purge_qc_data(db, dry_run=args.dry_run)
        print(result)
    finally:
        db.close()


if __name__ == "__main__":
    main()
