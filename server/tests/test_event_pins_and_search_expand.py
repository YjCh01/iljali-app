"""Event pin + Albamon search URL expansion."""

from fastapi.testclient import TestClient

from app.config import settings
from app.database import Base, engine
from app.main import app
from app.services.job_post_scraper import (
    extract_detail_urls_from_html,
    is_listing_or_search_url,
)

client = TestClient(app)
ADMIN_HEADERS = {"X-Admin-Api-Key": settings.admin_api_key}


def setup_module():
    Base.metadata.create_all(bind=engine)


def teardown_module():
    Base.metadata.drop_all(bind=engine)


def test_is_listing_or_search_url():
    assert is_listing_or_search_url(
        "https://www.albamon.com/total-search?keyword=%ED%86%B5%EA%B7%BC"
    )
    assert not is_listing_or_search_url(
        "https://www.albamon.com/recruit/view/12345"
    )


def test_extract_detail_urls_from_html():
    html = """
    <html><body>
      <a href="/recruit/view/111">job1</a>
      <a href="https://www.albamon.com/recruit/view/222">job2</a>
      <a href="/about">other</a>
    </body></html>
    """
    urls = extract_detail_urls_from_html(
        "https://www.albamon.com/total-search?keyword=bus",
        html,
    )
    assert any("111" in u for u in urls)
    assert any("222" in u for u in urls)


def test_event_pin_crud():
    created = client.post(
        "/v1/admin/ops/event-pins",
        headers=ADMIN_HEADERS,
        json={
            "latitude": 37.5665,
            "longitude": 126.978,
            "title": "출근 퀴즈",
            "body": "시급에 포함되는 것은?",
            "kind": "quiz",
            "color_hex": "#FF6F00",
            "payload": {
                "options": ["주휴수당", "야식비", "둘 다"],
                "correct_index": 0,
            },
        },
    )
    assert created.status_code == 200, created.text
    pin = created.json()["event_pin"]
    assert pin["kind"] == "quiz"
    assert len(pin["payload"]["options"]) == 3

    listed = client.get("/v1/admin/ops/event-pins", headers=ADMIN_HEADERS)
    assert listed.status_code == 200
    assert any(p["id"] == pin["id"] for p in listed.json()["event_pins"])

    bootstrap = client.get("/v1/sync/bootstrap")
    assert bootstrap.status_code == 200
    assert any(p["id"] == pin["id"] for p in bootstrap.json()["event_pins"])

    deleted = client.delete(
        f"/v1/admin/ops/event-pins/{pin['id']}",
        headers=ADMIN_HEADERS,
    )
    assert deleted.status_code == 200
