import io

from fastapi.testclient import TestClient

from app.database import Base, engine
from app.main import app
from app.services.auth_token_service import issue_token

client = TestClient(app)


def _seeker_headers() -> dict[str, str]:
    token = issue_token(
        {"sub": "seeker-cred-upload@test.iljari.co.kr", "member_type": "seeker"}
    )
    return {"Authorization": f"Bearer {token}"}


def setup_module():
    Base.metadata.create_all(bind=engine)


def test_upload_requires_auth():
    response = client.post(
        "/v1/credential-media/upload",
        files={"file": ("cert.jpg", io.BytesIO(b"fake-image-bytes"), "image/jpeg")},
    )
    assert response.status_code == 401


def test_upload_returns_url_for_authenticated_user():
    response = client.post(
        "/v1/credential-media/upload",
        headers=_seeker_headers(),
        files={"file": ("cert.jpg", io.BytesIO(b"fake-image-bytes"), "image/jpeg")},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["url"].endswith(body["filename"])
    assert "/media/credential/" in body["url"]

    # 정적 파일 마운트가 실제로 서빙하는지 상대경로로 재확인
    relative = "/" + body["url"].split("/", 3)[3]
    fetched = client.get(relative)
    assert fetched.status_code == 200
    assert fetched.content == b"fake-image-bytes"


def test_upload_rejects_disallowed_extension():
    response = client.post(
        "/v1/credential-media/upload",
        headers=_seeker_headers(),
        files={"file": ("cert.pdf", io.BytesIO(b"fake-pdf-bytes"), "application/pdf")},
    )
    assert response.status_code == 400


def test_upload_rejects_oversized_file():
    oversized = b"0" * (8 * 1024 * 1024 + 1)
    response = client.post(
        "/v1/credential-media/upload",
        headers=_seeker_headers(),
        files={"file": ("cert.jpg", io.BytesIO(oversized), "image/jpeg")},
    )
    assert response.status_code == 413
