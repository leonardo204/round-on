#!/usr/bin/env bash
# .api-keys.local 에서 키를 추출해 Secrets.xcconfig에 자동 동기화.
# 둘 다 gitignore 대상 — 외부 노출 없음.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL="$ROOT/.api-keys.local"
XCCONFIG="$ROOT/Secrets.xcconfig"

if [[ ! -f "$LOCAL" ]]; then
  echo "ERROR: $LOCAL 없음. 카카오 디벨로퍼스에서 REST API 키 발급 후 다음 형식으로 생성:" >&2
  echo "  KAKAO_REST_API_KEY=발급된키" >&2
  exit 1
fi

KEY=$(grep "^KAKAO_REST_API_KEY=" "$LOCAL" | cut -d'=' -f2-)
if [[ -z "$KEY" ]]; then
  echo "ERROR: $LOCAL 에 KAKAO_REST_API_KEY 값이 비어있음" >&2
  exit 1
fi

BEARER=$(grep "^ROUNDON_API_BEARER=" "$LOCAL" | cut -d'=' -f2- || true)

cat > "$XCCONFIG" <<XCCONF
// Secrets.xcconfig — 로컬 전용, .gitignore에 포함됨. 절대 커밋 금지.
// scripts/sync-secrets.sh 가 .api-keys.local 에서 자동 생성.
// 갱신: scripts/sync-secrets.sh 재실행.

KAKAO_REST_API_KEY = $KEY
ROUNDON_API_BEARER = $BEARER
XCCONF

echo "Secrets.xcconfig 동기화 완료 (KAKAO ${#KEY}자, ROUNDON ${#BEARER}자)"
