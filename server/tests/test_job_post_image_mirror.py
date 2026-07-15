from pathlib import Path
from unittest.mock import AsyncMock, patch
import asyncio

import httpx
from fastapi.testclient import TestClient

from app.config import settings
from app.main import app
from app.services.job_post_image_mirror import mirror_image_urls


client = TestClient(app)

# 1x1 PNG
_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
    b"\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x0f"
    b"\x00\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82"
)


def test_mirror_image_urls_saves_to_media(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "job_media_dir", str(tmp_path))
    monkeypatch.setattr(settings, "api_public_base_url", "http://test.local")

    mock_response = httpx.Response(
        200,
        content=_PNG,
        headers={"content-type": "image/png"},
        request=httpx.Request("GET", "https://file.albamon.com/a.png"),
    )
    mock_client = AsyncMock()
    mock_client.get = AsyncMock(return_value=mock_response)

    out = asyncio.run(
        mirror_image_urls(
            ["https://file.albamon.com/a.png"],
            referer="https://www.albamon.com/job/1",
            client=mock_client,
        )
    )
    assert len(out) == 1
    assert out[0].startswith("http://test.local/media/job-posts/")
    saved = list(Path(tmp_path).glob("*.png"))
    assert len(saved) == 1
    assert saved[0].read_bytes() == _PNG


def test_proxy_job_media_allowlist():
    with patch("app.routers.job_media.httpx.AsyncClient") as mock_cls:
        instance = AsyncMock()
        mock_cls.return_value.__aenter__.return_value = instance
        instance.get = AsyncMock(
            return_value=httpx.Response(
                200,
                content=_PNG,
                headers={"content-type": "image/png"},
                request=httpx.Request("GET", "https://file.albamon.com/a.png"),
            )
        )
        r = client.get(
            "/v1/job-media/proxy",
            params={"url": "https://file.albamon.com/a.png"},
        )
    assert r.status_code == 200
    assert r.content == _PNG


def test_proxy_job_media_blocks_unknown_host():
    r = client.get(
        "/v1/job-media/proxy",
        params={"url": "https://evil.example/x.png"},
    )
    assert r.status_code == 400
