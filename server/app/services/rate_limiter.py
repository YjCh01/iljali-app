"""경량 인메모리 rate limiter.

별도 인프라(Redis 등) 없이 단일 프로세스 배포에 맞춘 최소 구현 — 요청자 IP + 라우트
이름을 키로 고정 윈도우 방식 카운트를 관리한다. pytest 실행 중에는 우회되어(테스트가
같은 엔드포인트를 반복 호출하는 것과 충돌하지 않도록) 실제 차단 로직은
`check_rate_limit`을 직접 호출하는 단위테스트로 검증한다.
"""

from __future__ import annotations

import sys
import time
from collections import defaultdict, deque

from fastapi import HTTPException, Request

_hits: dict[str, deque[float]] = defaultdict(deque)


def _bypassed_for_tests() -> bool:
    return "pytest" in sys.modules


def reset_all() -> None:
    """테스트에서 케이스 간 상태 격리를 위해 사용."""
    _hits.clear()


def check_rate_limit(key: str, *, max_calls: int, window_sec: float) -> bool:
    """허용되면 True, 한도 초과면 False. 호출 자체를 즉시 기록한다."""
    now = time.monotonic()
    dq = _hits[key]
    while dq and now - dq[0] > window_sec:
        dq.popleft()
    if len(dq) >= max_calls:
        return False
    dq.append(now)
    return True


def rate_limit(name: str, *, max_calls: int, window_sec: float):
    """FastAPI 라우트 dependency — IP당 윈도우 내 호출 횟수를 제한한다."""

    def dependency(request: Request) -> None:
        if _bypassed_for_tests():
            return
        ip = request.client.host if request.client else "unknown"
        key = f"{name}:{ip}"
        if not check_rate_limit(key, max_calls=max_calls, window_sec=window_sec):
            raise HTTPException(
                status_code=429,
                detail="요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.",
            )

    return dependency
