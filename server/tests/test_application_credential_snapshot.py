import json

from fastapi.testclient import TestClient

from app.database import Base, engine
from app.main import app
from app.services.auth_token_service import issue_token

client = TestClient(app)

COMPANY_KEY = "5055055055"


def setup_module():
    Base.metadata.create_all(bind=engine)


def _seeker_headers(seeker_email: str) -> dict[str, str]:
    token = issue_token({"sub": seeker_email, "member_type": "seeker"})
    return {"Authorization": f"Bearer {token}"}


def _submit(seeker_email: str, **overrides) -> dict:
    body = {
        "post_id": "post-cred-snap-1",
        "post_title": "냉동창고 상하차",
        "company_name": "테스트기업",
        "company_key": COMPANY_KEY,
        "seeker_email": seeker_email,
        "seeker_name": "구직자",
        "status": "applied",
        "required_credential_ids_json": json.dumps(["forklift_operator_cert"]),
        "held_credential_ids_json": json.dumps(["forklift_operator_cert", "health_certificate"]),
    }
    body.update(overrides)
    response = client.post(
        "/v1/hiring/applications",
        json=body,
        headers=_seeker_headers(seeker_email),
    )
    assert response.status_code == 200
    return response.json()


def test_credential_snapshot_persists_through_create_and_get():
    created = _submit("seeker-cred-snap-1@test.iljari.co.kr")
    assert json.loads(created["required_credential_ids_json"]) == [
        "forklift_operator_cert"
    ]
    assert json.loads(created["held_credential_ids_json"]) == [
        "forklift_operator_cert",
        "health_certificate",
    ]

    fetched = client.get(
        f"/v1/hiring/applications/{created['id']}",
        headers=_seeker_headers("seeker-cred-snap-1@test.iljari.co.kr"),
    )
    assert fetched.status_code == 200
    assert json.loads(fetched.json()["required_credential_ids_json"]) == [
        "forklift_operator_cert"
    ]
    assert json.loads(fetched.json()["held_credential_ids_json"]) == [
        "forklift_operator_cert",
        "health_certificate",
    ]


def test_credential_snapshot_defaults_to_empty_list():
    seeker_email = "seeker-cred-snap-2@test.iljari.co.kr"
    created = client.post(
        "/v1/hiring/applications",
        json={
            "post_id": "post-cred-snap-2",
            "company_key": COMPANY_KEY,
            "seeker_email": seeker_email,
        },
        headers=_seeker_headers(seeker_email),
    )
    assert created.status_code == 200
    assert json.loads(created.json()["required_credential_ids_json"]) == []
    assert json.loads(created.json()["held_credential_ids_json"]) == []


def test_credential_snapshot_updates_on_resubmit_upsert():
    seeker_email = "seeker-cred-snap-3@test.iljari.co.kr"
    _submit(
        seeker_email,
        post_id="post-cred-snap-3",
        held_credential_ids_json=json.dumps(["health_certificate"]),
    )

    resubmitted = _submit(
        seeker_email,
        post_id="post-cred-snap-3",
        status="chatting",
        held_credential_ids_json=json.dumps(
            ["health_certificate", "forklift_operator_cert"]
        ),
    )
    assert resubmitted["status"] == "chatting"
    assert json.loads(resubmitted["held_credential_ids_json"]) == [
        "health_certificate",
        "forklift_operator_cert",
    ]
