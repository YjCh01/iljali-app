import asyncio
import json
import logging
from typing import Any

from fastapi import WebSocket

logger = logging.getLogger(__name__)


class ChatRealtimeHub:
    """지원 건별 WebSocket 구독 — 단일 API 프로세스용 (MVP)."""

    def __init__(self) -> None:
        self._rooms: dict[str, set[WebSocket]] = {}
        self._lock = asyncio.Lock()

    async def connect(self, application_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self._lock:
            self._rooms.setdefault(application_id, set()).add(websocket)
        await websocket.send_json(
            {"type": "connected", "application_id": application_id}
        )

    async def disconnect(self, application_id: str, websocket: WebSocket) -> None:
        async with self._lock:
            room = self._rooms.get(application_id)
            if room is None:
                return
            room.discard(websocket)
            if not room:
                self._rooms.pop(application_id, None)

    async def broadcast_message(self, application_id: str, payload: dict) -> None:
        envelope = {"type": "message", "payload": payload}
        async with self._lock:
            sockets = list(self._rooms.get(application_id, set()))
        if not sockets:
            return

        dead: list[WebSocket] = []
        for websocket in sockets:
            try:
                await websocket.send_json(envelope)
            except Exception:
                dead.append(websocket)
        for websocket in dead:
            await self.disconnect(application_id, websocket)

    async def handle_client_text(
        self, application_id: str, websocket: WebSocket, raw: str
    ) -> None:
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            return
        if not isinstance(data, dict):
            return
        msg_type = data.get("type")
        if msg_type == "ping":
            await websocket.send_json({"type": "pong"})


chat_realtime_hub = ChatRealtimeHub()
