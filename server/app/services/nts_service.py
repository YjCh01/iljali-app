import re
from dataclasses import dataclass

import httpx

from app.config import settings


@dataclass
class NtsLookupResult:
    valid: bool
    company_name: str
    industry_name: str
    business_status: str
    entity_type_label: str
    api_source: str


class NtsService:
    """국세청/공공데이터 사업자 상태조회 — 키 없으면 mock."""

    async def verify_business(
        self, business_registration_number: str, company_name: str
    ) -> NtsLookupResult:
        brn = re.sub(r"[^0-9]", "", business_registration_number)
        if len(brn) != 10:
            return NtsLookupResult(
                valid=False,
                company_name=company_name,
                industry_name="",
                business_status="invalid",
                entity_type_label="",
                api_source="local",
            )

        if settings.nts_api_key:
            try:
                return await self._call_odcloud(brn, company_name)
            except Exception:
                pass

        return self._mock(brn, company_name)

    async def _call_odcloud(self, brn: str, company_name: str) -> NtsLookupResult:
        params = {
            "serviceKey": settings.nts_api_key,
            "returnType": "JSON",
            "b_no": brn,
        }
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(settings.nts_api_url, params=params)
            response.raise_for_status()
            payload = response.json()

        items = payload.get("data") or payload.get("items") or []
        if isinstance(items, dict):
            items = [items]
        if not items:
            return self._mock(brn, company_name)

        item = items[0] if isinstance(items, list) else items
        status_code = str(
            item.get("b_stt_cd") or item.get("tax_type") or item.get("status") or "01"
        )
        valid = status_code in {"01", "02", "continuing", "1"}
        industry = (
            item.get("tax_type")
            or item.get("b_sector")
            or item.get("industry")
            or "기타"
        )
        entity = item.get("b_type") or ("법인" if brn.startswith(("1", "2")) else "개인사업자")
        return NtsLookupResult(
            valid=valid,
            company_name=item.get("b_nm") or company_name,
            industry_name=str(industry),
            business_status=status_code,
            entity_type_label=str(entity),
            api_source="odcloud",
        )

    def _mock(self, brn: str, company_name: str) -> NtsLookupResult:
        is_outsourcing = brn.endswith("9999")
        is_corp = brn.startswith(("1", "2"))
        return NtsLookupResult(
            valid=True,
            company_name=company_name,
            industry_name="인력공급업" if is_outsourcing else "화물운송 및 물류대행",
            business_status="continuing",
            entity_type_label="법인" if is_corp else "개인사업자",
            api_source="mock_nts",
        )
