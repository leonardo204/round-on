# 라운드온 Cloudflare Worker

`golf.zerolive.co.kr` 도메인에서 동작하는 라운드온 viewer 백엔드입니다.

## 아키텍처

```
[iPhone 앱] → POST/PUT → golf.zerolive.co.kr
                              ↓
                   Cloudflare Worker (roundon-viewer)
                              ↓
                 KV (메타/세션)    R2 (사진)
```

## 사용자 액션 (배포 전 필수)

### 1. wrangler 설치 + 로그인

```bash
npm install -g wrangler
wrangler login
```

### 2. KV 네임스페이스 + R2 버킷 생성

```bash
bash scripts/setup.sh
```

### 3. wrangler.toml KV ID 교체

`setup.sh` 실행 출력에서 각 네임스페이스 `id` 값을 복사하여 `wrangler.toml`의 플레이스홀더를 교체하세요:

```toml
[[kv_namespaces]]
binding = "KV_META"
id = "<여기에 roundon-meta ID 입력>"

# ... 나머지 3개도 동일하게
```

### 4. 시크릿 등록

```bash
# HMAC-SHA256 세션 쿠키 서명 키 (필수)
wrangler secret put SESSION_HMAC_KEY --env production
# 입력값: openssl rand -base64 32

# bcrypt pepper (선택)
wrangler secret put BCRYPT_PEPPER --env production
# 입력값: openssl rand -base64 32
```

### 5. 배포

```bash
npm install
wrangler deploy --env production
```

---

## 로컬 개발

```bash
npm install

# .dev.vars 파일 생성 (로컬 시크릿)
cat > .dev.vars << 'EOF'
SESSION_HMAC_KEY=local-dev-hmac-key-change-before-production
BCRYPT_PEPPER=local-dev-pepper-change-before-production
EOF

wrangler dev
```

### 스모크 테스트

```bash
# 별도 터미널에서 wrangler dev 실행 후
bash scripts/smoke-test.sh
```

---

## 엔드포인트 목록

| 메서드 | 경로 | 설명 |
|--------|------|------|
| `GET` | `/healthz` | 헬스체크 |
| `POST` | `/api/share` | viewer 생성 |
| `PUT` | `/api/share/:shortId` | viewer 업데이트 |
| `DELETE` | `/api/share/:shortId` | viewer 삭제 |
| `POST` | `/api/share/:shortId/photos` | 사진 업로드 |
| `DELETE` | `/api/share/:shortId/photos/:photoId` | 사진 삭제 |
| `GET` | `/:shortId` | viewer HTML |
| `GET` | `/:shortId/photo/:photoId` | 사진 인라인/다운로드 |
| `GET` | `/:shortId/photos.zip` | 전체 사진 ZIP |
| `POST` | `/:shortId/verify-pin` | PIN 검증 |

---

## Cloudflare 대시보드 추가 설정

### SSL/TLS

- SSL/TLS 모드: **Full (strict)**
- Always Use HTTPS: **ON**
- HSTS: **활성화**
- 최소 TLS: **1.2**

### R2 CORS (roundon-photos 버킷)

```json
{
  "AllowedOrigins": ["https://golf.zerolive.co.kr"],
  "AllowedMethods": ["GET"],
  "AllowedHeaders": ["*"],
  "MaxAgeSeconds": 3600
}
```

### R2 Lifecycle Rule (7일 자동 삭제)

`setup.sh`에서 자동 시도하지만 CLI 미지원 시 대시보드에서 수동 설정:
- R2 → `roundon-photos` → Settings → Lifecycle Rules → expiration.days = 7

---

## 보안 주의사항

- `SESSION_HMAC_KEY`와 `BCRYPT_PEPPER`는 절대 소스코드/wrangler.toml에 기재 금지
- `.dev.vars`는 `.gitignore`에 포함됨 — 커밋 금지
- KV ID는 공개 정보이므로 wrangler.toml에 기재 가능
- editToken은 iOS Keychain에 저장, 서버 로그에 평문 기록 금지

---

## 참조 문서

- `ref-docs/specs/30-API_SPEC.md` — HTTP 엔드포인트 명세
- `ref-docs/specs/31-VIEWER_HTML.md` — viewer HTML 구조
- `ref-docs/specs/32-CLOUDFLARE_SETUP.md` — 인프라 셋업 상세
- `ref-docs/specs/33-SECURITY.md` — 보안 정책
