# 20 — 전체 아키텍처 (Architecture)

> **관련 문서**: [01-SPEC](01-SPEC.md) · [21-DATA_MODEL](21-DATA_MODEL.md) · [22-STATE_MANAGEMENT](22-STATE_MANAGEMENT.md) · [23-OFFLINE_BEHAVIOR](23-OFFLINE_BEHAVIOR.md) · [30-API_SPEC](30-API_SPEC.md) · [전체 인덱스](README.md)

> **작성일**: 2026-05-11
> **버전**: v4 기반
> **출처 명세서**: [기능 명세서 v4](01-SPEC.md) §3 (222-284), §6, §F7 (112-114), §F8 (116-119), §11 (843-902)
> **관련 문서**: `21-DATA_MODEL.md`, `22-STATE_MANAGEMENT.md`, `23-OFFLINE_BEHAVIOR.md`, `30-API_SPEC.md`, `31-VIEWER_HTML.md`, `32-CLOUDFLARE_SETUP.md`, `53-PERMISSIONS.md`

---

## 1. 개요

라운드온(Round-On)은 **iPhone 앱 + Apple Watch 앱 + Cloudflare Worker 백엔드** 세 축으로 구성되며, 본 문서는 이 세 축 간의 데이터 흐름, 모듈 분리, 계층 구조, 핵심 아키텍처 결정을 정의한다. (CLAUDE.md §PROJECT), (01-SPEC.md §11)

### 본 문서 책임 vs 위임

| 범위 | 본 문서 | 위임 문서 |
|------|---------|----------|
| 시스템 컴포넌트 전체 그림 | 담당 | — |
| 데이터 흐름 3개 시나리오 | 담당 | — |
| iOS 앱 계층 구조 | 담당 | — |
| 모듈 분리 (3타깃) | 담당 | — |
| GolfCourse 적재 방식 결정 | 담당 (21-DATA_MODEL §5 위임 수신) | — |
| iCloud 미로그인 동작 결정 | 담당 (53-PERMISSIONS §7 위임 수신) | — |
| SwiftData @Model 스키마 | — | `21-DATA_MODEL.md` |
| ViewModel 상태 / WatchConnectivity 알고리즘 | — | `22-STATE_MANAGEMENT.md` |
| 오프라인 큐 / CloudKit 충돌 해결 | — | `23-OFFLINE_BEHAVIOR.md` |
| Worker API 계약 | — | `30-API_SPEC.md` |
| Cloudflare 설정 (wrangler.toml, TTL) | — | `32-CLOUDFLARE_SETUP.md` |
| Info.plist 권한 키 | — | `53-PERMISSIONS.md` |

---

## 2. 시스템 컴포넌트 다이어그램

내부 구현 컴포넌트는 실선(`┌────`), 외부 의존은 점선(`┌─ ─ ─`), 앱 번들 정적 리소스는 실선 + 본문 표기로 구분한다.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    [라운드온 앱 — 자체 구현]                          │
│                                                                      │
│  ┌──────────────────┐         ┌──────────────────┐                   │
│  │   iOS 앱 (App)   │ ◄─WC───►│   Watch 앱        │                   │
│  │   SwiftUI        │         │   SwiftUI        │                   │
│  │   ViewModels     │         │   HealthKit*     │                   │
│  └────────┬─────────┘         └────────┬─────────┘                   │
│           │                            │                             │
│           └─────────────┬──────────────┘                             │
│                         ▼                                            │
│            ┌────────────────────────┐                                │
│            │   Shared (3rd target)  │                                │
│            │   @Model + Tokens      │                                │
│            │   Repository 프로토콜   │                                │
│            │   SyncCoordinator §9   │                                │
│            └───────────┬────────────┘                                │
│                        │                                             │
└────────────────────────┼─────────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────────────────────┐
         │               ▼                               │
         │    ┌────────────────────┐                     │
         │    │ SwiftData (local)  │                     │
         │    └─────────┬──────────┘                     │
         │              │ auto-sync (iOS 17)              │
         │  ┌─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐        │
         │  ┊  CloudKit private DB              ┊        │
         │  ┊  (외부 의존 — iCloud 계정 필요)     ┊        │
         │  └─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘        │
         │                                               │
         │  ┌─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐   │
         │  ┊  HealthKit (디바이스 로컬, 외부 의존)    ┊   │
         │  ┊  HKWorkoutActivityType.golf              ┊   │
         │  └─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘   │
         │                                               │
         │  ┌─────────────────────────────────────────┐   │
         │  │  번들 courses.json (약 727KB, 정적 리소스) │   │
         │  │  CourseRepository 인메모리 로드           │   │
         │  │  한국 골프장 DB v3 (965곳, OSM ODbL)    │   │
         │  └─────────────────────────────────────────┘   │
         └───────────────────────────────────────────────┘

라운드 종료 후 viewer 공유 (Cloudflare 측, 외부):
┌─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
║  ┌──────────────────────────────┐                                    ║
║  │  Cloudflare Worker           │ ── 30-API_SPEC                     ║
║  │  (golf.zerolive.co.kr)       │                                    ║
║  └──────────┬───────────────────┘                                    ║
║             │                                                        ║
║     ┌───────┴───────┐                                                ║
║     ▼               ▼                                                ║
║  ┌──────┐       ┌───────┐                                            ║
║  │  KV  │       │  R2   │                                            ║
║  │ 메타  │       │ 사진  │                                            ║
║  └──────┘       └───────┘                                            ║
║  (모두 7일 TTL — 01-SPEC.md:248-250)                                   ║
└─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
```

출처: (01-SPEC.md:222-284), (01-SPEC.md §6), (01-SPEC.md §F7-F8)

---

## 3. 데이터 흐름 (3개 시나리오)

### 3.1 라운드 시작 → 진행 (로컬 우선)

spec §11 Step 9 (01-SPEC.md:871-872) 매핑: "SwiftData ↔ CloudKit 자동 sync, 미완료 라운드 복구"

1. 사용자가 F-B (라운드 시작) 탭 → `Round` / `Player` / `HoleScore` SwiftData write
2. iOS 17 SwiftData가 CloudKit private DB로 백그라운드 자동 sync
   - 명세 근거: 01-SPEC.md:112-114 "CloudKit으로 라운드 기록 자동 동기화. 로컬 우선, 네트워크 복구 시 자동 sync"
3. 네트워크 단절 시 로컬 SwiftData만 활성, 연결 복구 시 자동 sync 재개 (01-SPEC.md:114)
4. 앱 강제 종료 후 재실행 시 진행 중 라운드 자동 복구 (01-SPEC.md:108-109)

충돌 해결 알고리즘 및 오프라인 큐 상세는 `23-OFFLINE_BEHAVIOR.md` (작성 예정) 위임.

**라운드 진행 중 저장 타이밍**: HoleScore는 탭 인터랙션 직후 SwiftData에 즉시 write한다. 별도 "저장" 버튼 없이 매 탭마다 영속화되므로, 앱 강제 종료 시에도 마지막 탭까지 보존된다 (01-SPEC.md:108-109).

### 3.2 Watch ↔ iPhone 점수 sync

spec §11 Step 7 (01-SPEC.md:866) 매핑: "iPhone ↔ Watch 점수 sync, 라운드 상태 sync, 충돌 처리"

```
Watch 카운터 +1
    │
    ▼
WatchConnectivity 메시지 (WCSession)
    │
    ▼
iPhone SyncCoordinator (§9 참조)
    │
    ▼
SwiftData write (HoleScore 갱신)
    │
    ▼
4×18 그리드 UI 갱신 (@Observable)
```

WCSession 메시지 종류(sendMessage / transferUserInfo 분기), 충돌 해결 알고리즘은 `22-STATE_MANAGEMENT.md` (작성 예정) 위임. 본 절은 데이터 흐름 화살표만 다룬다.

**Watch 단독 진입점**: Watch에서 OB/해저드/OK 페널티도 동일 흐름으로 처리한다. Watch UI의 페널티 버튼 탭 → WCSession 메시지(페널티 종류 포함) → SyncCoordinator → SwiftData write. 페널티 종류별 메시지 스키마는 `22-STATE_MANAGEMENT.md` 위임.

**HealthKit 워크아웃 경로**: Watch 앱이 `HKWorkoutSession`을 시작/종료하며, 걸음 수/칼로리/심박수는 HealthKit 로컬 DB에만 기록된다 (01-SPEC.md:116-119). HealthKit 데이터는 SwiftData를 경유하지 않는다.

### 3.3 라운드 종료 → viewer 생성

spec §11 Step 12 (01-SPEC.md:880-887) 매핑: "Cloudflare Worker + KV + R2 (Viewer 백엔드)"

1. F-D 라운드 종료 → F-E 공유 옵션 모달 (실명/익명, 공개/PIN 선택)
2. POST `/api/share` 호출 — 라운드 데이터 + 사진 + 옵션 + 디바이스 토큰 (30-API_SPEC §3)
3. Worker가 shortId(base62 8자) 발급, KV(메타데이터) + R2(사진) write, 7일 TTL 설정 (01-SPEC.md:248-250)
4. `{ shortId, url, editToken, expiresAt }` 반환 → Round 모델의 `sharedShortId` / `sharedURL` / `sharedExpiresAt` / `sharedEditToken` 4개 필드에 저장 (21-DATA_MODEL §8)
5. iOS 시스템 공유 시트로 URL 전달

API 요청/응답 스키마 상세는 `30-API_SPEC.md`, KV/R2 바인딩 설정은 `32-CLOUDFLARE_SETUP.md` (작성 예정) 위임.

**7일 TTL 만료 처리**: Cloudflare KV/R2가 7일 후 자동 삭제되면, 앱이 다음 실행 시 `sharedExpiresAt` 필드를 확인하여 만료된 경우 4개 공유 필드를 nil로 초기화한다. nil 처리 트리거 시점(앱 재실행 / 백그라운드 태스크)은 `23-OFFLINE_BEHAVIOR.md` 위임 (21-DATA_MODEL §8).

**사진 업로드 경로**: 라운드 사진은 POST `/api/share` 본문에 직접 첨부하거나 POST `/api/share/{shortId}/photos`로 추가할 수 있다. 1장당 최대 10MB, viewer당 최대 30장 (01-SPEC.md:279-280). 업로드 실패 시 재시도 정책은 `23-OFFLINE_BEHAVIOR.md` 위임.

---

## 4. iOS 앱 계층 구조

### 계층 정의

| 계층 | 구성 요소 | 역할 |
|------|----------|------|
| **Views (SwiftUI)** | 각 화면 View 파일 | 화면 렌더링만, 상태는 ViewModel에서 수신 |
| **ViewModels (`@Observable`)** | `RoundViewModel`, `CourseViewModel` 등 | 상태 보유 및 사용자 인터랙션 처리 |
| **Repositories** | `CourseRepository`, `RoundRepository`, `ShareAPIClient` | 데이터 접근 추상화 |
| **SwiftData Stack** | `ModelContainer`, `ModelContext` | 영속 저장소 |
| **Network Layer** | URLSession + Worker API | Cloudflare Worker 통신 |

### 의존 방향 (단방향)

```
Views
  │
  ▼
ViewModels (@Observable)
  │
  ▼
Repositories
  │
  ├──► SwiftData Stack (로컬 영속)
  └──► Network Layer (Worker API 통신)
```

Views가 Repository를 직접 호출하지 않는다. 이를 통해 ViewModel을 Mock Repository로 테스트 가능한 구조를 확보한다.

### Watch 앱 계층 구조

Watch 앱은 iPhone 앱보다 단순하며, ViewModel 계층을 두되 Repository는 WatchConnectivity를 통해 iPhone에 위임하는 방식을 권장한다.

```
Watch Views (SwiftUI)
    │
    ▼
Watch ViewModels (@Observable)
    │
    ▼
WatchConnectivity Client ──► iPhone (SyncCoordinator → SwiftData)
    │
    └──► HealthKit (로컬 write, iPhone 무관)
```

Watch 앱이 독자 SwiftData ModelContainer를 보유할지 여부는 §10 미정 항목 5번 참조.

ViewModels 상태 상세(`@Observable` 구현, 라운드 진행 중 메모리 상태)는 `22-STATE_MANAGEMENT.md` (작성 예정) 위임.

---

## 5. 모듈 분리 (Xcode 워크스페이스)

spec §11 Step 1 (01-SPEC.md:847-852)에 따라 **3타깃**으로 구성한다. 빌드 시스템은 **XcodeGen** (`project.yml` → `RoundOn.xcodeproj`)을 사용하며, `courses.json` 번들 리소스는 `project.yml`의 `resources:` 섹션에 등록한다.

| 타깃 | 역할 | 출처 |
|------|------|------|
| **iOS 앱 (App-iOS)** | iPhone UI (SwiftUI Views), ViewModels, Repository 구현체, WatchConnectivity 클라이언트 | 01-SPEC.md:848 |
| **watchOS 앱 (App-Watch)** | Apple Watch UI (SwiftUI Views), HealthKit 워크아웃 세션, Digital Crown 카운터 | 01-SPEC.md:849 |
| **Shared** | SwiftData `@Model` 클래스, 디자인 토큰, DTO 타입, Repository 프로토콜 정의 | 01-SPEC.md:850 |

3타깃 구조는 spec §11 Step 1 그대로 유지한다. Core를 별도 타깃으로 분리하는 안은 §9 구현 제안 참조.

### 타깃 간 의존 관계

```
App-iOS ──► Shared
App-Watch ──► Shared
App-iOS ◄──/──► App-Watch  (직접 의존 없음 — WatchConnectivity 런타임 통신)
```

- `App-iOS`와 `App-Watch`는 서로 직접 import하지 않는다.
- `Shared`는 Foundation/SwiftData/SwiftUI(최소)만 import — UIKit/WatchKit 의존 없음.
- Watch-only 타입(WKInterfaceController 등)은 `App-Watch`에만 위치한다.

### OSM 데이터 표기 의무

`Shared` 타깃에 포함된 `courses.json`은 OSM ODbL 라이선스 데이터다. 앱 설정 → 정보 화면에 저작권 표기가 필수이다 (CLAUDE.md §PROJECT).

---

## 6. GolfCourse 적재 방식 [결정: 옵션 A]

21-DATA_MODEL §5에서 본 문서로 위임됨.

**결정**: **옵션 A — 번들 JSON 인메모리 `CourseRepository`**

앱 번들에 포함된 `courses.json`을 앱 시작 시 `CourseRepository`가 메모리 배열로 디코딩하여 보유한다. SwiftData `@Model`로 적재하지 않는다.

### 근거 (5개)

| # | 근거 | 출처 |
|---|------|------|
| 1 | `courses.json` 약 727KB — 앱 시작 시 1회 디코딩 후 메모리 배열로 충분, 쿼리 성능 문제 없음 (한국 골프장 DB v3 965곳) | ref-docs/golf-db-pack/ |
| 2 | 골프장 데이터는 앱 업데이트로만 갱신 — 사용자 생성/수정 데이터 없음, SwiftData 쓰기 불필요 | golf-db-pack/README.md |
| 3 | 01-SPEC.md:112 "CloudKit으로 라운드 기록 자동 동기화" — CloudKit 동기화 대상은 사용자 라운드 기록만, Course는 sync 대상 아님 | 01-SPEC.md:112 |
| 4 | Haversine 반경 3km 매칭(F1)은 965개 × O(1) 거리 계산으로 단일 호출당 1ms 미만 — 메모리 배열 선형 탐색 충분 | 01-SPEC.md:58-61 |
| 5 | SwiftData `@Model` + CloudKit 컨테이너 구성 시 모든 `@Model`은 기본적으로 sync 대상이 됨 — GolfCourse가 불필요하게 CloudKit private DB로 sync 시도 + 첫 실행 마이그레이션 비용 | 아키텍처 분석 |

**옵션 B (SwiftData @Model 적재) 기각**: 근거 3 및 5에 따라 기각.

`dataQuality` 기반 F3 분기 처리 (941개 `low` / complete 3 / partial 12 / minimal 9) — F3 GPS 자동 감지 — 골프장 + 서브코스 단위 (홀 단위 자동 감지는 미제공, 수동 진행) — 는 `21-DATA_MODEL.md` 위임.

---

## 7. iCloud 미로그인 시 동작 [결정: 정상 동작 + 배너]

53-PERMISSIONS §7에서 본 문서로 위임됨.

**결정**: 앱은 정상 동작하되, 설정 화면 상단에 비방해적 배너를 표시한다.

### 결정 상세

- **정상 동작 근거**: 01-SPEC.md:114 "로컬 우선, 네트워크 복구 시 자동 sync" 원칙과 일치. iCloud 미로그인 상태에서도 라운드 시작/저장/종료는 차단하지 않는다.
- **설정 화면 상단 배너**: "iCloud 미연결 — 다른 기기와 동기화되지 않습니다"
  - 배너 표시는 **spec 외 추가**: 53-PERMISSIONS §7 위임 결과이며, `01-SPEC.md` 원문에는 배너 명시 없음.
- **인앱 다이얼로그/강제 로그인 유도 금지**: 개인정보 톤 (CLAUDE.md §PROJECT — "위치/동반자 이름 외부 전송 금지")과 일치하는 비강제 정책. 사용자에게 계정 행동을 강요하지 않는다.
- **viewer 공유**: 디바이스 토큰 기반(01-SPEC.md:670)이므로 iCloud 로그인 여부와 무관하게 동작.
- **복구 시**: iCloud 연결 복구 시 로컬 SwiftData를 자동 merge. 충돌 해소 정책은 `23-OFFLINE_BEHAVIOR.md` 위임.

---

## 8. 책임 경계 표

| 문서 | 담당 영역 | 상태 |
|------|----------|------|
| **본 문서 (20-ARCHITECTURE)** | 시스템 컴포넌트, 데이터 흐름, 계층, 모듈, 핵심 결정 (GolfCourse/iCloud) | 작성 완료 |
| `21-DATA_MODEL.md` | SwiftData `@Model` 필드, 값 타입, 와이어 스키마 | 작성 완료 |
| `22-STATE_MANAGEMENT.md` | `@Observable` ViewModel, WatchConnectivity sync 알고리즘, 충돌 해결 | 작성 예정 |
| `23-OFFLINE_BEHAVIOR.md` | 네트워크 단절 큐잉, 재시도 백오프, CloudKit 충돌 | 작성 예정 |
| `30-API_SPEC.md` | Worker API 계약 (요청/응답/에러 스키마) | 작성 완료 |
| `31-VIEWER_HTML.md` | Viewer HTML 마크업, PIN 입력 화면 | 작성 완료 |
| `32-CLOUDFLARE_SETUP.md` | KV/R2 바인딩, wrangler.toml, TTL 적용 | 작성 예정 |
| `33-SECURITY.md` | bcrypt cost, PIN 잠금 키, PII 패턴 매칭 | 작성 예정 |
| `53-PERMISSIONS.md` | Info.plist 키, usage string, 권한 거부 fallback | 작성 완료 |

---

## 9. 구현 제안 (spec 외)

본 섹션은 `01-SPEC.md`에 없는 구현 권장안이며, 실제 결정은 구현 단계에서 확정. 본 문서가 명세화하지 않는다. 미채택 시 영향 없음.

### Shared 타깃 내부 `Core/` 폴더 격리 권장

`Shared` 타깃 내부에 `Core/` 폴더를 두어 도메인 로직(Repository 프로토콜, SyncCoordinator, 비즈니스 규칙)을 Views/ViewModels 코드와 물리적으로 격리할 것을 권장한다.

- spec §11 Step 1의 3타깃 구조를 유지한다 — `Core`를 별도 Xcode 타깃(프레임워크)으로 분리하지 않는다.
- 폴더 구조 예시:
  ```
  Shared/
    Core/
      Repositories/         ← 프로토콜 정의
      SyncCoordinator/      ← actor (아래 참조)
      Models/               ← SwiftData @Model
    DesignSystem/           ← 컬러 토큰, 타이포
    DTOs/                   ← Viewer 페이로드 DTO
  ```

### `SyncCoordinator` actor 도입 권장

Swift Concurrency `actor`로 WatchConnectivity 수신과 SwiftData write를 단일 진입점에 직렬화한다. 동시 쓰기 충돌(Watch와 iPhone이 같은 HoleScore를 동시 갱신)을 actor isolation으로 방지한다.

- 채택 시: `Shared/Core/SyncCoordinator/` 하위에 배치, iOS 앱과 Watch 앱 양쪽에서 import.
- 미채택 시: `22-STATE_MANAGEMENT.md`에서 대안 설계 결정.

### Repository 프로토콜 + Mock 구현

`Shared/Core/Repositories/`에 `CourseRepositoryProtocol`, `RoundRepositoryProtocol` 정의. iOS 앱과 Watch 앱은 구현체를 사용하고, 단위 테스트는 Mock 구현체를 주입한다.

- 의존성 주입 방식(initializer injection vs EnvironmentValues)은 구현 단계에서 결정.
- 테스트 커버리지 목표는 01-SPEC.md §11 Step 17 (01-SPEC.md:899-900) 참조.

---

## 10. [SPEC-UNDEFINED] 미정 항목

01-SPEC.md에 명시되지 않아 구현 단계에서 별도 결정이 필요한 항목이다.

1. **CloudKit zone 분리 정책**: default zone 사용 시 Round/Player/HoleScore가 단일 zone에 혼재. custom zone 사용 시 라운드 단위 삭제 지원 가능. zone 설계 기준 미정.
2. **Watch 앱 단독 실행 시 viewer 공유 가능 여부**: iPhone 미연결(Airplane Mode 또는 Watch-only) 상태에서 라운드 종료 후 공유 버튼 노출 여부 및 처리 방식 미정.
3. **모듈 간 Swift Concurrency boundary**: iOS 앱 MainActor 격리 경계와 Shared `actor` 간 데이터 전달 시 sendable 요건 정의 미정.
4. **iOS 18+ SwiftData 마이그레이션 정책**: iOS 18에서 SwiftData API 변경 또는 스키마 버전 업 시 마이그레이션 플랜 미정 (`VersionedSchema` 사용 여부 포함).
5. **Watch 앱 SwiftData 독립 저장 여부**: Watch 앱이 독자 ModelContainer를 보유할지, iPhone에서만 SwiftData write가 발생할지 미정.

### 부록: 후속 보완 TODO

- `22-STATE_MANAGEMENT.md` 작성 시 본 문서 §3.2 데이터 흐름 화살표를 참조하여 WCSession 메시지 타입 및 충돌 해결 알고리즘 상세화 필요.
- `23-OFFLINE_BEHAVIOR.md` 작성 시 본 문서 §3.1 오프라인 시나리오를 기반으로 큐 정책 설계 필요.
- `32-CLOUDFLARE_SETUP.md` 작성 시 본 문서 §3.3 viewer 생성 흐름을 참조하여 KV/R2 TTL 설정, wrangler.toml 작성 필요.

---

*최종 업데이트: 2026-05-11*
