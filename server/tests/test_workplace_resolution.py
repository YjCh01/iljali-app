from fastapi.testclient import TestClient

from app.database import Base, SessionLocal, engine
from app.job_sync_models import JobPostRow
from app.main import app
from app.services.auth_token_service import issue_token
from app.services.workplace_service import backfill_missing_workplace_ids

client = TestClient(app)


def setup_module():
    Base.metadata.create_all(bind=engine)


def _corp_auth_headers(company_key: str) -> dict[str, str]:
    token = issue_token(
        {
            "sub": "corp@test.iljari.co.kr",
            "member_type": "corporate",
            "company_key": company_key,
        }
    )
    return {"Authorization": f"Bearer {token}"}


def test_same_company_same_coordinates_share_workplace_id():
    headers = _corp_auth_headers("1111111111")
    first = client.post(
        "/v1/job-board/posts",
        headers=headers,
        json={
            "title": "물류 상차",
            "company_key": "1111111111",
            "warehouse_name": "강남물류센터",
            "workplace_latitude": 37.5,
            "workplace_longitude": 127.0,
        },
    )
    second = client.post(
        "/v1/job-board/posts",
        headers=headers,
        json={
            "title": "물류 하차",
            "company_key": "1111111111",
            # 이름 표기는 다르지만 좌표가 같으면 같은 근무지로 판정
            "warehouse_name": "강남 물류 센터",
            "workplace_latitude": 37.5,
            "workplace_longitude": 127.0,
        },
    )
    assert first.status_code == 200
    assert second.status_code == 200
    wp1 = first.json()["workplace_id"]
    wp2 = second.json()["workplace_id"]
    assert wp1 is not None
    assert wp1 == wp2


def test_different_coordinates_get_different_workplace_id():
    headers = _corp_auth_headers("2222222222")
    first = client.post(
        "/v1/job-board/posts",
        headers=headers,
        json={
            "title": "센터 A",
            "company_key": "2222222222",
            "warehouse_name": "센터A",
            "workplace_latitude": 36.0,
            "workplace_longitude": 128.0,
        },
    )
    second = client.post(
        "/v1/job-board/posts",
        headers=headers,
        json={
            "title": "센터 B",
            "company_key": "2222222222",
            "warehouse_name": "센터B",
            "workplace_latitude": 36.5,
            "workplace_longitude": 128.5,
        },
    )
    assert first.json()["workplace_id"] != second.json()["workplace_id"]


def test_same_coordinates_different_company_get_different_workplace_id():
    coords = {"workplace_latitude": 35.1, "workplace_longitude": 129.1}
    first = client.post(
        "/v1/job-board/posts",
        headers=_corp_auth_headers("3333333333"),
        json={
            "title": "회사A 공고",
            "company_key": "3333333333",
            "warehouse_name": "공유주소",
            **coords,
        },
    )
    second = client.post(
        "/v1/job-board/posts",
        headers=_corp_auth_headers("4444444444"),
        json={
            "title": "회사B 공고",
            "company_key": "4444444444",
            "warehouse_name": "공유주소",
            **coords,
        },
    )
    assert first.json()["workplace_id"] != second.json()["workplace_id"]


def test_update_with_new_coordinates_reresolves_workplace_id():
    headers = _corp_auth_headers("5555555555")
    created = client.post(
        "/v1/job-board/posts",
        headers=headers,
        json={
            "title": "이전 근무지",
            "company_key": "5555555555",
            "warehouse_name": "구주소",
            "workplace_latitude": 33.0,
            "workplace_longitude": 126.0,
        },
    )
    post_id = created.json()["id"]
    original_workplace_id = created.json()["workplace_id"]

    updated = client.put(
        f"/v1/job-board/posts/{post_id}",
        headers=headers,
        json={
            "warehouse_name": "신주소",
            "workplace_latitude": 33.5,
            "workplace_longitude": 126.5,
        },
    )
    assert updated.status_code == 200
    assert updated.json()["workplace_id"] != original_workplace_id

    # 근무지와 무관한 필드만 바꾸면 workplace_id는 그대로 유지
    unrelated_update = client.put(
        f"/v1/job-board/posts/{post_id}",
        headers=headers,
        json={"status": "closed"},
    )
    assert unrelated_update.json()["workplace_id"] == updated.json()["workplace_id"]


def test_backfill_clusters_legacy_rows_by_company_and_coordinate():
    db = SessionLocal()
    db.add(
        JobPostRow(
            id="legacy_post_1",
            title="레거시1",
            company_key="6666666666",
            warehouse_name="레거시센터",
            workplace_latitude=34.0,
            workplace_longitude=130.0,
        )
    )
    db.add(
        JobPostRow(
            id="legacy_post_2",
            title="레거시2",
            company_key="6666666666",
            warehouse_name="레거시센터",
            workplace_latitude=34.0,
            workplace_longitude=130.0,
        )
    )
    db.add(
        JobPostRow(
            id="legacy_post_3",
            title="레거시3-다른회사",
            company_key="7777777777",
            warehouse_name="레거시센터",
            workplace_latitude=34.0,
            workplace_longitude=130.0,
        )
    )
    db.commit()
    db.close()

    db = SessionLocal()
    updated = backfill_missing_workplace_ids(db)
    db.close()
    assert updated >= 3

    db = SessionLocal()
    row1 = db.get(JobPostRow, "legacy_post_1")
    row2 = db.get(JobPostRow, "legacy_post_2")
    row3 = db.get(JobPostRow, "legacy_post_3")
    assert row1.workplace_id is not None
    assert row1.workplace_id == row2.workplace_id
    assert row1.workplace_id != row3.workplace_id
    db.close()
