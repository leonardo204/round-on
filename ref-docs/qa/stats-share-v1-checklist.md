# 통계 공유 v1 — 수동 QA 체크리스트

> 작성일: 2026-05-27
> 대상 버전: 통계 공유 v1 (Phase 1~3 구현 완료 기준)
> 관련 spec: 01-SPEC.md §F9-A, 30-API_SPEC.md §TC-1~TC-7, 31-VIEWER_HTML.md §10, 33-SECURITY.md §7.7

---

## 진입점

- [ ] 통계 화면 상단 우측 `⬆︎ 공유` 버튼 항상 노출 (라운드 0건 포함)
- [ ] 라운드 0건 시 공유 버튼 비활성 (회색, 탭 무반응)
- [ ] PR 갱신 직후 통계 진입 시 PR 배너 등장
- [ ] HCP 1.0 이상 하락 시 HCP 배너 등장
- [ ] `recentTrend.improving` 조건 충족 시 TREND 배너 등장
- [ ] 30일 내 동일 trigger 재진입 시 배너 미등장
- [ ] 배너 탭 → 공유 시트 진입, cardKind가 배너 trigger와 정확히 매칭 (PR 배너 → `pr` 카드)

---

## 공유 시트

- [ ] 카드 3종 picker (PR / HCP / TREND) 작동
- [ ] picker 전환 시 카드 미리보기 즉시 변경
- [ ] 닉네임 입력 필드 표시
- [ ] 닉네임에 "010-1234-5678" 입력 시 마스킹 적용 (`***-****-****`)
- [ ] 닉네임에 이메일 입력 시 마스킹 적용
- [ ] PIN 토글 OFF 상태 기본 → ON 전환 시 4자리 입력 필드 표시
- [ ] PIN 4자리 미만 입력 시 "공유 링크 생성" 버튼 비활성
- [ ] PIN 4자리 입력 시 버튼 활성화
- [ ] "공유 링크 생성" CTA 탭 → 로딩 인디케이터 → viewer URL 반환
- [ ] 반환된 URL 형식: `https://golf.zerolive.co.kr/s/s_xxxxxxxx` (10자 shortId)
- [ ] iOS 공유 시트 열림: 카톡 / 메시지 / 메일 / 이미지 저장 / URL 복사 옵션 존재
- [ ] 공유 시트 "이미지 저장" → 카드 PNG가 카메라 롤에 저장됨
- [ ] 공유 시트 카드 + URL 첨부 확인 (텍스트: viewer URL)

---

## Worker viewer

- [ ] `https://golf.zerolive.co.kr/s/s_xxxxxxxx` — HTTP 200 정상 응답
- [ ] `Content-Type: text/html; charset=utf-8` 확인
- [ ] `og:title`: `{headline} | 라운드온`
- [ ] `og:description`: `{displayName}님의 골프 통계 · {periodLabel}`
- [ ] 만료 전 viewer — 11개 섹션 모두 렌더 확인:
  - [ ] 섹션 1: 헤더 — "라운드온" 브랜드 + D-day 뱃지
  - [ ] 섹션 2: 작성자 — 아바타 + 닉네임 + 기간 라벨
  - [ ] 섹션 3: 시그니처 hero — headline, bigNumber, deltaText
  - [ ] 섹션 4: 요약 3카드 — 총 라운드 / 최근 평균 / vs Par
  - [ ] 섹션 5: 스코어 분포 도넛 + 범례
  - [ ] 섹션 6: Par별 평균 바 + 최근 흐름 sparkline
  - [ ] 섹션 7: 베스트 라운드 (bestRound 있는 경우)
  - [ ] 섹션 8: 지역 지도 (regions 있는 경우) — 시도 centroid 핀만 표시
  - [ ] 섹션 9: 최근 5라운드 목록
  - [ ] 섹션 10: "나도 골프 기록 시작하기" CTA 버튼
  - [ ] 섹션 11: 푸터 — 만료일 + OSM ODbL + 라운드온
- [ ] D-day 뱃지 계산 정확 (생성일 + 7일 기준)
- [ ] "나도 골프 기록 시작하기" CTA 탭 → App Store 링크 이동
- [ ] 지도에 클럽하우스 좌표 핀 없음 (시도 centroid만)
- [ ] 7일 후 접근 → `410 HTML` 응답 ("통계 공유가 만료되었습니다")
- [ ] 없는 shortId 접근 → `404 HTML` 응답

---

## og:image (v2 — 2026-07-17)

> v1 의 `cardKind` 별 정적 자산(`/og-stats-pr.png` 등) 방식은 폐기됨.
> 번들 gzip 한도(3MB) 여유가 부족해 PNG 를 번들에 넣지 않는다.
> iOS 가 공유 생성 시 업로드한 1080×1080 시그니처 카드 PNG 를 KV 에 저장하고 shortId 별로 서빙한다.

- [ ] PIN 없는 공유 → viewer HTML 에 `og:image` = `https://golf.zerolive.co.kr/og/{shortId}.png` (shortId 별, cardKind 무관)
- [ ] `og:image:width` = `1080`, `og:image:height` = `1080`, `og:image:type` = `image/png`
- [ ] `og:image` 있을 때 `twitter:card` = `summary_large_image` (없으면 `summary`)
- [ ] `GET /og/{shortId}.png` → HTTP 200 + `Content-Type: image/png`
- [ ] 응답 헤더 `Cache-Control: public, max-age=604800, immutable`
- [ ] 반환된 이미지가 공유 시트에서 본 시그니처 카드와 동일 (1080×1080)
- [ ] **PIN 설정된 공유 → `GET /og/{shortId}.png` 404** (미리보기로 스코어 유출 차단)
- [ ] **PIN 설정된 공유 → viewer HTML 에 `og:image` 메타 자체가 없음**
- [ ] PIN 설정된 공유 링크를 카톡에 붙여넣기 → 미리보기에 카드 이미지 **미표시** (제목/설명만)
- [ ] 공유 생성 후 PIN 을 나중에 추가(PUT) → `/og/{shortId}.png` 404 로 전환
- [ ] 구버전 앱(ogImage 미전송) 으로 생성한 공유 → `/og` 404 + viewer 에 og:image 메타 없음, viewer 본문은 정상 렌더
- [ ] 이미지 업로드 실패(1.5MB 초과 / PNG 아님) 상황에서도 공유 생성은 성공 (og 만 생략)
- [ ] 공유 삭제(DELETE) 후 `/og/{shortId}.png` 404
- [ ] 만료(7일 경과) 후 `/og/{shortId}.png` 404
- [ ] `/og/{잘못된 형식}.png` (s_ prefix 없음 / 길이 불일치) → 404

---

## PIN 잠금

- [ ] PIN 설정된 viewer URL 접근 시 잠금 화면 렌더
- [ ] 잠금 화면: "PIN이 필요합니다" 제목 + 4자리 입력 폼 표시
- [ ] 올바른 PIN 입력 → viewer 본문 정상 표시
- [ ] 틀린 PIN 입력 → "PIN이 올바르지 않습니다. (N/5)" 표시
- [ ] 5회 오답 → "PIN 5회 오답으로 잠겼습니다. 1시간 후 재시도하세요." 표시
- [ ] PIN 성공 후 `location.reload()` → 쿠키(`stats_pin_ok_{shortId}`) 저장 → viewer 본문
- [ ] 쿠키 유효 상태에서 재방문 시 잠금 화면 없이 바로 viewer 본문
- [ ] 쿠키 삭제 후 재방문 → 잠금 화면 재등장

---

## 카톡 인앱 호환

- [ ] 카톡 단톡방 링크 공유 후 미리보기 카드 이미지 노출 (og:image 표시 — **PIN 없는 공유 한정**)
- [ ] PIN 설정 공유는 카톡 미리보기에 이미지 없이 제목/설명만 노출 (스코어 유출 차단)
- [ ] 카톡 미리보기 카드 제목(`og:title`) 노출
- [ ] 카톡 인앱 브라우저로 viewer 열림
- [ ] 인앱 브라우저 스크롤 깨짐 없음
- [ ] 인앱 브라우저 렌더 깨짐 없음 (외부 폰트 없으므로 빠른 로드)
- [ ] safe-area-inset 적용 — 아이폰 노치/Dynamic Island 영역 침범 없음

---

## PII 가드

- [ ] viewer HTML 소스에서 `courseId` 키워드 부재
- [ ] viewer HTML 소스에서 `deviceId` / `deviceToken` 키워드 부재
- [ ] viewer HTML 소스에서 `roundId` 키워드 부재
- [ ] viewer HTML 소스에서 클럽하우스 GPS 좌표 (소수점 6자리 이상 lat/lng 수치) 부재
- [ ] 닉네임 "010-1234-5678" 입력 → viewer에서 `***-****-****` 표시
- [ ] 닉네임 이메일 입력 → viewer에서 `***@***.***` 표시
- [ ] 동반자 이름 페이로드에 미포함 확인 (Worker 테스트 로그)

---

## Worker API 동작

- [ ] `POST /api/share/stats` → 201 응답 + shortId(`s_` prefix) + editToken + expiresAt
- [ ] `PUT /api/share/stats/:shortId` + 유효 editToken → 200 응답
- [ ] `PUT /api/share/stats/:shortId` + 잘못된 editToken → 401 응답
- [ ] `DELETE /api/share/stats/:shortId` + 유효 editToken → 204 응답
- [ ] 삭제 후 viewer 접근 → 404 응답
- [ ] deviceToken 기준 1분 5건 초과 → 429 응답 + `Retry-After: 60`
- [ ] 페이로드 1MB 초과 → 413 응답

---

## 회귀 (기존 기능 영향 없음 확인)

- [ ] 라운드 viewer (`https://golf.zerolive.co.kr/{shortId}`) 정상 응답
- [ ] 라운드 공유 시트 (기존 iOS `ShareSheetView`) 정상 작동
- [ ] 라운드 `POST /api/share` → 201 정상
- [ ] 라운드 `PUT /api/share/:shortId` → 200 정상
- [ ] 라운드 `POST /:shortId/verify-pin` → 기존 세션 쿠키(`viewer_session`) 발급 정상
- [ ] 통계 화면 기존 카드들 정상:
  - [ ] Hero 카드 (PR 수치)
  - [ ] 요약 카드 (총 라운드 / 평균 / vs Par)
  - [ ] 스코어 분포 차트
  - [ ] Par별 평균 차트
  - [ ] 지역별 라운드
  - [ ] 베스트 라운드
  - [ ] 최근 라운드 목록
- [ ] Watch 연동 (라운드 진행 중 Watch 화면) 영향 없음
- [ ] iCloud Sync 정상 (SwiftData 모델 변경 없음)

---

## 테스트 환경

| 항목 | 권장 |
|------|------|
| iOS 기기 | iPhone 16 Pro, iOS 18+ |
| 카톡 버전 | 최신 버전 (인앱 브라우저 테스트) |
| Worker 환경 | production (`roundon-viewer-production`) |
| KV_STATS | wrangler.toml 바인딩 확인 |

---

*작성: 2026-05-27 — 통계 공유 v1 Phase 4 문서 갱신 시 작성*
