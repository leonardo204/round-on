# ref-docs — 라운드온 설계·명세 문서 전체 인덱스

> 이 디렉토리는 라운드온(Round-On) 앱의 모든 설계 결정과 명세의 원본이다.
> 코드 구현 전 이 문서들이 먼저 작성되었으며, 구현의 단일 진실 공급원(Single Source of Truth) 역할을 한다.

---

## 버전 호환성

| 컴포넌트 | 버전 | 날짜 | 상태 |
|---------|------|------|------|
| App Specification | v4 | 2026-05-11 | 확정 |
| Golf Course DB | v3 | 2026-05-12 | 확정 (965곳) |
| Data Pipeline | v3 | 2026-05-12 | 재현 가능 |
| Cloudflare Worker | 0.1 | 2026-05-12 | 미배포 |
| iOS App MVP | 0.1 | 2026-05-13 | 빌드 통과, 미배포 |

---

## 디렉토리 구조

```
ref-docs/
├── README.md              ← 지금 이 파일 (전체 인덱스)
├── specs/                 ← 기능명세 + 설계 문서 18종
│   ├── README.md          ← specs/ 카테고리 인덱스
│   ├── 00-OVERVIEW.md     ← 제품 개요
│   ├── 01-SPEC.md         ← 기능 명세서 v4 (마스터)
│   ├── 02-USER_FLOWS.md   ← 사용자 플로우
│   ├── 10~14-*.md         ← 디자인 시스템·컴포넌트·화면·햅틱·접근성
│   ├── 20~23-*.md         ← 아키텍처·데이터모델·상태관리·오프라인
│   ├── 30~33-*.md         ← API·Viewer·Cloudflare·보안
│   └── 50, 53-*.md        ← 개인정보·권한
├── golf-db-pack/          ← 한국 골프장 DB v3 (965곳)
│   ├── README.md          ← DB 패키지 빠른 시작
│   ├── 40-COURSE_DB_SCHEMA.md  ← JSON 스키마 + Swift 예시
│   └── 41-COURSE_DB_PIPELINE.md ← 데이터 수집·빌드 파이프라인
├── data/                  ← 원시 데이터 파일
│   └── README.md
├── design-stitch/         ← UI 시안 (Google Stitch 생성)
│   ├── stitch-prompt.md   ← Stitch 작업 프롬프트 v2
│   └── screens/           ← iPhone(10) + Watch(7) + Mobile-Web(5) PNG/HTML
└── claude/                ← Claude Code 개발 보조 문서
    ├── context-db.md
    ├── context-monitor.md
    ├── conventions.md
    └── setup.md
```

---

## specs/ — 카테고리별 문서 목록

`specs/README.md`에 전체 인덱스가 있다. 여기서는 5개 카테고리 개요만 표시한다.

### 00번대 — 제품 정의

앱의 정체성, 기능 목록, 사용자 플로우를 정의한다. 처음 프로젝트를 파악할 때 이 세 문서를 순서대로 읽는다.

| 파일 | 설명 |
|------|------|
| [00-OVERVIEW.md](specs/00-OVERVIEW.md) | 제품 정체성, 가치 제안, Non-Goals, 제약사항 |
| [01-SPEC.md](specs/01-SPEC.md) | **마스터 기능 명세서 v4** — F1~F14 전체 기능 + 디자인 시스템 + 작업 분담 |
| [02-USER_FLOWS.md](specs/02-USER_FLOWS.md) | F-A~F-G 7개 골든패스, 권한 거부 분기, 플로우 다이어그램 |

### 10번대 — 디자인 시스템

색상·타이포·컴포넌트·화면·햅틱·접근성을 다룬다. 디자이너와 iOS 개발자가 참조한다.

| 파일 | 설명 |
|------|------|
| [10-DESIGN_SYSTEM.md](specs/10-DESIGN_SYSTEM.md) | 4계절 컬러 토큰, 타이포그래피, 8pt 그리드, 다크모드 |
| [11-COMPONENTS.md](specs/11-COMPONENTS.md) | 8+2종 컴포넌트 props/상태/변형, elevation 토큰 |
| [12-SCREENS.md](specs/12-SCREENS.md) | Stitch 시안 22화면 매핑, ScoreCell Variant B 채택, 색상·폰트 교체 정책 |
| [13-HAPTICS_AND_MOTION.md](specs/13-HAPTICS_AND_MOTION.md) | WKHapticType 매핑, 모션 토큰 4종, Reduce Motion |
| [14-ACCESSIBILITY.md](specs/14-ACCESSIBILITY.md) | VoiceOver 4-tuple, Dynamic Type 스케일, WCAG AA 대비, par-diff 모양 매핑 |

### 20번대 — 앱 아키텍처

시스템 구조, 데이터 모델, 상태 관리, 오프라인 동작을 다룬다. iOS 개발자 필독.

| 파일 | 설명 |
|------|------|
| [20-ARCHITECTURE.md](specs/20-ARCHITECTURE.md) | 컴포넌트/모듈/데이터 흐름, GolfCourse·iCloud 결정 |
| [21-DATA_MODEL.md](specs/21-DATA_MODEL.md) | SwiftData @Model 4종, DataQuality enum, GolfCourse 모델, CloudKit 매핑 |
| [22-STATE_MANAGEMENT.md](specs/22-STATE_MANAGEMENT.md) | @Observable ViewModel 5종, WatchConnectivity 메시지 3종, 카운터 delta-merge |
| [23-OFFLINE_BEHAVIOR.md](specs/23-OFFLINE_BEHAVIOR.md) | PendingOperation 큐, 백오프, Viewer 만료 nil 처리 |

### 30번대 — 백엔드

Cloudflare Worker API, Viewer HTML, 인프라 셋업, 보안 정책을 다룬다.

| 파일 | 설명 |
|------|------|
| [30-API_SPEC.md](specs/30-API_SPEC.md) | Cloudflare Worker 7개 엔드포인트, 요청·응답 JSON 스키마 |
| [31-VIEWER_HTML.md](specs/31-VIEWER_HTML.md) | viewer HTML 구조, 사진 long-press 저장, PIN 잠금 화면 |
| [32-CLOUDFLARE_SETUP.md](specs/32-CLOUDFLARE_SETUP.md) | KV 4네임스페이스, R2 버킷, wrangler.toml 구성 |
| [33-SECURITY.md](specs/33-SECURITY.md) | bcrypt 12, PIN 검증 엔드포인트, PII 마스킹 정책 |

### 50번대 — 정책

App Store 제출 및 법적 요건을 다룬다.

| 파일 | 설명 |
|------|------|
| [50-PRIVACY_POLICY.md](specs/50-PRIVACY_POLICY.md) | 개인정보 처리방침 (PIPA §30), App Store Privacy Nutrition Label — DRAFT |
| [53-PERMISSIONS.md](specs/53-PERMISSIONS.md) | Info.plist 권한 키, usage string 한/영, 요청 시점 UX — DRAFT |

---

## golf-db-pack/ — 한국 골프장 DB v3

한국 골프장 965곳 데이터셋. OpenStreetMap(ODbL) + 공공데이터 + 카카오 enrichment.

| 파일 | 설명 |
|------|------|
| [README.md](golf-db-pack/README.md) | 빠른 시작, 데이터 요약, 갱신 방법, 라이선스 |
| [40-COURSE_DB_SCHEMA.md](golf-db-pack/40-COURSE_DB_SCHEMA.md) | JSON 스키마 명세, Swift `CourseRepository` 예시, v2→v3 변경 이력 |
| [41-COURSE_DB_PIPELINE.md](golf-db-pack/41-COURSE_DB_PIPELINE.md) | OSM 수집 → 공공데이터 통합 → 카카오 enrichment → 중복 통합 전 과정 |

**데이터 품질 분포 (v3, 965곳)**:
- `complete` (18홀 완전 매핑): 3곳 (0.31%)
- `partial` (9홀 이상 매핑): 12곳
- `minimal` (1~8홀 매핑): 9곳
- `low` (클럽하우스 좌표만): 941곳

F3 GPS 자동 감지 — 골프장 + 서브코스 단위 (홀 단위 자동 감지는 미제공, 수동 진행).

---

## design-stitch/ — UI 시안

Google Stitch가 생성한 22화면 시안. 실제 앱 구현 시 `12-SCREENS.md §3`의 색상·폰트 교체 정책을 따른다 (Stitch Material You 보라 → 라운드온 Spring 그린).

| 위치 | 화면 수 | 설명 |
|------|--------|------|
| `screens/iphone/` | 10화면 | iPhone 주요 화면 PNG + HTML |
| `screens/watch/` | 7화면 | Apple Watch 화면 PNG + HTML |
| `screens/mobile-web/` | 5화면 | viewer 모바일 웹 PNG + HTML |

---

## claude/ — Claude Code 보조 문서

Claude Code 개발 세션에서 참조하는 도구·규칙 문서. 일반 개발자는 참조 불필요.

| 파일 | 설명 |
|------|------|
| [context-db.md](claude/context-db.md) | SQLite 기반 세션/태스크/결정 저장소 사용법 |
| [context-monitor.md](claude/context-monitor.md) | HUD + compaction 감지·복구 |
| [conventions.md](claude/conventions.md) | 커밋 컨벤션, 주석, 로깅 규칙 |
| [setup.md](claude/setup.md) | 새 환경 초기 설정 |

---

## 신규 사용자 읽기 순서

역할에 따라 다른 순서로 읽는다.

| 역할 | 권장 순서 |
|------|----------|
| PM / 기획자 | 00-OVERVIEW → 01-SPEC §0~§3 → 02-USER_FLOWS → 00-OVERVIEW §6 (Non-Goals) |
| 디자이너 | 12-SCREENS → 10-DESIGN_SYSTEM → 11-COMPONENTS → 13-HAPTICS_AND_MOTION → 14-ACCESSIBILITY |
| iOS 개발자 | 01-SPEC → 20-ARCHITECTURE → 21-DATA_MODEL → 22-STATE_MANAGEMENT → 23-OFFLINE_BEHAVIOR |
| 백엔드 개발자 | 30-API_SPEC → 32-CLOUDFLARE_SETUP → 33-SECURITY → 31-VIEWER_HTML |
| 법무 | 50-PRIVACY_POLICY → 53-PERMISSIONS → 33-SECURITY §4 |

---

*최종 업데이트: 2026-05-13*
