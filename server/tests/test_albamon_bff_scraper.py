from app.services.albamon_bff_scraper import (
    extract_albamon_recruit_no,
    extract_body_images_from_content_html,
)


def test_extract_recruit_no_from_detail_url():
    assert (
        extract_albamon_recruit_no("https://www.albamon.com/jobs/detail/117737154")
        == "117737154"
    )
    assert (
        extract_albamon_recruit_no(
            "https://www.albamon.com/jobs/detail/117737154?productCode=miplus"
        )
        == "117737154"
    )
    assert (
        extract_albamon_recruit_no(
            "https://www.albamon.com/jobs/detail/content/117737154"
        )
        == "117737154"
    )


def test_extract_body_images_strips_blogo():
    html = """
    <div class="regDetailView">
      <p class="bLogo"><img src="https://file.albamon.com/Albamon/Recruit/Photo/C-Photo-View?FN=JK_CO_logo.JPG" alt="기업로고" /></p>
      <p><img src="https://i.imgur.com/w7ogRDh.png" alt="모집요강" /></p>
      <p class="companyLogo"><img src="https://file.albamon.com/logo.png" /></p>
    </div>
    """
    cleaned, images = extract_body_images_from_content_html(html)
    assert len(images) == 1
    assert "imgur.com" in images[0]
    assert "bLogo" not in cleaned
    assert "JK_CO" not in cleaned
