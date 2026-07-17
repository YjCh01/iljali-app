"""공고·합의에 포함된 근무 시각 파싱 — lib/core/hiring/work_schedule_time.dart 포팅."""

from __future__ import annotations

import re
from datetime import date, datetime

_RANGE_RE = re.compile(r"(\d{1,2}):(\d{2})\s*[~\-–]\s*(\d{1,2}):(\d{2})")
_CLOCK_RE = re.compile(r"(\d{1,2}):(\d{2})")


def parse_start_clock(work_schedule: str) -> tuple[int, int] | None:
    """`09:00–18:00`, `09:00-18:00`, `09:00~18:00` 등에서 시작 시각."""
    match = _RANGE_RE.search(work_schedule or "")
    if match is None:
        return None
    return int(match.group(1)), int(match.group(2))


def parse_clock(value: str) -> tuple[int, int] | None:
    """`09:30` 같은 단일 시각 문자열 파싱 — 셔틀 탑승 시각 등."""
    match = _CLOCK_RE.search(value or "")
    if match is None:
        return None
    return int(match.group(1)), int(match.group(2))


def work_start_at(work_date: date, work_schedule: str) -> datetime | None:
    clock = parse_start_clock(work_schedule)
    if clock is None:
        return None
    hour, minute = clock
    return datetime(work_date.year, work_date.month, work_date.day, hour, minute)


def combine_date_and_clock(the_date: date, clock_text: str) -> datetime | None:
    clock = parse_clock(clock_text)
    if clock is None:
        return None
    hour, minute = clock
    return datetime(the_date.year, the_date.month, the_date.day, hour, minute)
