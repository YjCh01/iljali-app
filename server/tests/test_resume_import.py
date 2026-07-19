"""Resume import parser tests."""

from app.services.resume_text_parser import parse_resume_text


def test_parse_resume_text_sections():
    text = """
학력
서울대학교 경영학과 졸업 2016-2020

경력
(주)아라물류 물류센터 피킹 2021.03 - 2023.12

면허
운전면허 1종 보통

자격증
지게차운전기능사 2022.05

자기소개
성실하고 체력이 좋아 현장 업무에 자신 있습니다.
"""
    parsed = parse_resume_text(text)
    assert len(parsed["educations"]) >= 1
    assert len(parsed["experiences"]) >= 1
    assert len(parsed["licenses"]) >= 1
    assert len(parsed["certifications"]) >= 1
    assert "성실" in parsed["selfIntroduction"]
    assert parsed["confidence"] >= 0.5


def test_resume_import_url_requires_login_message():
    from fastapi.testclient import TestClient

    from app.main import app
    from app.services.auth_token_service import issue_token

    client = TestClient(app)
    seeker_headers = {
        "Authorization": "Bearer "
        + issue_token(
            {"sub": "seeker-resume-import@test.iljari.co.kr", "member_type": "seeker"}
        )
    }
    response = client.post(
        "/v1/resume-import/parse",
        json={"url": "https://www.jobkorea.co.kr/", "text": ""},
        headers=seeker_headers,
    )
    assert response.status_code == 400 or response.status_code == 200
    if response.status_code == 200:
        body = response.json()
        assert body.get("confidence", 1) <= 0.1 or body.get("message")


def test_resume_import_requires_auth():
    from fastapi.testclient import TestClient

    from app.main import app

    client = TestClient(app)
    response = client.post(
        "/v1/resume-import/parse",
        json={"url": "https://www.jobkorea.co.kr/", "text": ""},
    )
    assert response.status_code == 401
