#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
chmod +x scripts/set_kakao_rest_key_on_server.sh

echo "========================================"
echo "  Kakao REST API 키 → 서버 등록"
echo "  (주소 검색 좌표 · 지도 핀)"
echo "========================================"
echo ""
echo "【이 키가 하는 일】"
echo "  · Juso로 찾은 도로명 주소 → 위도·경도 변환"
echo "  · 근무지·지점·푸시 거점 지도 핀 위치"
echo "  · health 의 kakao_geocode_configured: true"
echo ""
echo "【카카오 로그인 키와 다른가?】"
echo "  · 보통 같습니다. 카카오 앱의 「REST API 키」 한 개로"
echo "    로그인(KAKAO_OAUTH_CLIENT_ID) + 주소좌표(KAKAO_REST_API_KEY) 둘 다 씁니다."
echo "  · 이 도구는 서버 주소용 KAKAO_REST_API_KEY 만 넣습니다."
echo "    (로그인은 이미 되고 있으면 건드리지 않습니다)"
echo ""
echo "【키 복사 방법】"
echo "  1. https://developers.kakao.com 접속 → 로그인"
echo "  2. 내 애플리케이션 → 「일자리」 앱 선택"
echo "  3. 앱 설정 → 앱 키 → 「REST API 키」 복사 (32자)"
echo "     (Native / JavaScript 키 아님!)"
echo "  4. 아래에 붙여넣기"
echo ""
echo "【Juso와 함께 쓰면】"
echo "  Juso = 도로명 주소 목록"
echo "  Kakao = 그 주소의 좌표"
echo "  → 둘 다 있으면 주소 검색 품질이 가장 좋습니다."
echo ""

read -r -p "Kakao REST API 키: " KAKAO_KEY
echo ""

if [[ -z "${KAKAO_KEY}" ]]; then
  echo "키를 입력해야 합니다."
  read -r -p "엔터를 누르면 종료합니다."
  exit 1
fi

echo "[진행] 서버 접속 중… (비밀번호 물어보면 root 비밀번호 입력)"
echo ""

./scripts/set_kakao_rest_key_on_server.sh "${KAKAO_KEY}"

echo ""
echo "완료. 확인:"
echo "  https://api.iljari.app/health"
echo "    → kakao_geocode_configured: true"
echo ""
echo "앱/웹에서 테스트:"
echo "  iljari.app → 기업 → 공고 등록 → 근무지 주소 검색"
echo "  또는 푸시 알림 거점 설정 → 주소 검색"
echo ""
read -r -p "엔터를 누르면 종료합니다."
