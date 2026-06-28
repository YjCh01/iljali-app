# NCP ACG — 인바운드 필수 포트
#
# NCP 콘솔 → Server → iljari-api-01 → ACG(방화벽)
# 인바운드 규칙 추가:
#   TCP 80   (0.0.0.0/0) — HTTP
#   TCP 443  (0.0.0.0/0) — HTTPS  ← 없으면 https://iljari.app 타임아웃
#
# 443 열린 뒤: https://iljari.app 정상
