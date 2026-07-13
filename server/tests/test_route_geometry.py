"""Road-following shuttle polyline densify (OSRM-compatible provider)."""

from app.services.route_geometry_service import (
    StraightLineProvider,
    apply_road_geometry_to_route,
    clear_geometry_cache,
    densify_stops_polyline,
)


class _FakeRoadProvider:
    def route_between(self, *, from_lat, from_lng, to_lat, to_lng):
        # Midpoint bend so result is denser than 2 endpoints
        mid_lat = (from_lat + to_lat) / 2 + 0.001
        mid_lng = (from_lng + to_lng) / 2 - 0.001
        return [
            {"latitude": from_lat, "longitude": from_lng},
            {"latitude": mid_lat, "longitude": mid_lng},
            {"latitude": to_lat, "longitude": to_lng},
        ]


def setup_function():
    clear_geometry_cache()


def test_densify_stitches_pairs_without_duplicating_joints():
    stops = [
        {"coordinate": {"latitude": 37.50, "longitude": 127.00}},
        {"coordinate": {"latitude": 37.51, "longitude": 127.01}},
        {"coordinate": {"latitude": 37.52, "longitude": 127.02}},
    ]
    points = densify_stops_polyline(
        stops, provider=_FakeRoadProvider(), use_cache=False
    )
    # 3 + 2 (second segment without duplicated start) = 5
    assert len(points) == 5
    assert points[0]["latitude"] == 37.50
    assert points[-1]["latitude"] == 37.52


def test_densify_falls_back_to_straight_when_provider_fails():
    class _Fail:
        def route_between(self, **_kwargs):
            return None

    stops = [
        {"latitude": 37.5, "longitude": 127.0},
        {"latitude": 37.6, "longitude": 127.1},
    ]
    points = densify_stops_polyline(stops, provider=_Fail(), use_cache=False)
    assert points == [
        {"latitude": 37.5, "longitude": 127.0},
        {"latitude": 37.6, "longitude": 127.1},
    ]


def test_apply_road_geometry_overwrites_polyline_points():
    route = {
        "id": "r1",
        "companyKey": "1122334455",
        "stops": [
            {"coordinate": {"latitude": 37.5, "longitude": 127.0}},
            {"coordinate": {"latitude": 37.51, "longitude": 127.01}},
        ],
        "polylinePoints": [
            {"latitude": 37.5, "longitude": 127.0},
            {"latitude": 37.51, "longitude": 127.01},
        ],
    }
    enriched = apply_road_geometry_to_route(route, provider=_FakeRoadProvider())
    assert len(enriched["polylinePoints"]) == 3
    assert enriched["polylinePoints"][1]["latitude"] != 37.5


def test_straight_provider_is_two_points():
    points = StraightLineProvider().route_between(
        from_lat=1.0, from_lng=2.0, to_lat=3.0, to_lng=4.0
    )
    assert points == [
        {"latitude": 1.0, "longitude": 2.0},
        {"latitude": 3.0, "longitude": 4.0},
    ]
