from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from app.config import settings
from app.database import Base, engine
from app.main import app
from app.services.job_post_scraper import ScrapeResult

client = TestClient(app)
ADMIN_HEADERS = {"X-Admin-Api-Key": settings.admin_api_key}


def setup_module():
    Base.metadata.create_all(bind=engine)


def teardown_module():
    Base.metadata.drop_all(bind=engine)


def test_extract_urls_dedupes():
    from app.services.admin_bulk_url_import_service import extract_urls

    raw = """
    https://www.albamon.com/job/1
    https://www.albamon.com/job/1
    https://www.albamon.com/job/2
    """
    urls = extract_urls(raw)
    assert urls == [
        "https://www.albamon.com/job/1",
        "https://www.albamon.com/job/2",
    ]


@patch(
    "app.services.admin_bulk_url_import_service.fetch_job_post",
    new_callable=AsyncMock,
)
@patch(
    "app.services.admin_bulk_url_import_service._geocode",
    new_callable=AsyncMock,
    return_value=None,
)
def test_bulk_import_urls_with_image_body(mock_geocode, mock_fetch):
    mock_fetch.return_value = ScrapeResult(
        platform="albamon",
        raw_text="",
        title="[이미지공고] 물류 보조",
        hourly_wage="시급 11000",
        work_schedule="",
        workplace="경기 이천시",
        job_description="이미지 공고",
        description_html='<p><img src="https://file.albamon.com/a.jpg" /></p>',
        description_images=["https://file.albamon.com/a.jpg"],
        confidence=0.85,
        source_url="https://www.albamon.com/job/img",
    )

    r = client.post(
        "/v1/admin/ops/jobs/bulk-import-urls",
        headers=ADMIN_HEADERS,
        json={
            "url_text": "https://www.albamon.com/job/img",
            "company_key": "5403100894",
        },
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["imported"] == 1
    assert body["results"][0]["image_count"] == 1

    sync = client.get("/v1/sync/bootstrap")
    post = next(
        p for p in sync.json()["posts"] if p["title"] == "[이미지공고] 물류 보조"
    )
    assert "file.albamon.com/a.jpg" in post["description_body_json"]


@patch(
    "app.services.admin_bulk_url_import_service.fetch_job_post",
    new_callable=AsyncMock,
)
@patch(
    "app.services.admin_bulk_url_import_service._geocode",
    new_callable=AsyncMock,
    return_value=None,
)
def test_bulk_import_urls_creates_posts(mock_geocode, mock_fetch):
    mock_fetch.return_value = ScrapeResult(
        platform="albamon",
        raw_text="시급 11000원\n경기 이천시 물류센터",
        title="[테스트] 물류 보조",
        hourly_wage="시급 11000",
        work_schedule="09:00-18:00",
        workplace="경기 이천시",
        job_description="단순 보조",
        confidence=0.8,
        source_url="https://www.albamon.com/job/test",
    )

    r = client.post(
        "/v1/admin/ops/jobs/bulk-import-urls",
        headers=ADMIN_HEADERS,
        json={
            "url_text": "https://www.albamon.com/job/test",
            "company_key": "5403100894",
            "company_name": "아라컴퍼니",
        },
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["imported"] == 1
    assert body["results"][0]["ok"] is True
    assert body["results"][0]["title"] == "[테스트] 물류 보조"

    sync = client.get("/v1/sync/bootstrap")
    assert sync.status_code == 200
    titles = [p["title"] for p in sync.json()["posts"]]
    assert "[테스트] 물류 보조" in titles


def test_bulk_import_urls_requires_input():
    r = client.post(
        "/v1/admin/ops/jobs/bulk-import-urls",
        headers=ADMIN_HEADERS,
        json={"url_text": "   "},
    )
    assert r.status_code == 400
