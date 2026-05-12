#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────
# 라운드온 Cloudflare 인프라 초기 셋업
# 32-CLOUDFLARE_SETUP §3, §4, §5
#
# 사전 조건:
#   - wrangler 설치 + wrangler login 완료
#   - Cloudflare 계정 ID / Zone ID 준비
#   - API Token에 Workers/KV/R2/Route 편집 권한 부여
#
# 실행:
#   bash scripts/setup.sh
# ──────────────────────────────────────────────────────────────────
set -euo pipefail

echo "=== 라운드온 Cloudflare 인프라 셋업 ==="

# ── 1. KV 네임스페이스 생성 (32-CLOUDFLARE §3) ────────────────────
echo ""
echo ">>> KV 네임스페이스 생성 중..."

echo "  [1/4] roundon-meta"
wrangler kv:namespace create "ROUNDON_META" || echo "  (이미 존재할 수 있음)"

echo "  [2/4] roundon-ratelimit"
wrangler kv:namespace create "ROUNDON_RATELIMIT" || echo "  (이미 존재할 수 있음)"

echo "  [3/4] roundon-pinlock"
wrangler kv:namespace create "ROUNDON_PINLOCK" || echo "  (이미 존재할 수 있음)"

echo "  [4/4] roundon-session"
wrangler kv:namespace create "ROUNDON_SESSION" || echo "  (이미 존재할 수 있음)"

echo ""
echo ">>> 위 출력에서 각 namespace의 'id' 값을 복사하여"
echo "    wrangler.toml의 <roundon-*> 플레이스홀더를 교체하세요."

# ── 2. R2 버킷 생성 (32-CLOUDFLARE §4) ──────────────────────────
echo ""
echo ">>> R2 버킷 생성 중..."
wrangler r2 bucket create roundon-photos || echo "  (이미 존재할 수 있음)"

# R2 Lifecycle Rule (7일 자동 삭제)
# 주의: wrangler CLI가 lifecycle put을 지원하지 않을 경우
#       Cloudflare 대시보드 → R2 → roundon-photos → Settings → Lifecycle rules에서
#       수동 설정하거나 Cloudflare API를 사용하세요. (32-CLOUDFLARE §4 참조)
echo ""
echo ">>> R2 Lifecycle Rule 설정 시도 중 (7일 자동 삭제)..."
wrangler r2 bucket lifecycle put roundon-photos --rules '{
  "rules": [{"id": "expire-7-days", "status": "Enabled", "expiration": {"days": 7}}]
}' 2>/dev/null || {
  echo "  [주의] lifecycle put CLI 미지원 — Cloudflare 대시보드에서 수동 설정 필요:"
  echo "    대시보드 → R2 → roundon-photos → Settings → Lifecycle Rules"
  echo "    Rule: expiration.days = 7"
}

# ── 3. 시크릿 등록 안내 (32-CLOUDFLARE §5) ────────────────────────
echo ""
echo "=== 시크릿 등록 (수동 필요) ==="
echo ""
echo "  아래 명령으로 시크릿을 등록하세요:"
echo ""
echo "  # bcrypt pepper (선택 — 추가 보안)"
echo "  wrangler secret put BCRYPT_PEPPER --env production"
echo "  # 입력값: openssl rand -base64 32"
echo ""
echo "  # HMAC-SHA256 세션 쿠키 서명 키 (필수)"
echo "  wrangler secret put SESSION_HMAC_KEY --env production"
echo "  # 입력값: openssl rand -base64 32"
echo ""

# ── 4. 셋업 완료 ───────────────────────────────────────────────
echo "=== 셋업 완료 ==="
echo ""
echo "다음 단계:"
echo "  1. wrangler.toml의 KV ID 플레이스홀더 교체"
echo "  2. wrangler secret put으로 시크릿 2종 등록"
echo "  3. Cloudflare 대시보드에서 R2 Lifecycle Rule 확인"
echo "  4. wrangler deploy --env production"
echo "  5. bash scripts/smoke-test.sh 실행"
