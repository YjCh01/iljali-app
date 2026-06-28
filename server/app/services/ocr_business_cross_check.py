"""사업자등록증 OCR ↔ 입력값 교차검증."""

from __future__ import annotations

import re
from dataclasses import dataclass

MIN_CONFIDENCE = 0.75


@dataclass
class OcrCrossCheckInput:
    ocr_brn: str
    ocr_company_name: str
    ocr_representative_name: str = ""
    ocr_confidence: float = 1.0
    expected_brn: str = ""
    expected_company_name: str = ""
    expected_representative_name: str = ""


def _digits(value: str) -> str:
    return re.sub(r"[^0-9]", "", value or "")


def _normalize_company(value: str) -> str:
    v = re.sub(r"[\s()（）\[\]「」·.]", "", value or "")
    for token in ("주식회사", "(주)"):
        v = v.replace(token, "")
    return v.lower()


def _company_matches(a: str, b: str) -> bool:
    na, nb = _normalize_company(a), _normalize_company(b)
    if not na or not nb:
        return True
    return na == nb or na in nb or nb in na


def _normalize_person_name(value: str) -> str:
    v = (value or "").strip()
    if v.startswith("대표자"):
        v = re.sub(r"^대표자\s*", "", v)
    v = re.sub(r"[\s　]+", "", v)
    v = re.sub(r"[·・∙•．\.]", "", v)
    v = re.sub(r"[()（）\[\]「」『』【】]", "", v)
    v = re.sub(r"(?i)ocr", "", v)
    return re.sub(r"[^가-힣a-zA-Z]", "", v)


def _levenshtein(a: str, b: str) -> int:
    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)
    rows = len(a) + 1
    cols = len(b) + 1
    matrix = [[0] * cols for _ in range(rows)]
    for i in range(rows):
        matrix[i][0] = i
    for j in range(cols):
        matrix[0][j] = j
    for i in range(1, rows):
        for j in range(1, cols):
            cost = 0 if a[i - 1] == b[j - 1] else 1
            matrix[i][j] = min(
                matrix[i - 1][j] + 1,
                matrix[i][j - 1] + 1,
                matrix[i - 1][j - 1] + cost,
            )
    return matrix[len(a)][len(b)]


def _fuzzy_korean_name_match(a: str, b: str) -> bool:
    if abs(len(a) - len(b)) > 2:
        return False
    max_dist = 1 if len(a) <= 3 or len(b) <= 3 else 2
    return _levenshtein(a, b) <= max_dist


def _rep_matches(ocr: str, expected: str) -> bool:
    a = _normalize_person_name(ocr)
    b = _normalize_person_name(expected)
    if not a or not b:
        return True
    if a == b or a in b or b in a:
        return True
    return _fuzzy_korean_name_match(a, b)


def detect_ocr_blocking_mismatch(data: OcrCrossCheckInput) -> str | None:
    """BRN·상호·신뢰도 불일치 — 가입 차단."""
    ocr_brn = _digits(data.ocr_brn)
    expected_brn = _digits(data.expected_brn)
    if len(ocr_brn) == 10 and ocr_brn != expected_brn:
        return f"OCR 사업자번호({ocr_brn})가 입력값({expected_brn})과 일치하지 않습니다."
    if not _company_matches(data.ocr_company_name, data.expected_company_name):
        return (
            f"OCR 상호「{data.ocr_company_name}」가 입력 상호와 일치하지 않습니다."
        )
    if data.ocr_confidence < MIN_CONFIDENCE:
        return (
            f"OCR 신뢰도가 낮습니다 ({data.ocr_confidence:.2f}). "
            "관리자 검토가 필요합니다."
        )
    return None


def detect_ocr_representative_mismatch(data: OcrCrossCheckInput) -> str | None:
    """대표자명 OCR 불일치 — 국세청 확인 후 관리자 검토 사유."""
    rep = (data.expected_representative_name or "").strip()
    if not rep or _rep_matches(data.ocr_representative_name, rep):
        return None
    ocr_label = (data.ocr_representative_name or "").strip()
    ocr_hint = f" (OCR: {ocr_label})" if ocr_label else ""
    return (
        f"등록증 OCR 대표자명이 입력값과 다릅니다{ocr_hint}. "
        "국세청 확인이 완료되었다면 계속 진행되며, 관리자가 등록증을 검토합니다."
    )


def detect_ocr_mismatch(data: OcrCrossCheckInput) -> str | None:
    """전체 OCR 교차검증 (미인증·등록증 제출용 — 대표자명 포함)."""
    blocking = detect_ocr_blocking_mismatch(data)
    if blocking:
        return blocking
    return detect_ocr_representative_mismatch(data)
