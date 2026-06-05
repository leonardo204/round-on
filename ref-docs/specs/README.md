# specs/ — 라운드온 설계 문서 카테고리 인덱스

> 이 디렉토리의 모든 문서는 라운드온(Round-On) 앱 기능 명세서 v4를 기반으로 작성된 사전 설계 문서다.
> 구현 단계에서 각 담당자가 단일 진실 공급원으로 사용한다.

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

## 00번대 — 제품 정의

앱의 정체성, 기능 목록 전체, 사용자 플로우를 정의한다. **모든 역할의 필독 섹션**.

| 파일 | 한 줄 설명 | 분량 |
|------|-----------|------|
| [00-OVERVIEW.md](00-OVERVIEW.md) | 제품 정체성·가치 제안·Non-Goals·제약사항 | ~140줄 |
| [01-SPEC.md](01-SPEC.md) | **마스터 기능 명세서 v4** — F1~F14 + 디자인 시스템 + 작업 분담 | ~1000줄 |
| [02-USER_FLOWS.md](02-USER_FLOWS.md) | F-A~F-G 골든패스, 권한 거부 분기, 플로우 다이어그램 | ~300줄 |

---

## 10번대 — 디자인 시스템

색상·타이포·컴포넌트·화면 매핑·햅틱·접근성. 디자이너와 iOS 개발자 필독.

| 파일 | 한 줄 설명 | 분량 |
|------|-----------|------|
| [10-DESIGN_SYSTEM.md](10-DESIGN_SYSTEM.md) | 4계절 컬러 토큰, 타이포그래피, 8pt 그리드, 다크모드 정책 | ~400줄 |
| [11-COMPONENTS.md](11-COMPONENTS.md) | 8+2종 컴포넌트 props/상태/변형, elevation 토큰 | ~500줄 |
| [12-SCREENS.md](12-SCREENS.md) | Stitch 시안 22화면 매핑, ScoreCell Variant B 채택, 색상·폰트 교체 정책 | ~500줄 |
| [13-HAPTICS_AND_MOTION.md](13-HAPTICS_AND_MOTION.md) | WKHapticType 이벤트 매핑, 모션 토큰 4종, Reduce Motion 처리 | ~200줄 |
| [14-ACCESSIBILITY.md](14-ACCESSIBILITY.md) | VoiceOver 4-tuple 레이블, Dynamic Type 스케일, WCAG AA 대비, par-diff 모양 매핑 | ~350줄 |

**핵심 결정사항** (12-SCREENS.md에서 확정):
- ScoreCell 변형: **Variant B** (`.split9x2` OUT/IN 2단) 채택
- 색상: Stitch Material You 보라 → 라운드온 Spring 그린 (`--green-primary`)
- 폰트: Stitch Hanken Grotesk → SF Pro Display + Pretendard

---

## 20번대 — 앱 아키텍처

시스템 구조, SwiftData 모델, 상태 관리, 오프라인 동작. **iOS 개발자 핵심 참조**.

| 파일 | 한 줄 설명 | 분량 |
|------|-----------|------|
| [20-ARCHITECTURE.md](20-ARCHITECTURE.md) | 컴포넌트/모듈/데이터 흐름, GolfCourse 방식 결정(@Model vs 번들 JSON) | ~400줄 |
| [21-DATA_MODEL.md](21-DATA_MODEL.md) | SwiftData @Model 4종, DataQuality enum 5종, GolfCourse 외부 데이터, CloudKit 매핑 | ~350줄 |
| [22-STATE_MANAGEMENT.md](22-STATE_MANAGEMENT.md) | @Observable ViewModel 5종, WatchConnectivity 메시지 3종, 카운터 delta-merge | ~400줄 |
| [23-OFFLINE_BEHAVIOR.md](23-OFFLINE_BEHAVIOR.md) | PendingOperation 큐, 지수 백오프, Viewer 만료 nil 처리 타이밍 | ~300줄 |

**DataQuality enum** (`low` 941곳 / `minimal` 9 / `partial` 12 / `complete` 3 / `unknown`) — 상세는 [21-DATA_MODEL.md §5](21-DATA_MODEL.md).

---

## 30번대 — 백엔드

Cloudflare Worker API, Viewer HTML, 인프라 셋업, 보안. **백엔드 개발자 핵심 참조**.

| 파일 | 한 줄 설명 | 분량 |
|------|-----------|------|
| [30-API_SPEC.md](30-API_SPEC.md) | Cloudflare Worker 7개 엔드포인트, 요청·응답 JSON 스키마 | ~500줄 |
| [31-VIEWER_HTML.md](31-VIEWER_HTML.md) | viewer HTML 구조, 사진 long-press 저장, PIN 잠금 화면 마크업 — DRAFT | ~600줄 |
| [32-CLOUDFLARE_SETUP.md](32-CLOUDFLARE_SETUP.md) | KV 4네임스페이스, R2 버킷, wrangler.toml 구성, 환경변수 | ~300줄 |
| [33-SECURITY.md](33-SECURITY.md) | bcrypt cost 12, PIN 5회 잠금, PII 마스킹, HMAC-SHA256 editToken | ~300줄 |

---

## 50번대 — 정책

App Store 제출 및 법적 요건. 배포 직전 법적 검수 필요.

| 파일 | 한 줄 설명 | 분량 |
|------|-----------|------|
| [50-PRIVACY_POLICY.md](50-PRIVACY_POLICY.md) | 개인정보 처리방침 (PIPA §30) + App Store Privacy Nutrition Label — **DRAFT, 법적 검수 필요** | ~400줄 |
| [53-PERMISSIONS.md](53-PERMISSIONS.md) | Info.plist 권한 키 6종, usage string 한/영, 요청 시점 UX — **DRAFT, TODO 5개** | ~250줄 |

---

## 읽기 권장 순서 (역할별)

| 역할 | 읽을 문서 (순서대로) |
|------|---------------------|
| PM / 기획자 | 00-OVERVIEW → 01-SPEC §0~§3 → 02-USER_FLOWS |
| 디자이너 | 12-SCREENS → 10-DESIGN_SYSTEM → 11-COMPONENTS → 13-HAPTICS_AND_MOTION → 14-ACCESSIBILITY |
| iOS 개발자 | 01-SPEC → 20-ARCHITECTURE → 21-DATA_MODEL → 22-STATE_MANAGEMENT → 23-OFFLINE_BEHAVIOR |
| 백엔드 개발자 | 30-API_SPEC → 32-CLOUDFLARE_SETUP → 33-SECURITY → 31-VIEWER_HTML |
| 법무 | 50-PRIVACY_POLICY → 53-PERMISSIONS → 33-SECURITY §4 |

---

*최종 업데이트: 2026-05-13*
