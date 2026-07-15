from bs4 import BeautifulSoup

from app.services.job_post_image_extractor import (
    extract_image_job_body,
    images_to_html,
    should_try_image_extract,
)


def test_should_try_image_extract_albamon_always():
    assert should_try_image_extract("", platform="albamon") is True
    assert should_try_image_extract("짧음", platform="albamon") is True
    assert (
        should_try_image_extract(
            "이 공고는 텍스트로 상세 업무 내용이 충분히 길게 적혀 있습니다. "
            "추가로 라인 작업과 단순 포장 보조 업무가 포함됩니다.",
            platform="albamon",
        )
        is True
    )


def test_should_try_image_extract_other_platforms_gated_by_length():
    assert should_try_image_extract("", platform="saramin") is True
    assert (
        should_try_image_extract(
            "이 공고는 텍스트로 상세 업무 내용이 충분히 길게 적혀 있습니다. "
            "추가로 라인 작업과 단순 포장 보조 업무가 포함됩니다.",
            platform="saramin",
        )
        is False
    )


def test_extract_albamon_image_job_body():
    html = """
    <html><body>
      <div class="detail_contents">
        <img src="//file.albamon.com/recruit/detail/sample1.jpg" width="800" />
        <img src="/images/logo.png" width="40" height="30" />
        <img data-src="https://file.albamon.com/recruit/detail/sample2.png" />
      </div>
    </body></html>
    """
    soup = BeautifulSoup(html, "lxml")
    body_html, images = extract_image_job_body(
        soup,
        "https://www.albamon.com/job/detail/123",
        platform="albamon",
    )
    assert len(images) == 2
    assert all("file.albamon.com" in url for url in images)
    assert images_to_html(images).count("<img") == 2


def test_extract_albamon_extensionless_photo_view():
    html = """
    <html><body>
      <div class="detail_contents">
        <img src="https://file.albamon.com/Albamon/Recruit/Photo/C-Photo-View?FN=abc123" width="720" />
        <img src="https://mc.albamon.kr/monimg/msa/assets/images/albamonZ/wordmark_z.svg" />
      </div>
    </body></html>
    """
    soup = BeautifulSoup(html, "lxml")
    _, images = extract_image_job_body(
        soup,
        "https://www.albamon.com/job/detail/999",
        platform="albamon",
    )
    assert len(images) == 1
    assert "C-Photo-View" in images[0]
