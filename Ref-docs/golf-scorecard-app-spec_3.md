# 🏌️ 라운드온 (Round-On) — 기능 명세서 (v4)

> **앱 이름**: **라운드온 (Round-On)** — 2026-05-11 확정
> **목적**: iPhone + Apple Watch 기반의 간단한 골프 스코어 카운터 앱 개발  
> **타겟 플랫폼**: iOS 17+ / watchOS 10+  
> **Viewer 도메인**: `golf.zerolive.co.kr`
> **개발 방식**: 단일 Phase, 한 번에 전체 개발 (Claude Code)  
> **작성일**: 2026-05-11  
> **버전**: v4 (모바일 viewer 강화 + 작업 분담 + 사전 문서 리스트)
>
> **네이밍 의미**: "라운드 + ON" — 라운드가 켜져있다(진행 중) / "온 그린(on green)" 골프 용어 / 라운드를 시작/접속한다는 한국적 직관. 한국 골프 앱 카테고리에서 동명 앱 미확인(2026-05-11 1차 검증). 단, 영어 숙어 "round on"은 부정 의미("공격하다")가 있어 영어권 출시 시 별도 브랜드 재고 권장.

---

## 0. 핵심 컨셉

> **"한 번 탭할 때마다 한 타. 라운드 끝나면 사진과 함께 친구들에게 공유."**

거리 측정, 게임 모드, 핸디캡 계산, 정산 등 부가 기능을 모두 배제하고,
**자동화된 점수 기록(샷 카운트 방식) + 사진 앨범까지 포함한 모바일 viewer 링크 공유** 두 가지에만 집중.

---

## 1. 시장 조사 요약

App Store 주요 골프 스코어 카운터 앱들을 조사한 결과는 다음과 같습니다.

### 1.1 글로벌 주요 앱

| 앱 이름 | 강점 | 비고 |
|---------|------|------|
| **18Birdies** | 43,000+ 코스, 무료 티어 강력 | 광고 많음 |
| **Golfshot** | AR 코스뷰, Apple Watch 자동 샷 추적 | 한국 코스 약함 |
| **Hole19** | 무료 디지털 스코어카드, Apple Watch 독립 실행 | 한국어 OK |
| **SwingU** | 7M+ 사용자, **그린 도착 자동 감지 → 스코어 화면 전환** | 완전 무료 |
| **TheGrint** | Apple Watch 배터리 효율 우수 | 무료 핸디캡 |
| **Golf GameBook** | 라이브 리더보드, 동반자 입력 강력 | 유료 위주 |
| **GolfWatch** | **Apple Watch 완전 독립 실행 (폰 없이)** | 구독 필수 |
| **Golf Score Counter** | **동반자 점수 입력 (최대 3명)**, Digital Crown 카운트업 | 점수 기록 위주 |

### 1.2 한국 시장

- **스마트스코어** — 한국 사실상의 표준. 360만+ 골퍼. 무거운 슈퍼앱
- **야디지북** — 한국 코스 매핑, Apple Watch 지원

### 1.3 핵심 인사이트

1. **자동 코스 매칭은 모든 메이저 앱의 기본 기능**
2. Apple Watch 점수 입력의 표준 UX = **Digital Crown 회전 + 스와이프 + Haptic**
3. **그린 도착 자동 감지** 같은 마이크로 자동화가 사용자 만족도에 큰 영향 (SwingU)
4. **공유 기능 약점** — 대부분 앱이 자기 앱 안에서만 공유 가능 → **링크 공유 + 사진 앨범**은 명확한 차별 기회

---

## 2. 기능 목록 (최종)

### F1. 앱 실행 시 자동 골프장 매칭
- 앱 실행 시 **1회 GPS fetch** (`CLLocationManager.requestLocation()`)
- 사전 내장된 한국 골프장 DB와 거리 매칭 (반경 3km 이내, 가장 가까운 곳)
- 매칭된 골프장을 디폴트로 표시, 사용자가 수동 변경 가능
- **언제 실행해도 OK**: 클럽하우스 도착, 첫 홀 전, 라운드 중간(까먹고 늦게 켜도) 모두 OK

### F2. 동반자 입력 (별명 자동, 추후 수정)
- 본인 + 동반자 최대 3명
- **별명 자동 채워넣기**: "동반자1", "동반자2", "동반자3"
- 라운드 중에도 자유롭게 이름 수정 가능
- **최근 동반자 목록**에서 1탭 선택 (이전 라운드에서 같이 친 사람)

### F3. GPS 기반 골프장 + 서브코스 자동 감지

> **F3 GPS 자동 감지 — 골프장 + 서브코스 단위 (홀 단위 자동 감지는 미제공, 수동 진행)**

- **골프장 단위 감지**: 앱 실행 시 클럽하우스 좌표로 1,163곳 모두에서 즉시 동작 (한국 골프장 DB v3 기준)
- **서브코스 감지**: 27/36홀 골프장 387곳은 `SubCourse` 모델로 동/서/남/북 등 서브코스 라벨 지원 — 현재 v3 데이터에는 서브코스 좌표 미포함, 후속 데이터 보강 후 자동 감지 활성화 예정
- **홀 단위 진행**: 항상 **수동 홀 진행 모드** — 사용자가 스와이프/탭으로 다음 홀 이동 (홀 단위 자동 감지는 미제공, F3는 골프장+서브코스 단위만 지원)
- **서브코스 라벨 (동/서/남/북 또는 전반/후반)**: holesCount > 18인 경우 라운드 시작 시 사용자가 수동 선택
- **holesCount nil 처리**: 638곳은 holesCount 미기재 → 라운드 생성 시 9/18/27/36 선택 프롬프트 표시 (DB에는 기록 안 함)

### F4. 타수 카운터 방식 입력

**핵심 컨셉**: 파에서 시작하는 게 아니라 **0에서 시작해서 샷마다 +1**.

- **샷 한 번 = +1 카운트**
  - 티샷 → +1, 세컨샷 → +1, 어프로치 → +1, 칩 → +1, 퍼팅 → +1 ...
  - 최종 카운트 = 그 홀의 타수
- **벌타 추가**:
  - **OB 버튼**: 탭하면 +2 (1벌타 + 다시 치는 1타)
  - **해저드 버튼**: 탭하면 +1 (벌타만)
  - **OK/컨시드 버튼**: 탭하면 +1 (그린에서 OK 받았을 때)
- **현재 카운트가 par 대비 몇 타인지 실시간 표시** (예: "5 (+1)")
- **±1 수동 조정** 가능 (잘못 카운트했을 때)

> **장점**: 일반 골퍼는 "내가 몇 타째인지" 종종 까먹는데, 매 샷마다 누르는 행위 자체가 카운트 + 박자 → 매우 직관적

### F5. Watch + iPhone 입력 UX

**Apple Watch (메인 입력 방법)**:
- **Digital Crown 시계방향** → +1
- **Digital Crown 반시계방향** → −1 (실수 수정)
- **화면 큰 탭(전체 영역)** → +1 (장갑 끼고도 OK)
- **좌/우 스와이프** → 홀 이동
- **상/하 스와이프** → 본인 ↔ 동반자 전환
- **OB / 해저드 / OK 버튼** → 화면 하단 작은 버튼 또는 Force Press 메뉴
- Haptic: 카운트 시 가벼운 진동, 홀 전환 시 더블 진동

**iPhone**:
- 18홀 × 4인 그리드 (전통적 스코어카드)
- 셀 탭으로 +1, 길게 누르기로 −1
- 라운드 중에도 사용 가능 (Watch와 자동 sync)

### F6. 라운드 재개 (자동)
- 앱 강제 종료/배터리 방전 시 다시 실행하면 진행 중이던 라운드 자동 복구
- 라운드 종료 = 사용자가 명시적으로 "라운드 종료" 탭

### F7. iCloud Sync
- CloudKit으로 라운드 기록 자동 동기화
- 여러 디바이스에서 동일 데이터 확인
- 로컬 우선, 네트워크 복구 시 자동 sync

### F8. Apple Health 연동
- 라운드를 워크아웃으로 기록 (`HKWorkoutActivityType.golf`)
- 걸음 수, 칼로리, 심박수, 라운드 시간 자동
- Apple Watch에서 자동 시작/종료

### F9. 모바일 최적화 Viewer URL + 사진 앨범 + 사진앱 저장 ⭐ (v4 강화)

**기본 동작**:
- 라운드 종료 후 "공유하기" → 임시 HTML viewer 생성
- 서버 업로드 → `https://golf.zerolive.co.kr/{shortId}` 반환
- **7일 후 자동 만료**
- iOS 시스템 공유 시트로 카카오톡/iMessage/인스타 등 어디든 공유
- **안드로이드 친구도 링크 클릭만 하면 OK**

**Viewer 옵션 (생성 시 선택)**:
- **이름 공개**: 실명 / 익명(A/B/C/D)
- **접근 권한**: 공개 링크 / PIN 보호 (4자리 숫자)

**사진 앨범**:
- 라운드 중 또는 종료 후 사진 첨부 (카메라 롤 / 즉석 촬영)
- viewer에 갤러리 형태로 표시
- **방문자가 사진 다운로드 가능** (오리지널 화질)

**공유 후 업데이트**:
- 같은 shortId 유지하면서 내용 갱신 가능
- 친구들이 보던 링크 그대로 새 사진 보임
- editToken 기반 인증 (본인 디바이스만 수정)

### F10. Viewer 모바일 최적화 + 사진앱 저장 ⭐ (v4 신규)

#### 10.1 모바일 우선 설계
- **모든 디바이스에서 동일 경험**: 모바일/태블릿/데스크탑 반응형
- **모바일에서 가장 잘 보이도록 우선 설계** (한국 골퍼는 카톡에서 링크 → 모바일 브라우저로 진입)
- 뷰포트: `<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">`
- 터치 타깃 최소 44×44pt (iOS HIG) / 48×48dp (Material)
- safe-area-inset 적용 (아이폰 노치, 안드로이드 제스처 영역)
- 가로/세로 모드 모두 지원

#### 10.2 사진 — 디바이스 사진앱에 저장 ⭐ 핵심
viewer의 모든 사진은 **방문자가 자기 사진앱에 저장 가능**해야 함.

**iOS (Safari, 카카오톡 인앱 브라우저)**:
- 사진을 **길게 누르기(long-press)** → 컨텍스트 메뉴 → "사진에 저장"
- 갤러리에서 풀스크린 사진을 보여줄 때 `<img>` 태그를 그대로 사용 (CSS background-image X)
- Save Image to Photos가 동작하도록 `<img src="..." alt="..." />` 형태로 직접 표시
- 핀치 줌 활성화 (`touch-action: pinch-zoom`)

**안드로이드 (Chrome, Samsung Internet, 카카오톡 인앱)**:
- 사진 **길게 누르기** → "이미지 다운로드" → 갤러리에 자동 저장
- 또는 다운로드 버튼 탭 → 갤러리 자동 저장

**명시적 다운로드 버튼도 제공**:
- 각 사진 우측 하단에 작은 아이콘 버튼 (`download` attribute)
- 누르면 `Content-Disposition: attachment; filename="golf-2026-05-11-3.jpg"` 헤더로 강제 다운로드
- 모바일 브라우저는 다운로드를 사진앱/갤러리에 자동 저장
- 전체 사진을 한꺼번에: **"사진 전체 다운로드(ZIP)"** 버튼

**기술적 구현 포인트**:
```html
<!-- 갤러리 사진 (iOS Long Press → 사진에 저장 가능) -->
<img src="https://golf.zerolive.co.kr/{shortId}/photo/{photoId}" 
     alt="라운드 사진" 
     loading="lazy" 
     style="touch-action: pinch-zoom;" />

<!-- 명시적 다운로드 버튼 -->
<a href="https://golf.zerolive.co.kr/{shortId}/photo/{photoId}?download=1" 
   download="golf-2026-05-11-h3.jpg">
   다운로드
</a>
```

Cloudflare Worker 응답 헤더:
```
Content-Type: image/jpeg
Content-Disposition: inline   (기본)
// ?download=1 쿼리 시
Content-Disposition: attachment; filename="..."
```

#### 10.3 갤러리 UX (라이트박스)
- 그리드 썸네일(3열) → 탭하면 풀스크린
- 풀스크린에서 좌/우 스와이프로 사진 이동
- 핀치 줌 가능
- 각 사진 캡션 표시 (옵션)
- 우측 상단 X 버튼으로 닫기
- 하단에 "사진 저장" / "다운로드" 버튼
- **순수 HTML + 최소 JS** (10KB 미만 라이트박스 라이브러리 또는 자체 구현)

#### 10.4 스코어카드 모바일 표시
- 4명 × 18홀 → 모바일 세로 화면에서는 좁음 → **가로 스크롤 허용** 또는 **9홀씩 2단**
- 합계(OUT/IN/TOT) 행은 sticky 처리
- 점수 셀: par 대비 색상 표시
  - 이글 이하: 진한 그린 동그라미
  - 버디: 그린 동그라미
  - 파: 기본
  - 보기: 옅은 회색 사각형
  - 더블 이상: 진한 회색 사각형

#### 10.5 PWA 기능 (옵션)
- `manifest.json` 제공 → 안드로이드 사용자가 "홈 화면에 추가" 가능
- 다음 라운드 공유 시 홈 화면 아이콘으로 빠른 재방문 (브랜드 효과)
- Service Worker로 오프라인 캐싱은 굳이 안 함 (만료성 컨텐츠라 의미 없음)

---

## 3. Viewer URL 호스팅 아키텍처

### 3.1 전체 흐름

```
[iPhone 앱]
  ↓ ① 라운드 데이터 + 사진 직렬화
  ↓ ② POST /api/share (디바이스 토큰 + 옵션)
[Cloudflare Worker (golf.zerolive.co.kr)]
  ↓ ③ shortId 생성 (base62 8자)
  ↓ ④ JSON → KV / 이미지 → R2 저장 (TTL 7일)
  ↓ ⑤ shortId + URL + editToken 반환
[iPhone 앱]
  ↓ ⑥ iOS 시스템 공유 시트
[안드로이드/iOS 친구]
  ↓ ⑦ 링크 탭 → 모바일 브라우저
[Cloudflare 엣지 → Worker → HTML 응답]
  - PIN 보호 시: 4자리 입력 화면 먼저
  - 검증 통과 시: 스코어카드 + 사진 앨범
  - 사진 long-press → 사진앱 저장
```

### 3.2 호스팅 구성 (Cloudflare 100%)

| 컴포넌트 | 역할 |
|----------|------|
| **Cloudflare Workers** | API + HTML 렌더링 |
| **Cloudflare KV** | shortId → 메타데이터 (TTL: 7일) |
| **Cloudflare R2** | 사진 파일 저장 (S3 호환, TTL 7일 자동 삭제) |
| **Cloudflare CDN** | 글로벌 엣지 캐싱 |
| **DNS** | 이미 Cloudflare → `golf.zerolive.co.kr` Worker 라우트 |

> **비용**: 무료 티어로 충분
> - KV: 100k reads/day, 1k writes/day
> - R2: 10GB 저장 + 매월 1M class A 무료
> - Workers: 100k requests/day

### 3.3 API 설계

```typescript
// POST /api/share — 새 viewer 생성
{ deviceToken, round, options: { nameVisibility, accessControl, pin? } }
→ { shortId, url, editToken, expiresAt }

// PUT /api/share/{shortId} — 업데이트 (editToken 필요)
// POST /api/share/{shortId}/photos — 사진 추가
// DELETE /api/share/{shortId}/photos/{photoId} — 사진 삭제
// GET /:shortId — HTML 렌더링 (PIN 보호 시 입력 화면 먼저)
// GET /:shortId/photo/:photoId[?download=1] — 사진 (인라인 / 다운로드)
// GET /:shortId/photos.zip — 전체 사진 ZIP 다운로드 (streaming)
```

### 3.4 보안 / 제약

- **shortId**: base62 8자 (218조 경우의 수)
- **editToken**: 별도 생성, KV 저장, 디바이스 외부 노출 X
- **PIN 보호**: bcrypt 해시 저장, 5회 오답 시 1시간 잠금
- **이미지**: 1장당 최대 10MB, 1 viewer당 최대 30장
- **Rate limiting**: 디바이스당 1분에 viewer 5개 생성 제한
- **HTTPS only**: Cloudflare 자동
- **개인정보**: 동반자 이름은 별명만, 실명/연락처 절대 업로드 X

---

## 4. 한국 골프장 DB 수집 방안

### 4.1 데이터 요구사항

| 필드 | 출처 | 난이도 |
|------|------|--------|
| 골프장 이름 | 공공데이터 | 쉬움 |
| 클럽하우스 위경도 | 공공데이터 + 지도 API | 쉬움 |
| holesCount (홀 수) | 공공데이터 / 카카오 enrichment | 중간 |
| courseType (타입) | 공공데이터 | 쉬움 |
| phone (전화번호) | 카카오 로컬 API enrichment | 쉬움 |
| kakaoPlaceUrl (카카오 장소 URL) | 카카오 로컬 API enrichment | 쉬움 |
| subCourses (서브코스 라벨) | 골프장 홈페이지 / 카카오·네이버 수동 보강 | 중간 |
| 각 홀의 파 (3/4/5) | 골프장 홈페이지 코스 가이드 | 중간 |
| 각 홀의 티박스 좌표 | **위성 이미지 수동 매핑** | 어려움 |
| 각 홀의 그린 좌표 | 위성 이미지 수동 매핑 | 어려움 |

### 4.2 수집 소스 (4단계 접근)

#### 1단계: 공공데이터로 기본 정보 (즉시 가능)

| 데이터셋 | URL | 내용 |
|----------|-----|------|
| 국토교통부 골프장현황도 | `data.go.kr/data/15015052/openapi.do` | RestAPI, 위치 정보 |
| 문화체육관광부 전국 골프장 | `data.go.kr/data/15118920/fileData.do` | 업소명, 소재지, 홀수 |
| 행정안전부 골프장 (LOCALDATA) | `data.go.kr/data/15045080/fileData.do` | 좌표 (EPSG:5174 → WGS84 변환) |
| 경기데이터드림 - 업종별 골프장 | `data.gg.go.kr` | 명칭, 경도·위도 |

이 단계로 **약 500-635개 한국 골프장의 이름 + 클럽하우스 좌표** 확보 가능.

#### 2단계: OSM Overpass API로 홀별 정보 자동 수집

OSM에는 `golf=hole`, `golf=tee`, `golf=green`, `par=*`, `ref=*` 태그가 정의되어 있어 자동 수집 가능.

```overpass
[out:json][timeout:60];
area["ISO3166-1"="KR"]->.kr;
(
  way["leisure"="golf_course"](area.kr);
  relation["leisure"="golf_course"](area.kr);
);
map_to_area->.courses;
(
  way(area.courses)["golf"="tee"];
  way(area.courses)["golf"="green"];
  way(area.courses)["golf"="hole"];
);
out geom;
```

> 한국 골프장 OSM 매핑률: **약 30-50% 추정**. 나머지는 수동 보완 필요.

#### 3단계: 위성 이미지 + 골프장 홈페이지 수동 매핑

OSM에 없는 곳은:
1. 골프장 공식 홈페이지 "코스 정보/야디지" 페이지에서 홀별 파 정보
2. Google Maps / 카카오맵 / 네이버맵 위성뷰에서 티박스/그린 좌표 추출
3. **자체 어드민 도구** 제작 (React + Leaflet) — 위성 지도에 클릭으로 좌표 찍기

#### 4단계: 베타 사용자 제보 (지속 갱신)

- 앱에 "이 골프장이 목록에 없어요" 버튼
- "홀 정보가 틀려요" 보고 기능 (실 GPS와 등록 좌표 비교)
- 시간 경과 시 자가 정확화

### 4.3 권장 진행 순서

| 단계 | 작업 | 산출물 | 소요 |
|------|------|--------|------|
| P0 | 공공데이터 + OSM + 카카오 enrichment → v3 통합 | `courses_seed_v3.json` (1,163곳) | 완료 (2026-05-12) |
| P1 | OSM Overpass 자동 수집 | 홀별 정보 (complete 3 / partial 12 / minimal 9 / low 1139) | 완료 |
| P2 | 서브코스 라벨 보강 (카카오/네이버 또는 수동) | 27/36홀 골프장 387곳 SubCourse 라벨 추가 | 진행 예정 |
| P3 | 홀별 좌표 점진 매핑 + 제보 반영 | complete/partial 점진 확대 | 지속 |

> **MVP 출시 기준**: v3 DB 번들 (골프장 + 서브코스 GPS 자동 감지, 홀 진행 수동)

### 4.4 데이터 구조 (앱 번들 JSON) — v3 기준

```json
{
  "version": "2026.05.12",
  "totalCourses": 1163,
  "courses": [
    {
      "id": "스카이힐골프클럽",
      "name": "스카이힐 골프클럽",
      "region": "경기",
      "holesCount": 36,
      "courseType": "CC",
      "phone": "031-XXX-XXXX",
      "kakaoPlaceUrl": "https://place.map.kakao.com/XXXXXXX",
      "clubhouse": { "lat": 37.4567, "lng": 127.1234 },
      "subCourses": [
        {
          "name": "동코스",
          "holes": []
        },
        {
          "name": "서코스",
          "holes": []
        }
      ],
      "holes": [],
      "dataQuality": "low"
    }
  ]
}
```

> **subCourses 필드**: v3에는 서브코스 좌표 데이터가 없으므로 현재 `holes: []`. 후속 데이터 보강 시 채워짐.  
> **holesCount nil**: 638곳은 홀 수 미기재. 라운드 생성 시 사용자 입력 프롬프트(9/18/27/36 선택) 표시.

JSON 크기: 한국 골프장 DB v3 (1,163곳, 2026-05-12 빌드) — 약 **727KB** (앱 번들 무리 없음).

---

## 5. 디자인 시스템 — "사계절 그린" 테마

### 5.1 디자인 원칙

- **레퍼런스**: Google Stitch로 목업 생성 예정
- **컨셉**: simple, 4계절의 그린(잔디) 느낌, 세련, 컴포넌트 절제
- **준수 가이드**: 
  - Apple HIG (clarity, deference, depth)
  - Material Design 3 (Material You, expressive)
  - Anthropic Frontend Design Skill (intentional aesthetic, distinctive choices)

### 5.2 컬러 팔레트 — "사계절 그린"

#### 🌱 Spring — 라이트 디폴트
```
--green-primary:    #7FB069   /* 새 잔디 */
--green-secondary:  #B8D8B0
--green-accent:     #C5E1A5
--surface:          #FAFCF7
--surface-elevated: #FFFFFF
--text-primary:     #1F2A1B
--text-secondary:   #5A6850
--border:           #E8EFE0
```

#### ☀️ Summer — 비비드
```
--green-primary:    #2D7A3E
--green-secondary:  #4CAF50
--green-accent:     #66BB6A
--surface:          #F0F7F1
--text-primary:     #0E2913
```

#### 🍂 Autumn — 따뜻한 톤
```
--green-primary:    #6B7F3E
--green-secondary:  #C4A04A
--green-accent:     #D4B574
--surface:          #FAF7F0
--text-primary:     #2A2515
```

#### ❄️ Winter — 다크 디폴트
```
--green-primary:    #5A8A6B
--green-secondary:  #2A3F35
--green-accent:     #8FB5A0
--surface:          #0F1612
--surface-elevated: #1A241E
--text-primary:     #E8F0EA
--text-secondary:   #9AAA9F
--border:           #2A3530
```

> 디폴트: 시스템 라이트 → Spring, 시스템 다크 → Winter. 설정에서 4계절 수동 선택 가능.

### 5.3 타이포그래피

```
--font-display: "SF Pro Display", -apple-system, sans-serif;
--font-text:    "SF Pro Text", -apple-system, sans-serif;
--font-mono:    "SF Mono", "Menlo", monospace;

/* iOS HIG 사이즈 */
--text-largeTitle: 34pt / 700
--text-title1:     28pt / 700
--text-title2:     22pt / 600
--text-headline:   17pt / 600
--text-body:       17pt / 400
--text-callout:    16pt / 400
--text-subhead:    15pt / 500
--text-footnote:   13pt / 400
--text-caption:    12pt / 400

/* 점수 디스플레이 */
--score-watch:  56pt / 600
--score-iphone: 44pt / 600
```

Web viewer는 Pretendard 또는 시스템 sans-serif.

### 5.4 컴포넌트 가이드

- **그림자**: 최소 (1-2단계)
- **테두리**: 1pt, `--border` 색상
- **둥근 모서리**: `--radius-sm: 8pt`, `--radius-md: 12pt`, `--radius-lg: 16pt`
- **아이콘**: SF Symbols `.regular` 두께
- **버튼**: filled / tinted / plain 3종류만
- **간격**: 8pt 그리드 (8, 16, 24, 32, 48)

핵심 컴포넌트: CourseCard, PlayerChip, ScoreCell, HoleProgress, ShotButton, PenaltyButton, PhotoGalleryGrid, ShareSheet

### 5.5 야외 가독성

- 모든 화면 **최소 4.5:1 명도 대비** (WCAG AA)
- 라운드 시작 시 한 번 "밝기 최대 권장" 안내
- 점수 숫자 항상 `weight: .semibold` 이상

---

## 6. 데이터 모델

```swift
@Model
final class Round {
    var id: UUID
    var date: Date
    var courseId: String
    var courseName: String
    var courseSubName: String?
    var players: [Player]
    var holes: [HoleScore]
    var photos: [RoundPhoto]
    var isFinished: Bool
    var startedAt: Date
    var finishedAt: Date?
    var sharedShortId: String?
    var sharedURL: String?
    var sharedExpiresAt: Date?
    var sharedEditToken: String?
    var sharedOptions: ShareOptions?
}

@Model
final class Player {
    var id: UUID
    var name: String
    var isOwner: Bool
    var order: Int
}

@Model
final class HoleScore {
    var holeNumber: Int
    var par: Int
    var counts: [UUID: Int]
    var obCount: [UUID: Int]
    var hazardCount: [UUID: Int]
}

@Model
final class RoundPhoto {
    var id: UUID
    var localPath: String
    var remoteURL: String?
    var capturedAt: Date
    var holeNumber: Int?
    var caption: String?
}

struct ShareOptions: Codable {
    var nameVisibility: NameVisibility   // .real / .anonymous
    var accessControl: AccessControl     // .public / .pin(String)
}

@Model
final class GolfCourse {
    var id: String
    var name: String
    var region: String
    var clubhouseLat: Double
    var clubhouseLng: Double
    var holesCount: Int?          // 총 홀 수 (nil이면 라운드 시작 시 사용자 입력)
    var courseType: String?       // "CC", "GC" 등
    var phone: String?            // 전화번호
    var kakaoPlaceUrl: String?    // 카카오 장소 URL
    var subCourses: [SubCourse]?  // 서브코스 목록 (27/36홀 골프장, 후속 보강 필요)
    var holes: [HoleInfo]         // 홀별 정보 (complete/partial/minimal 코스에만 존재)
    var dataQuality: DataQuality  // complete / partial / minimal / low
}

/// 서브코스 값 타입 (동/서/남/북 또는 전반/후반 라벨)
struct SubCourse: Codable {
    var name: String          // 서브코스 라벨 — 서브코스 라벨 (동/서/남/북 또는 전반/후반)
    var holes: [HoleInfo]     // 해당 서브코스의 홀 정보 (v3에서는 비어있음, 후속 보강)
}

struct HoleInfo: Codable {
    var number: Int
    var par: Int
    var teeLat: Double
    var teeLng: Double
    var greenLat: Double
    var greenLng: Double
}

enum DataQuality: String, Codable {
    case complete  // complete 3곳 (전체의 0.26%): 18홀 완전 매핑
    case partial   // partial 12곳: 9홀 이상 매핑
    case minimal   // minimal 9곳: 1~8홀 매핑
    case low       // low 1139곳: 홀 정보 없음 — F3 골프장+서브코스 GPS 감지만 동작, 홀 진행은 수동
    case unknown   // 분류 미정 (안전 fallback)
}
```

> **Round.courseSubName**: 이미 존재하는 필드 (`String?`). 수동 입력 또는 GPS 서브코스 감지 결과를 저장한다.

---

## 7. 화면 구성

### 7.1 iPhone

1. **홈** — 최근 라운드 카드 리스트 + "새 라운드"
2. **새 라운드 시작** — 자동 매칭 골프장 + 동반자 입력
3. **라운드 진행** — 4×18 그리드, 현재 홀 하이라이트
4. **사진 추가** — 라운드 중/후 사진 첨부
5. **라운드 종료** — 요약 + 사진 미리보기 + 공유
6. **공유 옵션 모달**:
   ```
   공유 옵션
   ─────────
   이름 공개:  ○ 실명  ● 익명
   접근 권한:  ● 공개   ○ PIN [____]
   만료: 7일 후
   [공유 링크 생성]
   ```
7. **라운드 상세** — 사후 보기, 사진 추가/삭제, viewer 재공유
8. **설정** — iCloud, HealthKit, 4계절 테마, 권한

### 7.2 Apple Watch

```
┌─────────────────┐
│   3번 홀 Par 4   │  ← 수동 홀 선택
│  [동코스]        │  ← 서브코스 라벨 표시 (자동)
│                 │
│    ╔══════╗     │
│    ║  5   ║     │  ← 큰 카운트
│    ║ (+1) ║     │     par 대비
│    ╚══════╝     │
│                 │
│  [큰 탭 영역]    │  ← 탭 → +1
│                 │  ← Crown 회전
│                 │
│ ⛳ OB │💧H│ ✓ OK │
│                 │
│ ● ● ● ◐ ○ ○ ... │
└─────────────────┘

좌/우 → 홀 이동
상/하 → 본인 ↔ 동반자
```

### 7.3 Haptic 패턴

| 액션 | Haptic |
|------|--------|
| +1 카운트 | `.click` |
| −1 (수정) | `.click` (다른 톤) |
| OB 탭 | `.notification(.warning)` |
| 해저드 탭 | `.click` × 2 |
| OK 탭 | `.success` (짧게) |
| 홀 수동 전환 | `.notification(.success)` |
| 홀 수동 전환(스와이프) | `.directionUp/Down` |
| 동반자 전환 | `.click` × 2 |
| GPS 매칭 완료 | `.success` |
| 라운드 종료 | `.success` (길게) |

---

## 8. 핵심 자동화 로직

### 8.1 골프장 자동 매칭

```
1. CLLocationManager.requestLocation() (1회)
2. GolfCourse DB 순회 → Haversine 거리 계산
3. 3km 이내 후보 중 가장 가까운 1개 디폴트
4. "○○골프장 자동 선택됨 (변경)" 표시
5. 매칭 실패 시 → 수동 선택 (검색 가능)
```

### 8.2 골프장 + 서브코스 GPS 감지 구현

> **F3 GPS 자동 감지 — 골프장 + 서브코스 단위 (홀 단위 자동 감지는 미제공, 수동 진행)**

```
[골프장 단위 감지 — 모든 1,163곳에서 동작]
1. CLLocationManager.requestLocation() (1회)
2. GolfCourse DB 순회 → Haversine 거리 계산
3. 3km 이내 후보 중 가장 가까운 1개 디폴트 표시
4. "○○골프장 자동 선택됨 (변경)" 표시

[서브코스 감지 — holesCount > 18 && subCourses != nil && !isEmpty]
5. subCourses 배열이 있으면 SubCourseSelector UI 표시
6. 사용자가 서브코스 라벨 (동/서/남/북 또는 전반/후반) 수동 선택
7. Round.courseSubName = 선택된 SubCourse.name 저장

[홀 진행 — 항상 수동 홀 진행 모드]
8. 사용자가 스와이프/탭으로 다음 홀 이동
9. 홀 단위 자동 감지는 미제공 — 수동 홀 진행만 지원 (F3는 골프장+서브코스 단위 GPS 감지만 제공)

[holesCount nil 처리]
10. holesCount == nil이면 라운드 시작 시 9/18/27/36 선택 프롬프트 표시
```

### 8.3 카운터 입력 검증

- 한 홀 최대 카운트: **15타**
- 최소: 1타 (홀인원)
- OB/해저드 누적은 별도 트래킹

---

## 9. 권한 / 개인정보

| 권한 | 시점 | 이유 |
|------|------|------|
| 위치 (When In Use) | 앱 실행 시 | 골프장 매칭, 홀 감지 |
| HealthKit (Workout Write) | 라운드 시작 시 | 워크아웃 기록 |
| 사진 (선택 접근) | 사진 추가 시 | 라운드 사진 첨부 |
| 카메라 | 즉석 촬영 시 | 라운드 중 촬영 |
| 알림 | 라운드 시작 시 | 홀 전환 알림 |
| iCloud (자동) | 백그라운드 | sync |

**개인정보 처리**:
- 위치: 디바이스 외부 전송 X
- 동반자 이름: 로컬 + iCloud, viewer 공유 시 사용자 선택 반영
- viewer 데이터/사진: 7일 후 자동 삭제 (KV/R2 TTL)
- 디바이스 토큰: 익명 UUID

---

## 10. 개발 작업 분담 ⭐ (v4 신규)

요청 사항 3가지를 명확히 분리합니다.

### 10.1 Claude Code에서 작업할 내용 (코드 + 문서)

#### 코드 (메인)
- ✅ iOS 앱 (Swift + SwiftUI, iOS 17+ 타겟)
- ✅ watchOS 앱 (Swift + SwiftUI, watchOS 10+ 타겟)
- ✅ Shared 프레임워크 (모델, 비즈니스 로직)
- ✅ CloudKit / SwiftData 연동
- ✅ WatchConnectivity 통신
- ✅ HealthKit 워크아웃 연동
- ✅ Cloudflare Worker (TypeScript) — API + HTML 렌더링
- ✅ Viewer HTML 템플릿 (반응형, 다크모드, 라이트박스, 사진앱 저장 지원)
- ✅ Cloudflare KV / R2 바인딩 설정
- ✅ 한국 골프장 데이터 수집 스크립트 (Python/Node) — 공공데이터 + OSM 통합
- ✅ 한국 골프장 어드민 도구 (React + Leaflet, 위성지도에 좌표 찍기)
- ✅ 빌드/배포 스크립트
- ✅ 단위 테스트

#### 문서 (Claude Code가 작성)
- ✅ `README.md` — 프로젝트 개요, 빌드/실행 방법
- ✅ `ARCHITECTURE.md` — 전체 아키텍처, 컴포넌트 다이어그램
- ✅ `API.md` — Cloudflare Worker API 명세
- ✅ `DATA_SCHEMA.md` — SwiftData/CloudKit 스키마 + JSON 골프장 스키마
- ✅ `CHANGELOG.md` — 버전별 변경사항
- ✅ 인라인 코드 주석 (Swift 표준 doc comment, TypeScript JSDoc)
- ✅ 각 모듈별 README

### 10.2 Google Stitch에서 작업해서 가져올 내용

> Stitch는 시각적 결과물(이미지/Figma)을 만들고, 실제 SwiftUI 코드는 Claude Code에서 작성. 두 도구 역할 분리.

#### Stitch 산출물 (이미지/PNG/Figma)
- 🎨 **iPhone 화면 목업** (8화면)
  - 홈 (최근 라운드 리스트)
  - 새 라운드 시작 (자동 매칭 골프장 + 동반자 입력)
  - 라운드 진행 (4×18 스코어카드, 현재 홀 하이라이트)
  - 페널티 입력 (OB/해저드/OK 모달)
  - 사진 추가 (카메라/갤러리 선택)
  - 라운드 종료 (요약 + 사진 미리보기)
  - 공유 옵션 모달 (실명/익명, 공개/PIN)
  - 라운드 상세 (사후 보기, 사진 관리)
  - 설정 (4계절 테마 선택 포함)
- ⌚ **Apple Watch 화면 목업** (4화면)
  - 메인 점수 입력 (큰 카운트 + 페널티 버튼)
  - 홀 전환 애니메이션
  - 동반자 전환
  - 라운드 종료 메뉴
- 🌐 **Viewer 웹 페이지 목업** (5화면)
  - 모바일 메인 (스코어카드 + 사진 갤러리 진입)
  - PIN 입력 화면
  - 사진 갤러리 라이트박스
  - 사진 풀스크린 (다운로드/저장 버튼)
  - 만료/오류 페이지
- 🎨 **디자인 시스템 페이지** (Stitch 안에 정리)
  - 4계절 컬러 팔레트 비교
  - 타이포그래피 샘플
  - 컴포넌트 카탈로그 (ShotButton, PenaltyButton 등)

#### Stitch 작업 시 입력 프롬프트 예시

```
Korean golf score-tracking iPhone app. Calm, refined "four-seasons-grass" 
aesthetic. Spring palette as default: primary #7FB069, surface #FAFCF7. 
Typography: SF Pro Display / Pretendard. Generous whitespace, minimal shadows, 
8pt grid. No glassmorphism, no gradients. 

Components needed:
- Large "+1 shot" tap area (button takes 60% of screen)
- Small penalty buttons row (OB / Hazard / OK)
- Hole progress dots (18 dots, current highlighted)
- Photo gallery grid (3 columns, square thumbnails)
- Share options sheet with toggles (real name/anonymous, public/PIN)
- Score card grid (4 players × 18 holes, sticky totals row)

Inspired by: Apple Fitness app, Day One Journal, Things 3, Material You 
Expressive. But distinctly its own — feels like fresh grass after morning rain.
```

#### Stitch → Claude Code 인계 방식
1. Stitch에서 화면 export (PNG + Figma 링크)
2. 각 화면에 대해 다음 문서 동봉:
   - 화면 이름
   - 사용된 컴포넌트 리스트
   - 컬러/타이포 토큰 매핑
   - 인터랙션 노트 (탭 시 동작, 애니메이션)
3. Claude Code는 이미지 + 노트를 보고 SwiftUI 구현

### 10.3 실제 구현 개발 시작 전에 만들어야 할 Markdown 문서 리스트 ⭐

**개발 착수 전에 모두 작성/확정**돼 있어야 함. 순서대로:

#### 0번대 - 기획/요구사항
- [ ] `00-OVERVIEW.md` — 제품 개요, 타겟 사용자, 핵심 가치 제안 (1-2페이지)
- [ ] `01-USER_STORIES.md` — 사용자 스토리 ("나는 ___로서 ___를 하고 싶다") 형식, 우선순위 부여
- [ ] `02-USER_FLOWS.md` — 주요 플로우 5-7개 (앱 첫 실행, 라운드 시작, 점수 입력, 라운드 종료, 공유, viewer 방문, 사진 다운로드)
- [ ] `03-NON_FUNCTIONAL.md` — 비기능 요구사항 (성능, 보안, 접근성, 배터리, 오프라인 동작 등)

#### 10번대 - 디자인
- [ ] `10-DESIGN_SYSTEM.md` — 4계절 컬러 토큰, 타이포, 간격, 그림자, 라운드 모서리 (이 명세서 §5 정리)
- [ ] `11-COMPONENTS.md` — 컴포넌트 카탈로그 (각 컴포넌트의 props, 상태, 변형)
- [ ] `12-SCREENS.md` — 화면 카탈로그 (Stitch 목업 링크 + 화면별 동작 명세)
- [ ] `13-HAPTICS_AND_MOTION.md` — Haptic 패턴 표 + 트랜지션 명세
- [ ] `14-ACCESSIBILITY.md` — VoiceOver 라벨, Dynamic Type, 명도 대비 가이드라인

#### 20번대 - 아키텍처
- [ ] `20-ARCHITECTURE.md` — 전체 아키텍처 (iOS 앱 / watchOS 앱 / Worker / KV / R2 / iCloud) 다이어그램
- [ ] `21-DATA_MODEL.md` — SwiftData/CloudKit 스키마 (이 명세서 §6 정리)
- [ ] `22-STATE_MANAGEMENT.md` — 라운드 진행 중 상태 관리, Watch ↔ iPhone sync 전략
- [ ] `23-OFFLINE_BEHAVIOR.md` — 네트워크 없을 때 동작 (로컬 우선, 추후 sync)

#### 30번대 - 백엔드 / API
- [ ] `30-API_SPEC.md` — Cloudflare Worker API 전체 명세 (요청/응답 스키마, 에러 코드)
- [ ] `31-VIEWER_HTML.md` — Viewer HTML 구조, 모바일 우선 가이드라인, **사진 long-press 저장** 동작 명세
- [ ] `32-CLOUDFLARE_SETUP.md` — KV/R2/Worker/DNS 셋업 가이드 (재현 가능하게)
- [ ] `33-SECURITY.md` — shortId 생성 정책, editToken, PIN bcrypt, rate limit, 데이터 보존 기간

#### 40번대 - 데이터
- [ ] `40-COURSE_DB_SCHEMA.md` — 한국 골프장 JSON 스키마 (이 명세서 §4.4)
- [ ] `41-COURSE_DB_PIPELINE.md` — 데이터 수집 파이프라인 (공공데이터 → OSM → 수동 매핑 → 사용자 제보)
- [ ] `42-COURSE_ADMIN_TOOL.md` — 어드민 도구 (React + Leaflet) 명세

#### 50번대 - 운영
- [ ] `50-PRIVACY_POLICY.md` — 개인정보 처리방침 (App Store 심사용)
- [ ] `51-TERMS_OF_SERVICE.md` — 이용약관
- [ ] `52-APP_STORE_LISTING.md` — 앱스토어 등록 정보 (이름, 설명, 키워드, 스크린샷 가이드)
- [ ] `53-PERMISSIONS.md` — 권한 요청 메시지 정리 (NSLocationWhenInUseUsageDescription 등)

#### 60번대 - 테스트 / 배포
- [ ] `60-TEST_PLAN.md` — 단위 테스트, UI 테스트, GPS 시뮬레이션, 베타 테스터 시나리오
- [ ] `61-BETA_PLAN.md` — TestFlight 배포 계획, 베타 테스터 모집/관리
- [ ] `62-RELEASE_CHECKLIST.md` — 배포 전 체크리스트

#### 권장 작성 순서 (의존성 고려)

```
00 → 01 → 02 → 03       (기획 확정)
       ↓
10 → 11 → 12 → 13 → 14  (디자인 확정, Stitch 작업 병행)
       ↓
20 → 21 → 22 → 23       (아키텍처 확정)
       ↓
30 → 31 → 32 → 33       (백엔드 명세)
       ↓
40 → 41 → 42            (데이터)
       ↓
50 → 51 → 52 → 53       (운영)
       ↓
[Claude Code 개발 착수]
       ↓
60 → 61 → 62            (테스트/배포)
```

**최소 작성 권장 (시간 부족 시 우선순위)**:
1. `00-OVERVIEW.md`
2. `02-USER_FLOWS.md`
3. `10-DESIGN_SYSTEM.md`
4. `21-DATA_MODEL.md`
5. `30-API_SPEC.md`
6. `31-VIEWER_HTML.md`
7. `40-COURSE_DB_SCHEMA.md`
8. `53-PERMISSIONS.md`

위 8개만 있으면 Claude Code가 일관성 있게 코드 생성 가능.

---

## 11. 개발 단계별 작업 순서 (Claude Code, 단일 Phase)

> 사전 문서 작성 후 본격 개발 시작.

### Step 1: 프로젝트 셋업
Xcode 워크스페이스 (iOS + watchOS + Shared), SwiftData 모델, CloudKit 컨테이너

### Step 2: 한국 골프장 시드 데이터
공공데이터 다운로드 스크립트 → OSM Overpass 통합 → 인기 100개 수동 매핑 → `courses.json` 앱 번들

### Step 3: 디자인 시스템 구현
4계절 컬러 토큰 (`Color+SeasonalGreen.swift`), 타이포 스타일, 공통 컴포넌트 라이브러리

### Step 4: 자동 매칭 + 새 라운드 화면
CoreLocation, Haversine 거리 계산, 골프장 선택 UI, 동반자 입력 (별명 자동, 최근 동반자)

### Step 5: iPhone 스코어카드 UI
4×18 그리드, 셀 탭 +1 / 길게 −1, 합계 자동 계산, OB/해저드/OK 버튼

### Step 6: Apple Watch 앱
Digital Crown 카운터, 큰 탭 영역, 스와이프, Haptic, 페널티 버튼

### Step 7: WatchConnectivity
iPhone ↔ Watch 점수 sync, 라운드 상태 sync, 충돌 처리

### Step 8: 골프장 + 서브코스 GPS 감지 구현
골프장 단위 GPS 매칭 (1,163곳 전체 동작), SubCourseSelector UI (27/36홀 골프장 387곳), holesCount nil 프롬프트 처리. **홀 단위 자동 감지 코드 미포함 — 수동 홀 진행 모드만 구현.**

### Step 9: CloudKit + 라운드 재개
SwiftData ↔ CloudKit 자동 sync, 미완료 라운드 복구

### Step 10: HealthKit 연동
`HKWorkoutSession` 시작/종료, 워크아웃 저장

### Step 11: 사진 첨부
PhotoKit, 카메라, 라운드별 사진 갤러리, 캡션

### Step 12: Cloudflare Worker + KV + R2 (Viewer 백엔드)
- Worker TypeScript 코드
- KV/R2 바인딩
- API 엔드포인트 (POST/PUT/DELETE/GET)
- PIN bcrypt + editToken 인증
- HTML 템플릿 — **모바일 우선, 사진 long-press 저장, 다운로드 버튼, ZIP 다운로드**

### Step 13: 공유 기능 (앱 측)
공유 옵션 모달 (실명/익명, 공개/PIN) → viewer API 호출 → 시스템 공유 시트

### Step 14: 4계절 테마 전환 시스템
시스템 다크모드 연동 + 설정에서 수동 4계절 선택

### Step 15: 마무리
권한 안내, 설정 화면, 앱 아이콘, 스플래시, 라운드 자동 종료 감지, 에러 처리

### Step 16: 한국 골프장 어드민 도구
React + Leaflet, 위성지도 좌표 찍기, JSON export

### Step 17: 테스트 + 배포 준비
단위 테스트, GPS Mock, TestFlight 빌드

---

## 12. UX 원칙

1. **3탭 룰**: 한 작업 최대 3탭
2. **Digital Crown 우선**: Watch에서 Crown 활용 극대화
3. **Haptic 동기화**: 시각과 진동을 함께
4. **모달 최소화**: 라운드 진행 중 팝업 절대 금지
5. **다크모드 + 야외 가독성**: 햇빛에서도 잘 보이는 고대비
6. **에러 메시지 친화**: 영어 직역 표현 금지
7. **간결함**: "스코어 입력과 공유" 외 모든 것 배제

---

## 13. 결정된 사항 (v3 → v4)

| 항목 | v3 | v4 (확정) |
|------|-----|-----|
| Viewer 모바일 최적화 | 반응형 | **모바일 우선 설계** |
| 사진앱 저장 | 다운로드 버튼만 | **long-press 저장 + 다운로드 버튼 + ZIP** |
| 작업 분담 | 미정 | **Claude Code / Stitch / 사전 문서 명확 분리** |
| 사전 문서 | 없음 | **15+ 종류의 markdown 문서 리스트** |

---

## 14. 참고 자료

- **Apple HIG**: https://developer.apple.com/design/human-interface-guidelines/
- **Material Design 3**: https://m3.material.io/
- **공공데이터포털 골프장**:
  - https://www.data.go.kr/data/15015052/openapi.do (국토교통부 골프장현황도)
  - https://www.data.go.kr/data/15118920/fileData.do (문화체육관광부 전국 골프장)
  - https://www.data.go.kr/data/15045080/fileData.do (행정안전부 골프장 LOCALDATA)
- **OSM Golf 매핑**:
  - https://wiki.openstreetmap.org/wiki/Tag:leisure=golf_course
  - https://wiki.openstreetmap.org/wiki/Tag:golf=hole
  - Overpass Turbo: https://overpass-turbo.eu/
- **Cloudflare**:
  - Workers: https://developers.cloudflare.com/workers/
  - KV: https://developers.cloudflare.com/kv/
  - R2: https://developers.cloudflare.com/r2/
- **Google Stitch**: https://stitch.withgoogle.com/
