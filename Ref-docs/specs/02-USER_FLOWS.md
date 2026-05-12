# 02 — 주요 사용자 플로우 (User Flows)

> **작성일**: 2026-05-11
> **버전**: v4 기반
> **출처 명세서**: [기능 명세서 v4](../golf-scorecard-app-spec_3.md)

---

## 표기 규약

| 항목 | 규칙 |
|------|------|
| Actor | `iPhone` `Watch` `Worker` `방문자(브라우저)` |
| 출처 인용 | `(spec_3.md:N)` 라인 / `(spec_3.md §N)` 섹션 / `(CLAUDE.md §PROJECT)` |
| 분기/예외 | 골든패스와 분리하여 **분기/예외** 소제목 하에 불릿 나열 |
| 범위 외 | `→ 상세: XX-FILE.md (작성 예정)` 형태로 위임 명시 |
| 도메인 | `golf.zerolive.co.kr` (spec_3.md:6) |

---

## 플로우 목차

| ID | 플로우 이름 | 주 Actor | 트리거 | 종료 조건 |
|----|------------|---------|--------|----------|
| F-A | 앱 첫 실행 / 골프장 자동 매칭 | iPhone | 앱 실행 | 골프장 확정 (자동 or 수동) |
| F-B | 라운드 시작 | iPhone | "라운드 시작" 탭 | Watch로 라운드 데이터 송출 완료 |
| F-C | 점수 입력 | Watch (iPhone sync) | Watch 메인 화면 진입 | 18홀 완료 또는 "라운드 종료" 탭 |
| F-D | 라운드 종료 / 자동 재개 | iPhone | 명시 종료 or 강제 종료 후 재실행 | 요약 저장 + CloudKit sync 완료 |
| F-E | Viewer 공유 생성/업데이트 | iPhone → Worker | "공유하기" 탭 | shortId URL 공유 시트 표시 |
| F-F | Viewer 방문 (PIN 분기) | 방문자(브라우저) | 공유 링크 탭 | 스코어카드 + 갤러리 표시 |
| F-G | 사진 다운로드 (사진앱 직접 저장) | 방문자(브라우저) | 갤러리 사진 탭 | 디바이스 사진앱 저장 완료 |

(원문: spec_3.md:771 §10.3)

---

## F-A. 앱 첫 실행 / 골프장 자동 매칭 (iPhone)

**Actor**: iPhone | **트리거**: 앱 실행 | **종료**: 골프장 확정

1. 위치 권한 요청 (`CLLocationManager.requestWhenInUseAuthorization()`) (spec_3.md:657-659)
2. 1회 GPS fetch (`CLLocationManager.requestLocation()`) (spec_3.md:58)
3. 한국 골프장 DB 순회 → Haversine 거리 계산 (spec_3.md:627-632)
4. 반경 3km 이내 최근접 코스 디폴트 표시 "○○골프장 자동 선택됨 (변경)" (spec_3.md:59, 633-634)
5. 사용자 확인 또는 수동 변경 → F-B로 진행

**분기/예외**

- 위치 권한 거부 → 수동 검색/선택 fallback (spec_3.md:634)
- 3km 내 매칭 실패 → 수동 선택 (spec_3.md:635)
- `dataQuality: low` 매칭 (1,163곳 중 1,139곳) → F-B에서 수동 홀 진행 모드 적용 (CLAUDE.md §PROJECT)
- F3 GPS 자동 감지 — 골프장 + 서브코스 단위 (홀 단위 자동 감지는 미제공, 수동 진행) — 모든 코스에서 골프장 단위 감지 가능 (CLAUDE.md §PROJECT)

---

## F-B. 라운드 시작 (iPhone)

**Actor**: iPhone | **트리거**: "라운드 시작" 탭 | **종료**: Watch 라운드 데이터 송출 완료

1. F-A에서 확정된 골프장 표시
2. holesCount > 18이고 subCourses 존재 시: SubCourseSelector 표시 → 서브코스 라벨 (동/서/남/북 또는 전반/후반) 선택 → Round.courseSubName 저장
3. holesCount == nil이면 사용자 입력 프롬프트 표시 (9/18/27/36 선택), DB에 기록 안 함
4. 동반자 최대 3명, 별명 자동 채워넣기("동반자1/2/3"), 최근 동반자 1탭 선택 가능 (spec_3.md:63-67)
5. "라운드 시작" 탭
6. HealthKit 권한 미허가 시 요청 → 허가 시 `HKWorkoutActivityType.golf` 워크아웃 세션 시작 (spec_3.md:116-119, 660)
7. WatchConnectivity로 Watch에 라운드 데이터 송출 (골프장, 홀, 동반자) (spec_3.md:684-685)
8. iPhone 4×18 그리드 및 Watch 메인 화면 동시 활성화

**분기/예외**

- HealthKit 권한 거부 → 워크아웃 없이 점수 기록만 진행 (spec_3.md:116-119)
- Watch 미연결 → iPhone 단독 모드 진행, 연결 시 자동 sync 재시도

---

## F-C. 점수 입력 (Watch 메인, iPhone sync)

> 라운드온의 핵심 플로우. 라운드 전체에 걸쳐 반복 실행됨.

**Actor**: Watch (메인), iPhone (sync) | **트리거**: Watch 메인 화면 진입 | **종료**: 18홀 완료 or 라운드 종료 탭

```
Watch              WatchConnectivity        iPhone
  | Crown +1 / 탭   |                        |
  |── sendMessage ─>| (즉시 deliver)         |
  |                 |── 4×18 그리드 갱신 ───>|
  |<── ack ─────────|                        |
  | (연결 끊김 시)   |                        |
  |── transferUser  | (큐, 복귀 시 전송)     |
  |    Info ───────>|                        |
```

(spec_3.md:104-105, 684-685)

1. Watch 메인: 홀 번호, par, 카운터(0에서 시작) 표시 (spec_3.md:75-77, 587-606)
2. 샷마다 Digital Crown 시계방향 또는 화면 큰 탭 → +1 / 반시계방향 → -1 수정 (spec_3.md:94-96)
3. 벌타: OB 버튼 +2 / 해저드 +1 / OK +1 (spec_3.md:83-85)
4. par 대비 실시간 갱신 (예: "5 (+1)") (spec_3.md:86)
5. 수동 홀 진행 모드: 좌/우 스와이프 또는 탭으로 다음 홀 이동 (spec_3.md:97). 홀 단위 자동 진행은 미제공.
6. 상/하 스와이프 → 본인 ↔ 동반자 전환 (spec_3.md:98)
7. iPhone 4×18 그리드와 즉시 sync (spec_3.md:104-105)

**분기/예외**

- 카운터 상한/하한: 최대 15타, 최소 1타 — 초과 입력 차단 (spec_3.md:649-651)
- 모든 코스: 수동 홀 진행 모드 — 사용자가 스와이프/탭으로 다음 홀 이동. 홀 단위 자동 진행은 미제공 (CLAUDE.md §PROJECT)
- haptic 패턴 상세 → `13-HAPTICS_AND_MOTION.md` (작성 예정) (spec_3.md §7.3)
- iPhone 단독 모드: 셀 탭 +1 / 길게 누르기 -1 (spec_3.md:103-105)
- **WatchConnectivity 끊김 → 복구**: 끊긴 동안 Watch는 로컬 카운터를 큐(`transferUserInfo`)에 누적 → 재연결 시 자동 전송. iPhone 측 같은 홀에 동시 편집이 있었다면 **최신 타임스탬프 우선** 정책 적용(F-D 분기와 동일)

---

## F-D. 라운드 종료 / 자동 재개 (iPhone)

**Actor**: iPhone | **트리거**: "라운드 종료" 탭 or 강제 종료 후 재실행 | **종료**: CloudKit sync 완료

**명시적 종료**

1. "라운드 종료" 탭 (spec_3.md:109)
2. 요약 화면: 총 스코어, 홀별, par 대비 (spec_3.md:572)
3. HealthKit 워크아웃 세션 종료 (걸음 수, 칼로리, 심박수, 시간) (spec_3.md:117-119)
4. SwiftData 저장 (로컬 우선) → CloudKit 자동 sync (spec_3.md:111-114, 916-926)
5. 요약 화면에서 사진 첨부 및 viewer 공유 옵션 → F-E로

**자동 재개**

1. 강제 종료 후 재실행 → SwiftData에서 미완료 라운드 감지
2. "이전 라운드 재개" 다이얼로그 자동 표시 (spec_3.md:107-108)
3. "재개" → F-C 복귀 / "종료" → 현재 데이터로 요약 저장

**분기/예외**

- iCloud 미로그인 또는 네트워크 없음 → 로컬만 저장, 복구 시 자동 sync (spec_3.md:114)
- Watch sync 충돌 → 최신 타임스탬프 우선 적용
- **HealthKit 워크아웃 세션 종료 실패** (백그라운드 종료/HK 오류): 워크아웃 메트릭(걸음/칼로리/심박) 부재로 표시 → 요약 화면은 스코어 데이터만으로 정상 노출, "워크아웃 데이터 누락" 안내 배너 표기 (spec_3.md:116-119)

---

## F-E. Viewer 공유 생성/업데이트 (iPhone → Cloudflare)

**Actor**: iPhone, Cloudflare Worker | **트리거**: "공유하기" 탭 | **종료**: shortId URL 공유 시트 표시

```
iPhone               Cloudflare Worker          KV/R2
  |                        |                       |
  | 사진/스코어 직렬화       |                       |
  |──── POST /api/share ──>|                       |
  |   (PIN → bcrypt 해시)  |── KV write meta ─────>|
  |                        |── R2 upload photos ──>|
  |<── shortId + editToken ─|                       |
  | iOS 공유 시트 호출       |                       |
```

1. 공유 옵션 선택: 이름 공개(실명/익명), 접근 권한(공개/PIN 4자리), 사진 첨부 여부 (spec_3.md:573-581)
2. PIN 입력 시 bcrypt 해시 처리 후 전송 (spec_3.md:278)
3. `POST /api/share` 요청 (spec_3.md:262-263)
4. Worker: shortId 생성(base62 8자) → KV(메타, TTL 7일) + R2(사진, TTL 7일) 저장 (spec_3.md:276, 250-251)
5. shortId + editToken + expiresAt 반환 (spec_3.md:264)
6. iOS 공유 시트 → 카카오톡/메시지로 `https://golf.zerolive.co.kr/{shortId}` 전송 (spec_3.md:125-128)

**업데이트 분기**: 기존 viewer 수정 → `PUT /api/share/{shortId}` + editToken 헤더, 기존 URL 그대로 갱신 (spec_3.md:139-142, 264-270)

**분기/예외**

- Rate limit: 디바이스당 1분 5개 제한 (spec_3.md:280)
- 동반자 실명·연락처 업로드 차단 (spec_3.md:282, CLAUDE.md §PROJECT)
- R2 사진 업로드 실패 → 재시도, 스코어 메타는 KV 우선 저장
- 사진 제한: 1장 최대 10MB, 1 viewer 최대 30장 (spec_3.md:279)
- **오프라인 공유 시도** (음영 지역에서 라운드 종료 직후): 로컬 큐에 페이로드 보관 → 네트워크 복귀 시 자동 재전송. CloudKit 큐와는 분리(viewer는 임시·외부 공유, CloudKit은 라운드 데이터 sync) (spec_3.md:114, 121-128 참조)
- API 상세 → `30-API_SPEC.md` (본 시리즈 #5)

---

## F-F. Viewer 방문 (PIN 분기) — 방문자 (iOS/Android/카톡 인앱)

**Actor**: 방문자(브라우저), Worker | **트리거**: 공유 링크 탭 | **종료**: 스코어카드 + 갤러리 표시

**공개 viewer (PIN 없음)** — 단순 2단계:

1. `GET /{shortId}` → Worker가 KV 메타 조회 후 즉시 HTML 응답
2. 모바일 우선 스코어카드 + 갤러리 표시 (가로 스크롤 or 9홀 2단) (spec_3.md:147-151, 205-213)

**PIN 보호 viewer** — 검증 분기 시퀀스:

```
방문자 (브라우저)        Cloudflare Worker       KV/R2
  |                        |                      |
  |──── GET /{shortId} ───>|                      |
  |                        |── KV read meta ─────>|
  |                        |<── 메타(PIN flag) ───|
  |<── PIN 입력 화면 HTML ─|                      |
  |                        |                      |
  | 4자리 PIN 입력         |                      |
  |── POST /{shortId} ────>| bcrypt.compare()     |
  |     {pin}              |                      |
  |<── 스코어카드 + 갤러리 |                      |
```

1. 링크 탭 → 브라우저(또는 카톡 인앱) 실행 (spec_3.md:148)
2. `GET /{shortId}` → KV 메타에 `pin: true` 발견 → PIN 입력 화면 응답 (spec_3.md:238-241)
3. 4자리 입력 → bcrypt 검증 통과 시 HTML 응답 (spec_3.md:278)

**분기/예외**

- PIN 5회 오답 → 1시간 잠금 (spec_3.md:278)
- 7일 만료 또는 없는 shortId → 404 + 만료 안내 (CLAUDE.md §PROJECT)
- 카톡 인앱 브라우저 long-press quirk → `31-VIEWER_HTML.md` (본 시리즈 #6)

---

## F-G. 사진 다운로드 (사진앱 직접 저장) — 방문자

**Actor**: 방문자(브라우저) | **트리거**: 갤러리 사진 탭 | **종료**: 디바이스 사진앱 저장 완료

1. 갤러리 썸네일 탭 → 라이트박스 풀스크린 (spec_3.md:196-201)
2. `<img src="...">` 태그 직접 표시 (CSS background-image 방식 사용 안 함) (spec_3.md:159)
3. **long-press** → 시스템 컨텍스트 메뉴:
   - iOS Safari: "사진에 저장" → iOS 사진앱 저장 (spec_3.md:157-160)
   - Android Chrome: "이미지 다운로드" → 갤러리 자동 저장 (spec_3.md:163-165)
4. 명시적 다운로드 버튼 탭 → `?download=1` → Worker `Content-Disposition: attachment` 헤더 응답 (spec_3.md:167-170, 188-194)
5. "사진 전체 다운로드(ZIP)" 버튼 → `GET /{shortId}/photos.zip` 스트리밍 (spec_3.md:171, 271)

**분기/예외**

- 카톡 인앱 브라우저: long-press 미지원 가능 → "외부 브라우저로 열기" 안내 (spec_3.md:200-203)
- ZIP 대용량(최대 30장×10MB) → progress 표시
- 구현 상세 → `31-VIEWER_HTML.md` (본 시리즈 #6) (spec_3.md:159, 173-186)

---

## 부록: 플로우 전이도

```
[앱 실행]
    |
   F-A  골프장 자동 매칭
    |
   F-B  라운드 시작
    |
   F-C  점수 입력 (18홀 반복)  <────────────┐
    |                                        |
   F-D  라운드 종료/재개                      |
    |         |                              |
(명시 종료)  (강제종료 후 재실행)              |
    |         |                              |
    |   "재개" 다이얼로그 ─────────────────────┘
    |
   F-E  Viewer 공유 (iPhone → Worker)
    |
  [링크 → 방문자]
    |
   F-F  Viewer 방문 (방문자 브라우저)
    |
   F-G  사진 다운로드 (사진앱 저장)
```

F-D 재개 점선: 강제 종료 후 재실행 시 "재개" 선택 → F-C 복귀 (spec_3.md:107-108)

---

## 본 문서 범위 외 항목

| 항목 | 위임 문서 |
|------|----------|
| 화면 UI 레이아웃, 컴포넌트 배치 | `12-SCREENS.md` (작성 예정) |
| Haptic 패턴 전체 매핑 + 트랜지션 | `13-HAPTICS_AND_MOTION.md` (작성 예정) |
| Worker API 엔드포인트 전체 명세 | `30-API_SPEC.md` (본 시리즈 #5) |
| Viewer HTML 구조, long-press 상세 | `31-VIEWER_HTML.md` (본 시리즈 #6) |
| shortId/editToken/PIN/rate limit 보안 상세 | `33-SECURITY.md` (작성 예정) |
| 권한 요청 메시지 전문 | `53-PERMISSIONS.md` (작성 예정) |

*최종 업데이트: 2026-05-11*
