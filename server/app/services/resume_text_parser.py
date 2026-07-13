"""이력서 텍스트 → 구조화 필드 (학력·경력·면허·자격증·자기소개)."""

from __future__ import annotations

import re
from uuid import uuid4

_SECTION_HEADERS = {
    "education": ("학력", "학력사항", "최종학력"),
    "experience": ("경력", "경력사항", "근무경력", "아르바이트 경력"),
    "license": ("면허", "면허증", "운전면허"),
    "certification": ("자격증", "자격", "어학", "수상"),
    "self_introduction": ("자기소개", "자기소개서", "소개", "성격의 장단점"),
}

_EDU_LEVEL_HINTS = (
    ("대학원", "대학원"),
    ("대학교(4년제)", "대학교"),
    ("대학교(2년제)", "전문대"),
    ("고등학교", "고등학교"),
    ("검정고시", "검정고시"),
)

_GRAD_STATUS = ("졸업", "재학", "휴학", "중퇴", "수료")

_EMPLOYMENT_HINTS = (
    ("아르바이트", ("알바", "아르바이트", "파트", "시급")),
    ("계약직", ("계약", "계약직")),
    ("정규직", ("정규", "정규직", "상용")),
    ("인턴", ("인턴",)),
    ("프리랜서", ("프리랜서", "프리")),
)


def _new_id(prefix: str) -> str:
    return f"{prefix}_{uuid4().hex[:10]}"


def _split_sections(text: str) -> dict[str, str]:
    lines = [line.strip() for line in text.splitlines()]
    buckets: dict[str, list[str]] = {"body": []}
    current = "body"

    for line in lines:
        if not line:
            continue
        matched = False
        for key, headers in _SECTION_HEADERS.items():
            if any(line.replace(" ", "") == header.replace(" ", "") for header in headers):
                current = key
                buckets.setdefault(current, [])
                matched = True
                break
            if any(line.startswith(header) and len(line) <= len(header) + 4 for header in headers):
                current = key
                buckets.setdefault(current, [])
                matched = True
                break
        if not matched:
            buckets.setdefault(current, []).append(line)

    return {key: "\n".join(value).strip() for key, value in buckets.items() if value}


def _parse_year_range(raw: str) -> tuple[int | None, int | None, int | None, int | None]:
    period = re.search(
        r"(\d{4})\s*[.\-/년]\s*(\d{1,2})?\s*[~\-–—]\s*(\d{4}|현재|재직중)?\s*[.\-/년]?\s*(\d{1,2})?",
        raw,
    )
    if not period:
        years = re.findall(r"(20\d{2}|19\d{2})", raw)
        if len(years) >= 2:
            return int(years[0]), None, int(years[1]), None
        if len(years) == 1:
            return int(years[0]), None, None, None
        return None, None, None, None

    start_year = int(period.group(1))
    start_month = int(period.group(2)) if period.group(2) else None
    end_token = period.group(3) or ""
    end_year = None if end_token in {"", "현재", "재직중"} else int(end_token)
    end_month = int(period.group(4)) if period.group(4) else None
    return start_year, start_month, end_year, end_month


def _guess_education_level(line: str) -> str:
    for level, hint in _EDU_LEVEL_HINTS:
        if hint in line:
            return level
    if "대학" in line:
        return "대학교(4년제)"
    if "고등" in line or "고교" in line:
        return "고등학교"
    return "기타"


def _guess_graduation_status(line: str) -> str:
    for status in _GRAD_STATUS:
        if status in line:
            return status
    return "졸업"


def _parse_educations(section: str, fallback: str) -> list[dict]:
    source = section or fallback
    results: list[dict] = []
    for line in [ln.strip() for ln in source.splitlines() if ln.strip()]:
        if not any(token in line for token in ("학교", "대학", "고등", "고교", "검정", "전문대")):
            continue
        years = re.findall(r"(20\d{2}|19\d{2})", line)
        school_match = re.search(
            r"([가-힣A-Za-z0-9·\s]{2,30}(?:학교|대학교|대학|고등학교|고교|전문대학|대학원))",
            line,
        )
        major_match = re.search(r"([가-힣A-Za-z·\s]{2,20}(?:학과|전공|계열))", line)
        results.append(
            {
                "id": _new_id("edu"),
                "level": _guess_education_level(line),
                "graduationStatus": _guess_graduation_status(line),
                "schoolName": school_match.group(1).strip() if school_match else line[:40],
                "major": major_match.group(1).strip() if major_match else None,
                "startYear": int(years[0]) if years else None,
                "endYear": int(years[-1]) if len(years) >= 2 else (int(years[0]) if years else None),
            }
        )
    return results[:8]


def _guess_employment_type(line: str) -> str:
    for label, hints in _EMPLOYMENT_HINTS:
        if any(hint in line for hint in hints):
            return label
    return "아르바이트"


def _parse_experiences(section: str, fallback: str) -> list[dict]:
    source = section or fallback
    results: list[dict] = []
    for line in [ln.strip() for ln in source.splitlines() if ln.strip()]:
        if not any(token in line for token in ("회사", "근무", "매장", "물류", "센터", "아르바이트", "알바", "(주)", "주식회사")):
            if not re.search(r"(20\d{2}|19\d{2})", line):
                continue
        company_match = re.search(
            r"((?:\(주\)|주식회사)?[가-힣A-Za-z0-9·&\s]{2,24}(?:주식회사|회사|센터|매장|마트|호텔|식당)?)",
            line,
        )
        role_match = re.search(
            r"(?:담당|직무|포지션|업무)[:：]?\s*([가-힣A-Za-z0-9·/\s]{2,24})",
            line,
        )
        if not company_match and "|" in line:
            parts = [part.strip() for part in line.split("|") if part.strip()]
            if len(parts) >= 2:
                company_match = re.match(r".+", parts[0])
                role_match = re.match(r".+", parts[1])
        start_year, start_month, end_year, end_month = _parse_year_range(line)
        company_name = company_match.group(1).strip() if company_match else line.split("|")[0].strip()[:30]
        job_role = role_match.group(1).strip() if role_match else "현장 보조"
        results.append(
            {
                "id": _new_id("exp"),
                "employmentType": _guess_employment_type(line),
                "companyName": company_name,
                "jobRole": job_role,
                "startYear": start_year,
                "startMonth": start_month,
                "endYear": end_year,
                "endMonth": end_month,
                "description": line if len(line) > 40 else None,
            }
        )
    return results[:12]


def _parse_named_items(section: str, fallback: str, *, license_mode: bool) -> list[dict]:
    source = section or fallback
    keywords = ("면허", "운전") if license_mode else ("자격", "기사", "기능사", "산업", "능력", "토익", "opic", "토플")
    results: list[dict] = []
    for line in [ln.strip() for ln in source.splitlines() if ln.strip()]:
        if license_mode and not any(token in line.lower() for token in keywords):
            continue
        if not license_mode and not any(token.lower() in line.lower() for token in keywords):
            continue
        acquired = re.search(r"(20\d{2}[.\-/년]?\s*\d{0,2})", line)
        name = re.sub(r"(취득|합격|발급).*$", "", line).strip(" ·-|")
        results.append(
            {
                "id": _new_id("lic" if license_mode else "cert"),
                "name": name[:60] or line[:60],
                "issuer": None,
                "acquiredLabel": acquired.group(1) if acquired else None,
            }
        )
    return results[:10]


def _parse_self_introduction(section: str, fallback: str) -> str:
    if section.strip():
        return section.strip()[:2000]
    lines = [ln.strip() for ln in fallback.splitlines() if ln.strip()]
    intro_lines = [
        ln
        for ln in lines
        if len(ln) >= 20
        and not any(token in ln for token in ("학력", "경력", "자격", "면허", "이메일", "전화"))
    ]
    if intro_lines:
        return "\n".join(intro_lines[:6])[:2000]
    return ""


def parse_resume_text(text: str) -> dict:
    raw = (text or "").strip()
    sections = _split_sections(raw)
    educations = _parse_educations(sections.get("education", ""), raw)
    experiences = _parse_experiences(sections.get("experience", ""), raw)
    licenses = _parse_named_items(sections.get("license", ""), raw, license_mode=True)
    certifications = _parse_named_items(
        sections.get("certification", ""), raw, license_mode=False
    )
    self_introduction = _parse_self_introduction(
        sections.get("self_introduction", ""), raw
    )

    filled = sum(
        1
        for block in (educations, experiences, licenses, certifications)
        if block
    ) + (1 if self_introduction else 0)
    confidence = min(0.95, 0.35 + filled * 0.12)

    return {
        "educations": educations,
        "experiences": experiences,
        "licenses": licenses,
        "certifications": certifications,
        "selfIntroduction": self_introduction,
        "raw_text": raw,
        "confidence": round(confidence, 2),
    }
