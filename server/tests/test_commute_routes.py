"""Commute routes — server persistence."""

from datetime import datetime, timezone

from fastapi.testclient import TestClient

from app.database import SessionLocal
from app.main import app
from app.services.auth_token_service import issue_token

client = TestClient(app)

COMPANY_KEY = "9988776655"
ROUTE_ID = "route_server_test_1"


def _corp_headers() -> dict[str, str]:
    token = issue_token(
        {
            "sub": "corp@test.iljari.co.kr",
            "member_type": "corporate",
            "company_key": COMPANY_KEY,
        }
    )
    return {"Authorization": f"Bearer {token}"}


def _sample_route() -> dict:
    return {
        "id": ROUTE_ID,
        "companyKey": COMPANY_KEY,
        "routeName": "1호차",
        "active": True,
        "overlayColorHex": "#E53935",
        "stops": [
            {
                "id": "stop_1",
                "label": "첫 정류장",
                "coordinate": {"latitude": 37.5, "longitude": 127.0},
                "departureTime": "07:00",
            },
            {
                "id": "__shuttle_workplace__",
                "label": "근무지",
                "coordinate": {"latitude": 37.51, "longitude": 127.01},
                "arrivalTime": "08:30",
            },
        ],
        "polylinePoints": [],
    }


def test_commute_route_upsert_and_list():
    headers = _corp_headers()
    saved = client.put(
        f"/v1/shuttle/routes/{ROUTE_ID}",
        headers=headers,
        json=_sample_route(),
    )
    assert saved.status_code == 200, saved.text
    assert saved.json()["routeName"] == "1호차"

    listed = client.get(
        "/v1/shuttle/routes",
        headers=headers,
        params={"company_key": COMPANY_KEY},
    )
    assert listed.status_code == 200
    ids = [item["id"] for item in listed.json()["items"]]
    assert ROUTE_ID in ids

    fetched = client.get(
        f"/v1/shuttle/routes/{ROUTE_ID}",
        headers=headers,
    )
    assert fetched.status_code == 200
    assert fetched.json()["companyKey"] == COMPANY_KEY


def test_commute_route_deactivate():
    headers = _corp_headers()
    client.put(f"/v1/shuttle/routes/{ROUTE_ID}", headers=headers, json=_sample_route())
    deactivated = client.delete(
        f"/v1/shuttle/routes/{ROUTE_ID}",
        headers=headers,
        params={"company_key": COMPANY_KEY, "hard": False},
    )
    assert deactivated.status_code == 200
    assert deactivated.json()["active"] is False
