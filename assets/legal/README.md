# 일자리 약관·정책 (2026-09-01 시행)

> `store/legal/*.md` — 앱 `assets/legal/` 및 PDF와 동기화.  
> 시행일: **2026년 9월 1일**

## 문서 목록

| 파일 | 용도 |
|------|------|
| `01_terms_of_service.md` | 이용약관 |
| `02_privacy_policy.md` | 개인정보처리방침 |
| `03_privacy_consent_notice.md` | 가입 시 수집·이용 동의 요약 |
| `04_electronic_finance.md` | 전자금융거래 이용약관 (토스페이먼츠) |
| `05_paid_service_refund.md` | 유료서비스·환불정책 |
| `06_location_based.md` | 위치기반서비스 이용약관 |
| `07_outsourcing_restrictions.md` | 아웃소싱·인력공급 이용 제한 |
| `08_marketing_consent.md` | 마케팅 수신 동의 (선택) |
| `09_community_chat.md` | 커뮤니티·채팅 운영정책 |
| `10_seeker_document_consent.md` | 신분증·통장 수집 동의 |
| `11_criminal_record_consent.md` | 범죄경력조회 동의 |

## 동기화

```bash
python3 scripts/sync_legal_docs.py
dart run tool/generate_legal_pdfs.dart
```

## 미기재 (접수 후 반영)

- [ ] 위치기반서비스사업 **신고번호** — 전자민원 접수 완료 후 `06_location_based.md` 제4조
