from fastapi.testclient import TestClient

from app.database import Base, engine
from app.main import app

client = TestClient(app)


def setup_module():
    Base.metadata.create_all(bind=engine)


def test_parse_text_import():
    response = client.post(
        "/v1/job-import/parse",
        json={
            "text": "「카페 알바」 모집\n시급 : 12,000원\n09:00 ~ 18:00\n경기도 화성시 동탄대로 123",
            "platform": "albamon",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert "카페 알바" in data["title"]
    assert data["hourly_wage"] is not None
    assert data["confidence"] >= 0.5


def test_parse_requires_input():
    response = client.post("/v1/job-import/parse", json={})
    assert response.status_code == 200
    assert response.json()["confidence"] == 0.0
