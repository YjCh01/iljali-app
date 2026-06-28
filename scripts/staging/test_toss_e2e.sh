#!/usr/bin/env bash
# Toss sandbox smoke — charge URL 생성 + mock confirm (키 없으면 mock)
set -euo pipefail

API_URL="${1:-http://localhost:8000}"
ORDER_ID="E2E-$(date +%s)"

echo "[toss-e2e] API: ${API_URL}"

charge="$(curl -sf -X POST "${API_URL}/v1/payments/charge" \
  -H 'Content-Type: application/json' \
  -d "{\"order_id\":\"${ORDER_ID}\",\"order_name\":\"E2E 패키지\",\"amount_krw\":5000,\"company_key\":\"1234567890\",\"web_checkout\":true}")"

echo "${charge}" | python3 -c "import sys,json; d=json.load(sys.stdin); print('mock:', d.get('mock'), 'checkout:', (d.get('checkout_url') or '')[:80])"

if echo "${charge}" | python3 -c "import sys,json; exit(0 if json.load(sys.stdin).get('mock') else 1)"; then
  confirm="$(curl -sf -X POST "${API_URL}/v1/payments/confirm" \
    -H 'Content-Type: application/json' \
    -d "{\"payment_key\":\"e2e-test-key\",\"order_id\":\"${ORDER_ID}\",\"amount_krw\":5000}")"
  echo "${confirm}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('success'), d"
  echo "[toss-e2e] mock charge+confirm OK"
else
  checkout="$(echo "${charge}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('checkout_url',''))")"
  echo "[toss-e2e] sandbox checkout URL ready — browser에서 결제 후 /payment-success 로 리다이렉트 확인"
  echo "  ${checkout}"
fi
