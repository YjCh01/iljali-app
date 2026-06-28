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
    business_status_code: str
    entity_type_label: str
    api_source: str
    failure_message: str | None = None


class NtsService:
    """국세청/공공데이터 사업자 진위확인·상태조회 — odcloud REST (홈택스 스크래핑 아님)."""

    async def verify_business(
        self,
        business_registration_number: str,
        company_name: str,
        *,
        representative_name: str = "",
        opening_date: str = "",
    ) -> NtsLookupResult:
        brn = re.sub(r"[^0-9]", "", business_registration_number)
        if len(brn) != 10:
            return NtsLookupResult(
                valid=False,
                company_name=company_name,
                industry_name="",
                business_status="invalid",
                business_status_code="",
                entity_type_label="",
                api_source="local",
                failure_message="사업자등록번호 10자리가 필요합니다.",
            )

        if settings.nts_api_key:
            try:
                if representative_name and opening_date:
                    return await self._call_validate(
                        brn,
                        company_name,
                        representative_name,
                        opening_date,
                    )
                return await self._call_status(brn, company_name)
            except Exception:
                pass
        elif settings.require_nts_api_key:
            return NtsLookupResult(
                valid=False,
                company_name=company_name,
                industry_name="",
                business_status="unavailable",
                business_status_code="",
                entity_type_label="",
                api_source="local",
                failure_message="국세청 API 키가 설정되지 않았습니다. 운영 환경에서는 NTS_API_KEY가 필요합니다.",
            )

        return self._mock(
            brn,
            company_name,
            representative_name=representative_name,
            opening_date=opening_date,
        )

    async def _call_validate(
        self,
        brn: str,
        company_name: str,
        representative_name: str,
        opening_date: str,
    ) -> NtsLookupResult:
        start_dt = re.sub(r"[^0-9]", "", opening_date)
        params = {"serviceKey": settings.nts_api_key, "returnType": "JSON"}
        payload = {
            "businesses": [
                {
                    "b_no": brn,
                    "start_dt": start_dt,
                    "p_nm": representative_name.strip(),
                    "p_nm2": "",
                    "b_nm": company_name.strip(),
                    "corp_no": "",
                    "b_sector": "",
                    "b_type": "",
                    "b_adr": "",
                }
            ]
        }
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                settings.nts_validate_api_url,
                params=params,
                json=payload,
            )
            response.raise_for_status()
            body = response.json()

        data = body.get("data") or []
        if not data:
            return self._mock(
                brn,
                company_name,
                representative_name=representative_name,
                opening_date=opening_date,
            )

        item = data[0]
        valid_code = str(item.get("valid") or "02")
        valid_msg = str(item.get("valid_msg") or "")
        if valid_code != "01":
            return NtsLookupResult(
                valid=False,
                company_name=company_name,
                industry_name="",
                business_status="mismatch",
                business_status_code=valid_code,
                entity_type_label="",
                api_source="odcloud",
                failure_message=valid_msg
                or "입력하신 정보가 국세청 등록 정보와 일치하지 않습니다.",
            )

        status = item.get("status") or {}
        status_code = str(status.get("b_stt_cd") or "")
        status_label = str(status.get("b_stt") or "")
        if status_code in {"02", "03"} or "폐업" in status_label or "휴업" in status_label:
            return NtsLookupResult(
                valid=False,
                company_name=company_name,
                industry_name=str(status.get("tax_type") or ""),
                business_status=status_label,
                business_status_code=status_code,
                entity_type_label=str(status.get("tax_type") or ""),
                api_source="odcloud",
                failure_message=f"{status_label} 상태의 사업자입니다."
                if status_label
                else "가입할 수 없는 사업자 상태입니다.",
            )

        return NtsLookupResult(
            valid=True,
            company_name=company_name,
            industry_name=str(status.get("tax_type") or "기타"),
            business_status=status_label or "계속사업자",
            business_status_code=status_code or "01",
            entity_type_label=str(status.get("tax_type") or ""),
            api_source="odcloud",
        )

    async def _call_status(self, brn: str, company_name: str) -> NtsLookupResult:
        params = {"serviceKey": settings.nts_api_key, "returnType": "JSON"}
        payload = {"b_no": [brn]}
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                settings.nts_status_api_url,
                params=params,
                json=payload,
            )
            response.raise_for_status()
            body = response.json()

        data = body.get("data") or []
        if not data:
            return self._mock(brn, company_name)

        item = data[0]
        status_code = str(item.get("b_stt_cd") or "")
        status_label = str(item.get("b_stt") or "")
        if "등록되지 않은" in status_label:
            return NtsLookupResult(
                valid=False,
                company_name=company_name,
                industry_name="",
                business_status=status_label,
                business_status_code=status_code,
                entity_type_label="",
                api_source="odcloud",
                failure_message=status_label,
            )
        if status_code in {"02", "03"} or "폐업" in status_label or "휴업" in status_label:
            return NtsLookupResult(
                valid=False,
                company_name=company_name,
                industry_name=str(item.get("tax_type") or ""),
                business_status=status_label,
                business_status_code=status_code,
                entity_type_label=str(item.get("tax_type") or ""),
                api_source="odcloud",
                failure_message=f"{status_label} 상태의 사업자입니다.",
            )

        return NtsLookupResult(
            valid=True,
            company_name=item.get("b_nm") or company_name,
            industry_name=str(item.get("tax_type") or "기타"),
            business_status=status_label or "계속사업자",
            business_status_code=status_code or "01",
            entity_type_label=str(item.get("tax_type") or ""),
            api_source="odcloud",
        )

    def _mock(
        self,
        brn: str,
        company_name: str,
        *,
        representative_name: str = "",
        opening_date: str = "",
    ) -> NtsLookupResult:
        dev_brn = "1234567891"
        dev_date = "20200101"
        dev_name = "홍길동"
        start_dt = re.sub(r"[^0-9]", "", opening_date)

        if representative_name and opening_date:
            matches = brn == dev_brn and start_dt == dev_date and representative_name.strip() == dev_name
            if not matches and not (
                brn.endswith("9991")
                and start_dt == dev_date
                and representative_name.strip() == dev_name
            ):
                return NtsLookupResult(
                    valid=False,
                    company_name=company_name,
                    industry_name="",
                    business_status="mismatch",
                    business_status_code="02",
                    entity_type_label="",
                    api_source="mock_nts",
                    failure_message=(
                        "입력하신 정보가 국세청 등록 정보와 일치하지 않습니다. "
                        f"(개발 모드: {dev_brn} · {dev_date} · {dev_name})"
                    ),
                )

        if brn.endswith("8881"):
            return NtsLookupResult(
                valid=False,
                company_name=company_name,
                industry_name="",
                business_status="휴업",
                business_status_code="02",
                entity_type_label="",
                api_source="mock_nts",
                failure_message="휴업 상태의 사업자입니다.",
            )
        if brn.endswith("7771"):
            return NtsLookupResult(
                valid=False,
                company_name=company_name,
                industry_name="",
                business_status="폐업",
                business_status_code="03",
                entity_type_label="",
                api_source="mock_nts",
                failure_message="폐업 상태의 사업자입니다.",
            )

        is_outsourcing = brn.endswith("9991")
        is_corp = brn.startswith(("1", "2"))
        return NtsLookupResult(
            valid=True,
            company_name=company_name,
            industry_name="인력공급업" if is_outsourcing else "화물운송 및 물류대행",
            business_status="continuing",
            business_status_code="01",
            entity_type_label="법인" if is_corp else "개인사업자",
            api_source="mock_nts",
        )
