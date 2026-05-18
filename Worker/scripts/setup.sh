#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────
# 라운드온 Cloudflare 인프라 초기 셋업 (wrangler v4 호환)
# 32-CLOUDFLARE_SETUP §3, §4, §5
#
# 사전 조건:
#   - npx wrangler login 완료
#   - Cloudflare 대시보드에서 R2 활성화 (R2 → Get started → 무료 플랜 동의)
#
# 실행:
#   bash scripts/setup.sh
# ──────────────────────────────────────────────────────────────────
set -uo pipefail

echo "=== 라운드온 Cloudflare 인프라 셋업 (wrangler v4) ==="

WRANGLER="npx wrangler"

# binding|name 쌍 (macOS bash 3.x associative array 미지원 회피)
PAIRS=(
  "KV_META|ROUNDON_META"
  "KV_RATELIMIT|ROUNDON_RATELIMIT"
  "KV_PINLOCK|ROUNDON_PINLOCK"
  "KV_SESSION|ROUNDON_SESSION"
)

extract_id() {
  # 입력: wrangler 출력
  # 출력: 32-hex id 또는 빈 문자열
  echo "$1" | grep -oE 'id = "[a-f0-9]{32}"' | head -1 | grep -oE '[a-f0-9]{32}' || echo ""
}

lookup_existing_id() {
  # 인자: namespace title (예: roundon-viewer-ROUNDON_META)
  local TITLE="$1"
  $WRANGLER kv namespace list 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
title = '$TITLE'
for ns in data:
    if ns.get('title') == title:
        print(ns.get('id', ''))
        break
" 2>/dev/null || echo ""
}

# ── 1. KV 네임스페이스 생성 ────────────────────────────────────
echo ""
echo ">>> KV 네임스페이스 생성/조회 중..."

RESULTS=()
for i in "${!PAIRS[@]}"; do
  PAIR="${PAIRS[$i]}"
  BINDING="${PAIR%|*}"
  NAME="${PAIR#*|}"
  echo "  [$((i+1))/4] $NAME (binding=$BINDING)"

  OUTPUT=$($WRANGLER kv namespace create "$NAME" 2>&1) || true
  ID=$(extract_id "$OUTPUT")

  if [[ -z "$ID" ]]; then
    # 이미 존재 — list로 조회 (worker 이름 prefix 포함)
    WORKER_NAME=$(grep -E '^name\s*=' wrangler.toml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
    TITLE="${WORKER_NAME}-${NAME}"
    ID=$(lookup_existing_id "$TITLE")
    if [[ -n "$ID" ]]; then
      echo "    (이미 존재) → ID: $ID"
    else
      echo "    [경고] ID 추출 실패"
    fi
  else
    echo "    생성 완료 → ID: $ID"
  fi

  RESULTS+=("$BINDING|$ID")
done

# ── 2. wrangler.toml 자동 업데이트 ────────────────────────────
echo ""
echo ">>> wrangler.toml KV ID 자동 교체 중..."
cp wrangler.toml wrangler.toml.bak
echo "  백업: wrangler.toml.bak"

for RESULT in "${RESULTS[@]}"; do
  BINDING="${RESULT%|*}"
  ID="${RESULT#*|}"
  if [[ -z "$ID" ]]; then
    echo "  [건너뜀] $BINDING — ID 없음"
    continue
  fi
  python3 -c "
import re
with open('wrangler.toml', 'r') as f:
    content = f.read()
pattern = r'(binding\s*=\s*\"$BINDING\"\s*\n\s*id\s*=\s*\")[^\"]+(\")'
new_content, count = re.subn(pattern, r'\g<1>$ID\g<2>', content)
with open('wrangler.toml', 'w') as f:
    f.write(new_content)
print(f'  $BINDING → $ID (치환 {count}회)')
"
done

# ── 3. R2 버킷 생성 ──────────────────────────────────────────────
echo ""
echo ">>> R2 버킷 생성 중..."
R2_OUTPUT=$($WRANGLER r2 bucket create roundon-photos 2>&1) || true
echo "$R2_OUTPUT" | sed 's/^/  /'

if echo "$R2_OUTPUT" | grep -q "Please enable R2"; then
  echo ""
  echo "  ⚠️  R2가 계정에서 비활성 상태입니다."
  echo "      Cloudflare 대시보드 → 좌측 R2 → 'Get started' 클릭 → 무료 플랜 동의"
  echo "      → 이 스크립트를 다시 실행하세요."
  echo ""
fi

# R2 Lifecycle Rule
echo ""
echo ">>> R2 Lifecycle Rule 설정 시도 중 (7일 자동 삭제)..."
LIFECYCLE_JSON="/tmp/roundon-lifecycle.json"
cat > "$LIFECYCLE_JSON" <<'EOF'
{
  "rules": [
    {
      "id": "expire-7-days",
      "enabled": true,
      "conditions": { "prefix": "" },
      "deleteObjectsTransition": { "condition": { "type": "Age", "maxAge": 604800 } }
    }
  ]
}
EOF
$WRANGLER r2 bucket lifecycle set roundon-photos --file "$LIFECYCLE_JSON" 2>&1 | sed 's/^/  /' || {
  echo "  [주의] lifecycle CLI 실패 — Cloudflare 대시보드에서 수동 설정 필요:"
  echo "    R2 → roundon-photos → Settings → Lifecycle Rules"
  echo "    Action: Expire current versions of objects, Days after upload: 7"
}

# ── 4. 안내 ──────────────────────────────────────────────────────
echo ""
echo "=== 다음 단계 (수동) ==="
echo ""
echo "1) 시크릿 등록:"
echo "   openssl rand -base64 32  # 출력값 메모"
echo "   npx wrangler secret put SESSION_HMAC_KEY --env production"
echo "   # 프롬프트에 위 값 paste"
echo ""
echo "   openssl rand -base64 32  # 다른 값"
echo "   npx wrangler secret put BCRYPT_PEPPER --env production"
echo ""
echo "2) Worker 배포:"
echo "   npx wrangler deploy --env production"
echo ""
echo "3) DNS CNAME (Cloudflare 대시보드 → DNS):"
echo "   Type=CNAME, Name=golf, Target=<account>.workers.dev, Proxy=ON"
echo "   (deploy 후 route는 wrangler.toml에 의해 자동 등록)"
echo ""
echo "4) 동작 확인:"
echo "   curl https://golf.zerolive.co.kr/healthz"
echo ""
echo "=== KV ID 요약 ==="
for RESULT in "${RESULTS[@]}"; do
  echo "  ${RESULT%|*} = ${RESULT#*|}"
done
echo ""
echo "=== 셋업 스크립트 완료 ==="
