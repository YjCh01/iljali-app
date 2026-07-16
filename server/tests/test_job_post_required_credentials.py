import json

from fastapi.testclient import TestClient

from app.database import Base, engine
from app.main import app
from app.services.auth_token_service import issue_token

client = TestClient(app)

COMPANY_KEY = "5055055055"


def setup_module():
    Base.metadata.create_all(bind=engine)


def _corp_headers(company_key: str = COMPANY_KEY) -> dict[str, str]:
    token = issue_token(
        {
            "sub": "corp-cred@test.iljari.co.kr",
            "member_type": "corporate",
            "company_key": company_key,
        }
    )
    return {"Authorization": f"Bearer {token}"}


def test_required_credentials_persist_through_create_and_get():
    required = ["forklift_operator_cert", "health_certificate"]
    created = client.post(
        "/v1/job-board/posts",
        headers=_corp_headers(),
        json={
            "title": "물류센터 지게차 기사",
            "company_key": COMPANY_KEY,
            "required_credential_ids_json": json.dumps(required),
        },
    )
    assert created.status_code == 200
    assert json.loads(created.json()["required_credential_ids_json"]) == required

    post_id = created.json()["id"]
    fetched = client.get(f"/v1/job-board/posts/{post_id}")
    assert fetched.status_code == 200
    assert json.loads(fetched.json()["required_credential_ids_json"]) == required


def test_required_credentials_default_to_empty_list():
    created = client.post(
        "/v1/job-board/posts",
        headers=_corp_headers(),
        json={"title": "단순 포장", "company_key": COMPANY_KEY},
    )
    assert created.status_code == 200
    assert json.loads(created.json()["required_credential_ids_json"]) == []


def test_required_credentials_updatable_and_survive_unrelated_update():
    created = client.post(
        "/v1/job-board/posts",
        headers=_corp_headers(),
        json={"title": "미화", "company_key": COMPANY_KEY},
    )
    post_id = created.json()["id"]

    updated = client.put(
        f"/v1/job-board/posts/{post_id}",
        headers=_corp_headers(),
        json={"required_credential_ids_json": json.dumps(["latent_tb_screening"])},
    )
    assert updated.status_code == 200
    assert json.loads(updated.json()["required_credential_ids_json"]) == [
        "latent_tb_screening"
    ]

    # 자격증과 무관한 필드만 바꿔도 기존 지정이 사라지지 않아야 함
    # (재동기화 시 통째로 사라졌던 버그의 재발 방지 테스트).
    status_only = client.put(
        f"/v1/job-board/posts/{post_id}",
        headers=_corp_headers(),
        json={"status": "closed"},
    )
    assert status_only.status_code == 200
    assert json.loads(status_only.json()["required_credential_ids_json"]) == [
        "latent_tb_screening"
    ]
