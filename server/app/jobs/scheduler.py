"""백그라운드 reverify 배치 스케줄러."""

from __future__ import annotations

import asyncio
import logging

from app.config import settings
from app.database import SessionLocal
from app.jobs.reverify_batch_job import process_reverify_batch

logger = logging.getLogger(__name__)

_task: asyncio.Task | None = None


async def _run_loop() -> None:
    interval = max(1, settings.reverify_batch_interval_hours) * 3600
    while True:
        try:
            db = SessionLocal()
            try:
                result = process_reverify_batch(db)
                logger.info("reverify batch: %s", result)
            finally:
                db.close()
        except Exception as exc:
            logger.exception("reverify batch error: %s", exc)
        await asyncio.sleep(interval)


def start_reverify_scheduler() -> None:
    global _task
    if not settings.reverify_batch_enabled:
        return
    if _task is not None and not _task.done():
        return
    _task = asyncio.create_task(_run_loop())
    logger.info(
        "reverify scheduler started (every %sh)",
        settings.reverify_batch_interval_hours,
    )


async def stop_reverify_scheduler() -> None:
    global _task
    if _task is None:
        return
    _task.cancel()
    try:
        await _task
    except asyncio.CancelledError:
        pass
    _task = None
