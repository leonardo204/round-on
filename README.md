# 라운드온 (Round-On)

> **"한 번 탭할 때마다 한 타. 라운드 끝나면 사진과 함께 친구들에게 공유."**

iPhone + Apple Watch 기반의 간결한 골프 스코어 카운터 앱. 한국 골프장 965곳 자동 매칭, Watch Digital Crown 카운팅, 7일 만료 모바일 viewer 링크 공유 세 가지에 집중한다.

| 항목 | 값 |
|------|-----|
| 한국어 명칭 | 라운드온 |
| 영문 명칭 | Round-On |
| 확정일 | 2026-05-11 |
| 플랫폼 | iOS 17+ / watchOS 10+ |
| Viewer 도메인 | `golf.zerolive.co.kr` |
| 저장소 | github.com/leonardo204/round-on |

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

## 빠른 시작

### iOS 앱 빌드

```bash
# XcodeGen으로 프로젝트 재생성
xcodegen generate

# 개발용 (Watch 시뮬레이터 불필요)
xcodebuild -scheme RoundOn-iOS \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro,OS=17.0" \
  build

# 정식 빌드 (Watch 시뮬레이터 필요)
xcodebuild -scheme RoundOn build
```

**Bundle ID**:
- 개발용: `kr.zerolive.golf.roundon.dev`
- 정식: `kr.zerolive.golf.roundon`
- Team ID: `XU8HS9JUTS`

### 카카오 API 키 설정 (개발 환경)

GPS로 매칭된 골프장을 카카오 로컬 API로 재검증하는 기능 (F3)에 카카오 REST API 키가 필요하다.
키가 없으면 GPS 단독 매칭만 동작하고 카카오 검증은 `.unavailable`로 스킵된다.

**방법 1: `.api-keys.local` 파일 (개발 환경 권장)**

```
# .api-keys.local (프로젝트 루트, .gitignore됨)
KAKAO_REST_API_KEY=여기에_키_입력
```

시뮬레이터 실행 시 앱이 자동으로 이 파일에서 키를 읽는다.

**방법 2: Secrets.xcconfig → Info.plist 주입 (배포 환경)**

1. `Secrets.xcconfig` 파일에 키 입력:
   ```
   KAKAO_REST_API_KEY = 여기에_키_입력
   ```
2. `xcodegen generate` 실행 — Info.plist에 `KAKAO_REST_API_KEY` 키가 자동 포함됨
3. 앱 실행 시 `Bundle.main.object(forInfoDictionaryKey: "KAKAO_REST_API_KEY")`로 읽힘

> **주의**: `Secrets.xcconfig`는 `.gitignore`에 포함됨. 절대 커밋 금지.
>
> 카카오 REST API 키 발급: https://developers.kakao.com → 애플리케이션 추가 → 앱 키 확인

---

### Cloudflare Worker 로컬 실행

```bash
cd Worker
npm install
wrangler dev
```

---

## 디렉토리 구조

```
golfCounter/
├── App-iOS/           — iPhone 앱 코드 (SwiftUI)
├── App-Watch/         — Apple Watch 앱 코드 (watchOS SwiftUI)
├── Shared/            — iOS + Watch 공용 (Models / ViewModels / Sync / DesignSystem)
├── Tests/             — XCTest 단위·통합 테스트
├── Worker/            — Cloudflare Worker 백엔드 (TypeScript)
├── scripts/           — 한국 골프장 DB 빌드 파이프라인 (Python)
├── Ref-docs/          — 명세·디자인·정책 문서 (모든 설계 결정의 근거)
│   ├── specs/         — 기능명세 + 설계 문서 18종
│   ├── golf-db-pack/  — 골프장 DB 스키마·파이프라인
│   ├── design-stitch/ — UI 시안 PNG + HTML (Stitch 생성)
│   └── claude/        — Claude Code 개발 보조 문서
├── project.yml        — XcodeGen 매니페스트
└── README.md          — 지금 이 파일
```

---

## 문서 진입점

| 문서 | 설명 |
|------|------|
| [Ref-docs/README.md](Ref-docs/README.md) | 모든 명세·설계 문서 인덱스 |
| [Ref-docs/specs/01-SPEC.md](Ref-docs/specs/01-SPEC.md) | 기능 명세서 v4 (F1~F14 전체) |
| [Ref-docs/specs/00-OVERVIEW.md](Ref-docs/specs/00-OVERVIEW.md) | 제품 개요·가치 제안·Non-Goals |
| [Ref-docs/specs/20-ARCHITECTURE.md](Ref-docs/specs/20-ARCHITECTURE.md) | 전체 아키텍처·모듈 구조 |
| [Ref-docs/specs/21-DATA_MODEL.md](Ref-docs/specs/21-DATA_MODEL.md) | SwiftData 모델 스키마 |
| [Ref-docs/specs/30-API_SPEC.md](Ref-docs/specs/30-API_SPEC.md) | Cloudflare Worker API 7개 엔드포인트 |
| [Ref-docs/golf-db-pack/README.md](Ref-docs/golf-db-pack/README.md) | 한국 골프장 DB v3 패키지 |
| [Worker/README.md](Worker/README.md) | Worker 배포 가이드 |

---

## 현재 상태 (2026-05-13 기준)

MVP 개발 중. 아래 항목이 미완이다.

| # | 항목 | 담당 |
|---|------|------|
| 1 | Cloudflare Worker 배포 (wrangler publish) | 백엔드 |
| 2 | App Store Connect 앱 등록 + TestFlight | iOS |
| 3 | `golf.zerolive.co.kr` DNS/Worker 라우트 활성화 | 인프라 |
| 4 | 50-PRIVACY_POLICY.md placeholder 6건 확정 | 법무 |
| 5 | App Store Privacy Nutrition Label 제출 | iOS |

---

## 기술 스택 요약

| 레이어 | 기술 |
|--------|------|
| iOS 앱 | SwiftUI, SwiftData, CloudKit, HealthKit, WatchConnectivity |
| Watch 앱 | watchOS SwiftUI, Digital Crown API, WKHapticFeedbackGenerator |
| 백엔드 | Cloudflare Workers (TypeScript), KV, R2 |
| 골프장 DB | OpenStreetMap (ODbL) + 공공데이터 + 카카오 enrichment |
| 빌드 도구 | XcodeGen, xcodebuild, wrangler, Python 3 (DB 파이프라인) |

---

## 라이선스

- **앱 코드**: 저작권 보유 (zerolive.co.kr)
- **한국 골프장 데이터**: OpenStreetMap 기여자, ODbL 1.0

ODbL 라이선스 표기 의무 — 앱 내 **설정 → 정보 → 사용된 오픈소스/데이터**에 아래를 표기해야 한다:

```
© OpenStreetMap contributors, ODbL 1.0
https://www.openstreetmap.org/copyright
```

---

*최종 업데이트: 2026-05-13*
