from app.services.ocr_business_cross_check import (
    OcrCrossCheckInput,
    detect_ocr_blocking_mismatch,
    detect_ocr_mismatch,
    detect_ocr_representative_mismatch,
)


def _input(**kwargs) -> OcrCrossCheckInput:
    defaults = dict(
        ocr_brn="1234567891",
        ocr_company_name="(주)일자리",
        ocr_representative_name="홍길동",
        ocr_confidence=0.95,
        expected_brn="1234567891",
        expected_company_name="일자리",
        expected_representative_name="홍길동",
    )
    defaults.update(kwargs)
    return OcrCrossCheckInput(**defaults)


def test_ocr_match_ok():
    assert detect_ocr_mismatch(_input()) is None


def test_ocr_brn_mismatch():
    reason = detect_ocr_blocking_mismatch(
        _input(ocr_brn="1111111111", expected_brn="1234567891")
    )
    assert reason is not None
    assert "사업자번호" in reason


def test_rep_middle_dot_normalized():
    assert (
        detect_ocr_representative_mismatch(
            _input(ocr_representative_name="김 · 영희", expected_representative_name="김영희")
        )
        is None
    )


def test_rep_mismatch_soft_message_after_nts():
    reason = detect_ocr_representative_mismatch(
        _input(ocr_representative_name="이타인", expected_representative_name="김실제")
    )
    assert reason is not None
    assert "대표자명" in reason
    assert "국세청 확인" in reason


def test_blocking_does_not_include_rep():
    assert (
        detect_ocr_blocking_mismatch(
            _input(ocr_representative_name="이타인", expected_representative_name="김실제")
        )
        is None
    )
