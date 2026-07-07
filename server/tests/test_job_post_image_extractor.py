from bs4 import BeautifulSoup

from app.services.job_post_image_extractor import (
    extract_image_job_body,
    images_to_html,
    should_try_image_extract,
)


def test_should_try_image_extract_when_description_empty():
    assert should_try_image_extract("", platform="albamon") is True
    assert should_try_image_extract("짧음", platform="albamon") is True
    assert (
        should_try_image_extract(
            "이 공고는 텍스트로 상세 업무 내용이 충분히 길게 적혀 있습니다. "
            "추가로 라인 작업과 단순 포장 보조 업무가 포함됩니다.",
            platform="albamon",
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
    assert "sample1.jpg" in images[0]
    assert body_html == images_to_html(images)
    assert "<img src=" in body_html
