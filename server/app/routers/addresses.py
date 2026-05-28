import httpx
from fastapi import APIRouter, Query
from pydantic import BaseModel, Field

from app.config import settings

router = APIRouter(prefix="/v1/addresses", tags=["addresses"])

_JUSO_URL = "https://business.juso.go.kr/addrlink/addrLinkApi.do"
_KAKAO_ADDRESS_URL = "https://dapi.kakao.com/v2/local/search/address.json"
_KAKAO_KEYWORD_URL = "https://dapi.kakao.com/v2/local/search/keyword.json"


class AddressItem(BaseModel):
    road_address: str
    jibun_address: str | None = None
    dong_name: str | None = None
    building_name: str | None = None
    zip_code: str | None = None
    latitude: float | None = None
    longitude: float | None = None


class AddressSearchResponse(BaseModel):
    success: bool
    results: list[AddressItem] = Field(default_factory=list)
    mock: bool = False
    message: str | None = None


async def _geocode_kakao(client: httpx.AsyncClient, query: str) -> tuple[float, float] | None:
    if not settings.kakao_rest_api_key:
        return None
    response = await client.get(
        _KAKAO_ADDRESS_URL,
        params={"query": query},
        headers={"Authorization": f"KakaoAK {settings.kakao_rest_api_key}"},
        timeout=10.0,
    )
    if response.status_code >= 400:
        return None
    payload = response.json()
    documents = payload.get("documents") or []
    if not documents:
        return None
    doc = documents[0]
    try:
        return float(doc["y"]), float(doc["x"])
    except (KeyError, TypeError, ValueError):
        return None


async def _search_juso(client: httpx.AsyncClient, keyword: str) -> list[AddressItem]:
    response = await client.get(
        _JUSO_URL,
        params={
            "confmKey": settings.juso_confm_key,
            "currentPage": "1",
            "countPerPage": "15",
            "keyword": keyword,
            "resultType": "json",
        },
        timeout=12.0,
    )
    response.raise_for_status()
    payload = response.json()
    common = (payload.get("results") or {}).get("common") or {}
    if common.get("errorCode") not in (None, "0", 0):
        return []

    rows = (payload.get("results") or {}).get("juso") or []
    items: list[AddressItem] = []
    for row in rows:
        road = (row.get("roadAddr") or "").strip()
        if not road:
            continue
        coord = await _geocode_kakao(client, road)
        items.append(
            AddressItem(
                road_address=road,
                jibun_address=(row.get("jibunAddr") or "").strip() or None,
                dong_name=(row.get("emdNm") or "").strip() or None,
                building_name=(row.get("bdNm") or "").strip() or None,
                zip_code=(row.get("zipNo") or "").strip() or None,
                latitude=coord[0] if coord else None,
                longitude=coord[1] if coord else None,
            )
        )
    return items


async def _search_kakao_keyword(client: httpx.AsyncClient, keyword: str) -> list[AddressItem]:
    response = await client.get(
        _KAKAO_KEYWORD_URL,
        params={"query": keyword, "size": 15},
        headers={"Authorization": f"KakaoAK {settings.kakao_rest_api_key}"},
        timeout=10.0,
    )
    if response.status_code >= 400:
        return []
    payload = response.json()
    items: list[AddressItem] = []
    for doc in payload.get("documents") or []:
        road = (doc.get("road_address_name") or doc.get("address_name") or "").strip()
        if not road:
            continue
        try:
            lat = float(doc["y"])
            lng = float(doc["x"])
        except (KeyError, TypeError, ValueError):
            lat = None
            lng = None
        items.append(
            AddressItem(
                road_address=road,
                jibun_address=(doc.get("address_name") or "").strip() or None,
                dong_name=(doc.get("region_3depth_name") or "").strip() or None,
                building_name=(doc.get("place_name") or "").strip() or None,
                latitude=lat,
                longitude=lng,
            )
        )
    return items


def _mock_results(keyword: str) -> list[AddressItem]:
    samples = [
        AddressItem(
            road_address="서울특별시 강남구 테헤란로 152",
            jibun_address="서울특별시 강남구 역삼동 737",
            dong_name="역삼동",
            latitude=37.5001,
            longitude=127.0364,
        ),
        AddressItem(
            road_address="서울특별시 강남구 강남대로 396",
            jibun_address="서울특별시 강남구 역삼동 825",
            dong_name="역삼동",
            latitude=37.4979,
            longitude=127.0276,
        ),
        AddressItem(
            road_address="서울특별시 송파구 올림픽로 300",
            jibun_address="서울특별시 송파구 신천동 29",
            dong_name="신천동",
            latitude=37.5133,
            longitude=127.1002,
        ),
    ]
    trimmed = keyword.strip()
    return [
        item
        for item in samples
        if trimmed in item.road_address
        or (item.dong_name and trimmed in item.dong_name)
        or trimmed in (item.jibun_address or "")
    ]


@router.get("/search", response_model=AddressSearchResponse)
async def search_addresses(
    q: str = Query(min_length=1, max_length=80, description="동·도로명·건물명"),
):
    keyword = q.strip()
    if not keyword:
        return AddressSearchResponse(success=True, results=[])

    async with httpx.AsyncClient() as client:
        if settings.juso_confm_key:
            try:
                items = await _search_juso(client, keyword)
                if items:
                    return AddressSearchResponse(success=True, results=items)
            except httpx.HTTPError:
                pass

        if settings.kakao_rest_api_key:
            items = await _search_kakao_keyword(client, keyword)
            if items:
                return AddressSearchResponse(success=True, results=items)

    mock = _mock_results(keyword)
    if mock:
        return AddressSearchResponse(
            success=True,
            results=mock,
            mock=True,
            message="JUSO/Kakao 키 미설정 — 샘플 주소만 표시됩니다.",
        )

    return AddressSearchResponse(
        success=True,
        results=[],
        mock=True,
        message="주소 API 키를 server/.env 에 설정해 주세요. (JUSO_CONFM_KEY, KAKAO_REST_API_KEY)",
    )
