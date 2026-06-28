#!/bin/bash
# → 도구_실서비스한방배포(app포함).command 와 동일 (하위 호환)
cd "$(dirname "$0")"
exec ./scripts/deploy_prod_all.sh "$@"
