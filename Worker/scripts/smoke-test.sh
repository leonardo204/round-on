#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────
# 라운드온 Worker 스모크 테스트
# 로컬(wrangler dev) 또는 배포된 환경을 대상으로 기본 동작 검증
#
# 실행:
#   BASE_URL=http://localhost:8787 bash scripts/smoke-test.sh
#   BASE_URL=https://golf.zerolive.co.kr bash scripts/smoke-test.sh
# ──────────────────────────────────────────────────────────────────
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8787}"
PASS=0
FAIL=0

# 색상 코드
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

assert_status() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo -e "${GREEN}  PASS${NC} $label (HTTP $actual)"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}  FAIL${NC} $label (expected $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== 라운드온 스모크 테스트 ==="
echo "  대상: $BASE_URL"
echo ""

# ── 1. /healthz ─────────────────────────────────────────────────
echo ">>> 1. GET /healthz"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/healthz")
assert_status "healthz" "200" "$STATUS"

# ── 2. /robots.txt ──────────────────────────────────────────────
echo ">>> 2. GET /robots.txt"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/robots.txt")
assert_status "robots.txt" "200" "$STATUS"

# ── 3. POST /api/share (공개 viewer 생성) ───────────────────────
echo ">>> 3. POST /api/share (공개)"
SHARE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/share" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceToken": "test-device-uuid-001",
    "round": {
      "id": "round-001",
      "courseName": "테스트 컨트리클럽",
      "date": "2026-05-12",
      "players": [{"id": "p1", "name": "홍길동", "totalScore": 78}],
      "holes": [
        {"number": 1, "par": 4, "scores": [{"playerId": "p1", "shots": 4}]},
        {"number": 2, "par": 3, "scores": [{"playerId": "p1", "shots": 3}]}
      ]
    },
    "options": {"nameVisibility": "real", "accessControl": "public"}
  }')

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/share" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceToken": "test-device-uuid-002",
    "round": {"id": "r2", "courseName": "스모크 CC", "date": "2026-05-12", "players": [], "holes": []},
    "options": {"nameVisibility": "real", "accessControl": "public"}
  }')
assert_status "POST /api/share" "201" "$STATUS"

SHORT_ID=$(echo "$SHARE_RESPONSE" | grep -o '"shortId":"[^"]*"' | cut -d'"' -f4)
EDIT_TOKEN=$(echo "$SHARE_RESPONSE" | grep -o '"editToken":"[^"]*"' | cut -d'"' -f4)

if [ -n "$SHORT_ID" ]; then
  echo "  생성된 shortId: $SHORT_ID"

  # ── 4. GET /:shortId (viewer HTML) ──────────────────────────
  echo ">>> 4. GET /$SHORT_ID (viewer)"
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/$SHORT_ID")
  assert_status "GET viewer" "200" "$STATUS"

  # ── 5. GET /미존재shortId (404) ─────────────────────────────
  echo ">>> 5. GET /NOTEXIST (404)"
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/NOTEXIST")
  assert_status "404 not found" "404" "$STATUS"

  # ── 6. GET /:shortId/photos.zip (사진 없음 → 404) ──────────
  echo ">>> 6. GET /$SHORT_ID/photos.zip (사진 없음)"
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/$SHORT_ID/photos.zip")
  assert_status "photos.zip 404" "404" "$STATUS"

  # ── 7. DELETE /api/share/:shortId (삭제) ───────────────────
  if [ -n "$EDIT_TOKEN" ]; then
    echo ">>> 7. DELETE /api/share/$SHORT_ID"
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
      -X DELETE "$BASE_URL/api/share/$SHORT_ID" \
      -H "Authorization: Bearer $EDIT_TOKEN")
    assert_status "DELETE share" "204" "$STATUS"
  fi
fi

# ── 결과 요약 ──────────────────────────────────────────────────
echo ""
echo "=== 결과 ==="
echo -e "  ${GREEN}PASS: $PASS${NC}  ${RED}FAIL: $FAIL${NC}"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
