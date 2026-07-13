"""정류장 사이 도로 추종 경로 — OSRM driving (Naver Directions 교체 가능)."""

from __future__ import annotations

import hashlib
import logging
import os
from typing import Any, Protocol

import httpx

logger = logging.getLogger(__name__)

_OSRM_BASE = os.getenv(
    "OSRM_BASE_URL",
    "https://router.project-osrm.org",
).rstrip("/")
_TIMEOUT_SEC = float(os.getenv("OSRM_TIMEOUT_SEC", "8"))
_PAIR_CACHE: dict[str, list[dict[str, float]]] = {}
_CACHE_MAX = 512


class RouteGeometryProvider(Protocol):
    def route_between(
        self,
        *,
        from_lat: float,
        from_lng: float,
        to_lat: float,
        to_lng: float,
    ) -> list[dict[str, float]] | None:
        """Return polyline points [{latitude, longitude}, ...] or None on failure."""


def _pair_key(from_lat: float, from_lng: float, to_lat: float, to_lng: float) -> str:
    raw = f"{from_lat:.5f},{from_lng:.5f}->{to_lat:.5f},{to_lng:.5f}"
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()


def _cache_get(key: str) -> list[dict[str, float]] | None:
    return _PAIR_CACHE.get(key)


def _cache_set(key: str, points: list[dict[str, float]]) -> None:
    if len(_PAIR_CACHE) >= _CACHE_MAX:
        # Drop an arbitrary oldest-ish entry
        _PAIR_CACHE.pop(next(iter(_PAIR_CACHE)), None)
    _PAIR_CACHE[key] = points


def clear_geometry_cache() -> None:
    _PAIR_CACHE.clear()


class OsrmDrivingProvider:
    """OpenStreetMap OSRM — no API key required."""

    def __init__(self, *, base_url: str | None = None, timeout_sec: float | None = None):
        self.base_url = (base_url or _OSRM_BASE).rstrip("/")
        self.timeout_sec = timeout_sec if timeout_sec is not None else _TIMEOUT_SEC

    def route_between(
        self,
        *,
        from_lat: float,
        from_lng: float,
        to_lat: float,
        to_lng: float,
    ) -> list[dict[str, float]] | None:
        url = (
            f"{self.base_url}/route/v1/driving/"
            f"{from_lng},{from_lat};{to_lng},{to_lat}"
        )
        try:
            with httpx.Client(timeout=self.timeout_sec) as client:
                response = client.get(
                    url,
                    params={"overview": "full", "geometries": "geojson"},
                )
            if response.status_code != 200:
                logger.warning(
                    "OSRM HTTP %s for %s,%s -> %s,%s",
                    response.status_code,
                    from_lat,
                    from_lng,
                    to_lat,
                    to_lng,
                )
                return None
            body = response.json()
            if body.get("code") != "Ok":
                logger.warning("OSRM code=%s", body.get("code"))
                return None
            routes = body.get("routes") or []
            if not routes:
                return None
            coords = (routes[0].get("geometry") or {}).get("coordinates") or []
            points: list[dict[str, float]] = []
            for pair in coords:
                if not isinstance(pair, (list, tuple)) or len(pair) < 2:
                    continue
                lon, lat = float(pair[0]), float(pair[1])
                points.append({"latitude": lat, "longitude": lon})
            return points if len(points) >= 2 else None
        except Exception as error:  # noqa: BLE001 — network/parse soft-fail
            logger.warning("OSRM route failed: %s", error)
            return None


class StraightLineProvider:
    """Fallback — stop-to-stop straight segment."""

    def route_between(
        self,
        *,
        from_lat: float,
        from_lng: float,
        to_lat: float,
        to_lng: float,
    ) -> list[dict[str, float]] | None:
        return [
            {"latitude": from_lat, "longitude": from_lng},
            {"latitude": to_lat, "longitude": to_lng},
        ]


def _stop_lat_lng(stop: dict[str, Any]) -> tuple[float, float] | None:
    coord = stop.get("coordinate")
    if isinstance(coord, dict):
        lat = coord.get("latitude")
        lng = coord.get("longitude")
    else:
        lat = stop.get("latitude")
        lng = stop.get("longitude")
    try:
        if lat is None or lng is None:
            return None
        return float(lat), float(lng)
    except (TypeError, ValueError):
        return None


def densify_stops_polyline(
    stops: list[dict[str, Any]],
    *,
    provider: RouteGeometryProvider | None = None,
    use_cache: bool = True,
) -> list[dict[str, float]]:
    """Stitch consecutive stop pairs into a road-following polyline.

    On provider failure for a pair, falls back to a straight segment.
    """
    if len(stops) < 2:
        return []

    if provider is None:
        kind = os.getenv("ROUTE_GEOMETRY_PROVIDER", "osrm").strip().lower()
        provider = (
            StraightLineProvider()
            if kind in {"straight", "fallback", "off"}
            else OsrmDrivingProvider()
        )
    driving = provider
    straight = StraightLineProvider()
    result: list[dict[str, float]] = []

    for i in range(len(stops) - 1):
        a = _stop_lat_lng(stops[i])
        b = _stop_lat_lng(stops[i + 1])
        if a is None or b is None:
            continue
        from_lat, from_lng = a
        to_lat, to_lng = b
        key = _pair_key(from_lat, from_lng, to_lat, to_lng)
        segment: list[dict[str, float]] | None = None
        if use_cache:
            segment = _cache_get(key)
        if segment is None:
            segment = driving.route_between(
                from_lat=from_lat,
                from_lng=from_lng,
                to_lat=to_lat,
                to_lng=to_lng,
            )
            if segment is None:
                segment = straight.route_between(
                    from_lat=from_lat,
                    from_lng=from_lng,
                    to_lat=to_lat,
                    to_lng=to_lng,
                )
            if use_cache and segment is not None:
                _cache_set(key, segment)
        if not segment:
            continue
        if not result:
            result.extend(segment)
        else:
            # Avoid duplicating shared endpoint
            result.extend(segment[1:] if len(segment) > 1 else segment)

    return result


def apply_road_geometry_to_route(
    route: dict[str, Any],
    *,
    provider: RouteGeometryProvider | None = None,
) -> dict[str, Any]:
    """Mutate a copy of route with densified polylinePoints from stops."""
    data = dict(route)
    stops = data.get("stops")
    if not isinstance(stops, list) or len(stops) < 2:
        return data
    points = densify_stops_polyline(stops, provider=provider)
    if len(points) >= 2:
        data["polylinePoints"] = points
    elif not data.get("polylinePoints"):
        # Keep straight stop coords if densify produced nothing usable
        fallback: list[dict[str, float]] = []
        for stop in stops:
            pair = _stop_lat_lng(stop)
            if pair is None:
                continue
            fallback.append({"latitude": pair[0], "longitude": pair[1]})
        if len(fallback) >= 2:
            data["polylinePoints"] = fallback
    return data
