from fastapi.testclient import TestClient

from app.database import Base, engine
from app.main import app
from app.services.auth_token_service import issue_token

client = TestClient(app)

_EMPLOYER_HEADERS = {
    "Authorization": "Bearer "
    + issue_token(
        {
            "sub": "corp-job-import@test.iljari.co.kr",
            "member_type": "corporate",
            "company_key": "9090909090",
        }
    )
}


def setup_module():
    Base.metadata.create_all(bind=engine)


def test_parse_text_import():
    response = client.post(
        "/v1/job-import/parse",
        json={
            "text": "「카페 알바」 모집\n시급 : 12,000원\n09:00 ~ 18:00\n경기도 화성시 동탄대로 123",
            "platform": "albamon",
        },
        headers=_EMPLOYER_HEADERS,
    )
    assert response.status_code == 200
    data = response.json()
    assert "카페 알바" in data["title"]
    assert data["hourly_wage"] is not None
    assert data["confidence"] >= 0.5


def test_parse_requires_input():
    response = client.post(
        "/v1/job-import/parse", json={}, headers=_EMPLOYER_HEADERS
    )
    assert response.status_code == 200
    assert response.json()["confidence"] == 0.0


def test_parse_requires_auth():
    response = client.post("/v1/job-import/parse", json={})
    assert response.status_code == 401


def test_parse_rejects_seeker_token():
    seeker_headers = {
        "Authorization": "Bearer "
        + issue_token({"sub": "seeker-job-import@test.iljari.co.kr", "member_type": "seeker"})
    }
    response = client.post("/v1/job-import/parse", json={}, headers=seeker_headers)
    assert response.status_code == 403
