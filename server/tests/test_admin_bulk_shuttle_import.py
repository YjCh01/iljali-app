"""Admin bulk shuttle route import from Excel."""

from io import BytesIO
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from openpyxl import Workbook

from app.config import settings
from app.database import SessionLocal
from app.main import app
from app.shuttle_models import CommuteRouteRow

client = TestClient(app)
ADMIN_HEADERS = {"X-Admin-Api-Key": settings.admin_api_key}
COMPANY_KEY = "5403100894"


def _build_xlsx(rows: list[tuple]) -> bytes:
    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "노선입력"
    sheet.append(("노선명", "정류장순서", "정류장명", "도착시간", "주소"))
    for row in rows:
        sheet.append(row)
    buffer = BytesIO()
    workbook.save(buffer)
    return buffer.getvalue()


def _clear_routes(company_key: str) -> None:
    db = SessionLocal()
    try:
        db.query(CommuteRouteRow).filter(CommuteRouteRow.company_key == company_key).delete()
        db.commit()
    finally:
        db.close()


@patch(
    "app.services.admin_bulk_shuttle_import_service._geocode",
    return_value=(37.5, 127.0),
)
def test_bulk_import_shuttle_routes(mock_geocode):
    _clear_routes(COMPANY_KEY)
    payload = _build_xlsx(
        [
            ("1호차", 1, "강남역", "06:30", "서울 강남구"),
            ("1호차", 2, "근무지", "07:30", "경기 이천"),
            ("2호차", 1, "수원역", "05:50", "경기 수원"),
            ("2호차", 2, "근무지", "06:40", "경기 이천"),
        ]
    )
    response = client.post(
        "/v1/admin/ops/shuttle/routes/bulk-import",
        headers=ADMIN_HEADERS,
        data={"company_key": COMPANY_KEY},
        files={
            "file": (
                "routes.xlsx",
                payload,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
        },
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["submitted_routes"] == 2
    assert body["imported"] == 2
    assert len(body["results"]) == 2
    assert body["results"][0]["stop_count"] == 2

    db = SessionLocal()
    try:
        rows = (
            db.query(CommuteRouteRow)
            .filter(CommuteRouteRow.company_key == COMPANY_KEY)
            .all()
        )
        assert len(rows) == 2
    finally:
        db.close()


def test_bulk_import_shuttle_routes_rejects_bad_time():
    payload = _build_xlsx([("1호차", 1, "강남역", "25:99", "서울")])
    response = client.post(
        "/v1/admin/ops/shuttle/routes/bulk-import",
        headers=ADMIN_HEADERS,
        data={"company_key": COMPANY_KEY},
        files={
            "file": (
                "routes.xlsx",
                payload,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
        },
    )
    assert response.status_code == 400
