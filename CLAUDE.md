# Claude Code 개발 가이드

> 공통 규칙(Agent Delegation, 커밋 정책, Context DB 등)은 글로벌 설정(`~/.claude/CLAUDE.md`)을 따릅니다.
> 글로벌 미설치 시: `curl -fsSL https://raw.githubusercontent.com/leonardo204/dotclaude/main/install.sh | bash`

---

## Slim 정책

이 파일은 **100줄 이하**를 유지한다. 새 지침 추가 시:
1. 매 턴 참조 필요 → 이 파일에 1줄 추가
2. 상세/예시/테이블 → Ref-docs/claude/*.md에 작성 후 여기서 참조
3. ref-docs 헤더: `# 제목 — 한 줄 설명` (모델이 첫 줄만 보고 필요 여부 판단)

---

## PROJECT

### 개요

**라운드온 (Round-On)** — iPhone + Apple Watch 골프 스코어 카운터 앱

| 항목 | 값 |
|------|-----|
| 앱 이름 | 라운드온 (Round-On) — 2026-05-11 확정 |
| 컨셉 | "한 번 탭할 때마다 한 타. 라운드 끝나면 사진과 함께 친구들에게 공유." |
| 기술 스택 | iOS 17+ / watchOS 10+, SwiftUI, SwiftData, CloudKit, HealthKit, WatchConnectivity, Cloudflare Workers + KV + R2 |
| 빌드 방법 | Xcode 워크스페이스 (iOS + watchOS + Shared) — TBD |
| Viewer 도메인 | `golf.zerolive.co.kr` (7일 만료 라운드 viewer URL) |
| 상태 | 기획/명세 단계 (v4) — 단일 Phase 개발 예정 |

### 상세 문서

#### 프로젝트 명세
- [기능 명세서 v4](Ref-docs/golf-scorecard-app-spec_3.md) — F1~F14 전체 기능 + 디자인 시스템 + 작업 분담
- [한국 골프장 DB 패키지](Ref-docs/golf-db-pack/README.md) — 1,163곳 골프장 데이터셋 (v3, 2026-05-12 빌드, OSM/ODbL)
- [DB 스키마](Ref-docs/golf-db-pack/40-COURSE_DB_SCHEMA.md) — JSON 스키마 + Swift `CourseRepository` 예시
- [DB 파이프라인](Ref-docs/golf-db-pack/41-COURSE_DB_PIPELINE.md) — 데이터 수집·빌드 과정

#### 사전 설계 문서 (specs/)
- [00 제품 개요](Ref-docs/specs/00-OVERVIEW.md) — 정체성, 가치 제안, Non-Goals
- [02 사용자 플로우](Ref-docs/specs/02-USER_FLOWS.md) — F-A~F-G 7개 골든패스
- [10 디자인 시스템](Ref-docs/specs/10-DESIGN_SYSTEM.md) — 4계절 컬러 토큰, 타이포, 8pt 그리드
- [11 컴포넌트 카탈로그](Ref-docs/specs/11-COMPONENTS.md) — 컴포넌트 8+2종 props/상태/변형, elevation 토큰
- [12 화면 카탈로그](Ref-docs/specs/12-SCREENS.md) — Stitch 시안 22화면 매핑, ScoreCell Variant B 채택, 색상/폰트 교체 정책
- [13 햅틱 및 모션](Ref-docs/specs/13-HAPTICS_AND_MOTION.md) — WKHapticType 매핑, 모션 토큰 4종
- [14 접근성](Ref-docs/specs/14-ACCESSIBILITY.md) — VoiceOver 4-tuple, Dynamic Type 스케일, WCAG AA 대비, par-diff 모양 매핑, Reduce Motion
- [20 전체 아키텍처](Ref-docs/specs/20-ARCHITECTURE.md) — 컴포넌트/모듈/데이터 흐름, GolfCourse·iCloud 결정
- [21 데이터 모델](Ref-docs/specs/21-DATA_MODEL.md) — SwiftData @Model + CloudKit
- [22 상태 관리](Ref-docs/specs/22-STATE_MANAGEMENT.md) — @Observable VM 5종, WC 메시지 3종, 카운터 delta-merge
- [23 오프라인 동작](Ref-docs/specs/23-OFFLINE_BEHAVIOR.md) — PendingOperation 큐, 백오프, viewer 만료 nil
- [30 API 명세](Ref-docs/specs/30-API_SPEC.md) — Cloudflare Worker 7개 엔드포인트
- [31 Viewer HTML](Ref-docs/specs/31-VIEWER_HTML.md) — 모바일 우선 + 사진 long-press 저장
- [32 Cloudflare 셋업](Ref-docs/specs/32-CLOUDFLARE_SETUP.md) — KV 4네임스페이스, R2 버킷, wrangler.toml
- [33 보안 정책](Ref-docs/specs/33-SECURITY.md) — bcrypt 12, PIN 검증 EP, PII 마스킹
- [50 개인정보 처리방침](Ref-docs/specs/50-PRIVACY_POLICY.md) — PIPA §30, App Store Privacy Nutrition Label
- [53 권한 요청](Ref-docs/specs/53-PERMISSIONS.md) — Info.plist 키, usage string 한/영

#### 개발 환경 빌드 (구현 단계)
- 정식 타깃: `RoundOn` 스킴 (Bundle ID `kr.zerolive.golf.roundon`, Watch 임베드 — watchOS 시뮬레이터 설치 환경)
- 개발용 타깃: `RoundOn-iOS` 스킴 (Bundle ID `kr.zerolive.golf.roundon.dev`, Watch 미임베드 — watchOS 시뮬레이터 없는 환경)
- 일상 개발: `xcodebuild -scheme RoundOn-iOS` (빠른 iOS 단독 빌드)
- 정식 빌드/Archive: `xcodebuild -scheme RoundOn` (Watch 시뮬레이터 필요)

#### 디자인 시안 (design-stitch/)
- [Stitch 프롬프트 모음](Ref-docs/design-stitch/stitch-prompt.md) — Google Stitch 작업 프롬프트 v2 + 인계 가이드
- [시안 산출물](Ref-docs/design-stitch/screens/) — iPhone 10화면 / Watch 7화면 / Mobile-Web 5화면 PNG + HTML
- 색상 교체 정책: Stitch Material You 보라 → 라운드온 Spring 그린 (`12-SCREENS.md §3` 참조)

#### Claude Code 시스템
- [Context DB](Ref-docs/claude/context-db.md) — SQLite 기반 세션/태스크/결정 저장소
- [Context Monitor](Ref-docs/claude/context-monitor.md) — HUD + compaction 감지/복구
- [컨벤션](Ref-docs/claude/conventions.md) — 커밋, 주석, 로깅 규칙
- [셋업](Ref-docs/claude/setup.md) — 새 환경 초기 설정

### 핵심 규칙

- **디자인 톤**: "사계절 그린" 4팔레트 (Spring 라이트 / Winter 다크 디폴트), 절제·미니멀, 8pt 그리드
- **F4 카운터 컨셉**: par에서 시작 X — **0에서 시작, 샷마다 +1** (OB +2, 해저드 +1, OK +1)
- **개인정보**: 위치/동반자 이름 외부 전송 금지. viewer는 7일 후 KV/R2 자동 삭제
- **DB 라이선스**: 골프장 데이터는 OSM ODbL — 앱 내 표기 필수 (설정 → 정보)
- **DB 품질 분기**: 한국 골프장 DB v3 (1,163곳, 2026-05-12 빌드) — 1,163곳 중 1,139곳 `low`. F3 GPS 자동 감지 — 골프장 + 서브코스 단위 (홀 단위 자동 감지는 미제공, 수동 진행) — 모든 코스에서 골프장 단위 감지 가능. complete 3곳 (전체의 0.26%). dataQuality 기반 분기 처리 필수
- **글로벌 출시 시 재고**: 영어 "round on"은 부정 의미("공격하다") — 영어권 진출 시 별도 브랜드 검토

---

*최종 업데이트: 2026-05-12*
