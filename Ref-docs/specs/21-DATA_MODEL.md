# 21 — 데이터 모델 (Data Model)

> **작성일**: 2026-05-11
> **버전**: v4 기반
> **출처 명세서**: [기능 명세서 v4](../golf-scorecard-app-spec_3.md) §6 (spec_3.md:486-560)

---

## 1. 목적 / 범위

본 문서는 라운드온 앱의 **SwiftData 영속 모델** (스키마) 을 명세한다. 다루는 영역은 `@Model` 클래스 정의, 필드 타입, 값 타입(struct), Course 데이터 경계, CloudKit 매핑 원칙이다.

다루지 않는 영역: 라운드 진행 중 메모리 상태(`@Observable`) → `22-STATE_MANAGEMENT.md`(작성 예정) / 오프라인 큐·CloudKit 충돌 해결 → `23-OFFLINE_BEHAVIOR.md`(작성 예정) / Viewer 페이로드 직렬화 → `30-API_SPEC.md`(본 시리즈 #5).

출처: spec_3.md §6 (486-560), CLAUDE.md §PROJECT.

---

## 2. 모델 개요 다이어그램

아래 다이어그램은 spec_3.md:486-560에서 직접 도출한 모델 간 참조 관계다.

```
┌─────────────────────────────────────────────────────────┐
│                        Round                            │
│  id / date / courseId ──────────────► GolfCourse        │
│  courseName / courseSubName?          (id: String)      │
│  startedAt / finishedAt?              (번들 JSON 또는    │
│  isFinished / totalScore              @Model, §5 참조)  │
│  sharedShortId? / sharedURL?                            │
│  sharedExpiresAt? / sharedEditToken?                    │
│  sharedOptions?: ShareOptions                           │
│       │                                                 │
│       ├──── players: [Player]                           │
│       │         id / name / isOwner / order             │
│       │                                                 │
│       ├──── holes: [HoleScore]                          │
│       │         holeNumber / par                        │
│       │         counts:      [UUID: Int]  (Player.id 키)│
│       │         obCount:     [UUID: Int]                │
│       │         hazardCount: [UUID: Int]                │
│       │                                                 │
│       └──── photos: [RoundPhoto]                        │
│                 id / localPath / remoteURL?             │
│                 capturedAt / holeNumber? / caption?     │
└─────────────────────────────────────────────────────────┘

외부 참조
  Round ──► HKWorkout (HealthKit)   (HKWorkout UUID 매핑 필드는 spec 미정의)
  Round ──► Cloudflare Worker/KV/R2 — Viewer 공유 (sharedShortId 키)
```

---

## 3. SwiftData 영속 모델

아래 4개 `@Model` 클래스는 spec_3.md:488-534에 정의된 Swift 코드를 기준으로 한다. `@Relationship` 어노테이션은 spec에 없으며, 연관 모델은 단순 배열로 보유한다 (spec 미정의 — 후속 보완 TODO).

### Round (spec_3.md:489-507)

| 필드 | 타입 | Optional | 출처 | 비고 |
|------|------|----------|------|------|
| id | UUID | 아니오 | spec_3.md:491 | 라운드 식별자 |
| date | Date | 아니오 | spec_3.md:492 | 라운드 날짜 |
| courseId | String | 아니오 | spec_3.md:493 | GolfCourse.id 외래키 참조 |
| courseName | String | 아니오 | spec_3.md:494 | 코스 표시명 (비정규화 복사) |
| courseSubName | String | 예 | spec_3.md:495 | 수동 입력 또는 GPS 서브코스 감지 결과 (예: "동코스"). SubCourseSelector에서 선택한 SubCourse.name 저장. |
| players | [Player] | 아니오 | spec_3.md:496 | 동반자 목록 |
| holes | [HoleScore] | 아니오 | spec_3.md:497 | 홀별 점수 |
| photos | [RoundPhoto] | 아니오 | spec_3.md:498 | 첨부 사진 |
| isFinished | Bool | 아니오 | spec_3.md:499 | 라운드 종료 여부 |
| startedAt | Date | 아니오 | spec_3.md:500 | 라운드 시작 시각 |
| finishedAt | Date | 예 | spec_3.md:501 | 라운드 종료 시각 |
| sharedShortId | String | 예 | spec_3.md:502 | Viewer URL 단축 ID |
| sharedURL | String | 예 | spec_3.md:503 | 전체 Viewer URL |
| sharedExpiresAt | Date | 예 | spec_3.md:504 | Viewer 만료 시각 (7일 후) |
| sharedEditToken | String | 예 | spec_3.md:505 | Viewer 수정 토큰 |
| sharedOptions | ShareOptions | 예 | spec_3.md:506 | 이름 공개 여부 + 접근 제어 |

### Player (spec_3.md:510-515)

| 필드 | 타입 | Optional | 출처 | 비고 |
|------|------|----------|------|------|
| id | UUID | 아니오 | spec_3.md:511 | HoleScore의 counts 키 |
| name | String | 아니오 | spec_3.md:512 | 별명(닉네임) — 실명 외부 전송 금지 |
| isOwner | Bool | 아니오 | spec_3.md:513 | 라운드 소유자(기기 사용자) 여부 |
| order | Int | 아니오 | spec_3.md:514 | 표시 순서 |

### HoleScore (spec_3.md:518-524)

| 필드 | 타입 | Optional | 출처 | 비고 |
|------|------|----------|------|------|
| holeNumber | Int | 아니오 | spec_3.md:519 | 홀 번호 (1-18) |
| par | Int | 아니오 | spec_3.md:520 | 해당 홀 파 |
| counts | [UUID: Int] | 아니오 | spec_3.md:521 | Player.id → 총 타수 |
| obCount | [UUID: Int] | 아니오 | spec_3.md:522 | Player.id → OB 벌타 수 |
| hazardCount | [UUID: Int] | 아니오 | spec_3.md:523 | Player.id → 해저드 벌타 수 |

`counts`, `obCount`, `hazardCount` 세 필드 모두 `[UUID: Int]` 타입이며 Player.id를 키로 사용한다 (spec_3.md:521-523). `Dictionary<UUID, Int>`의 SwiftData 직렬화 지원 여부는 §10 — `[UUID: Int]` SwiftData 영속화 검증 필요 절 참조.

### RoundPhoto (spec_3.md:527-534)

| 필드 | 타입 | Optional | 출처 | 비고 |
|------|------|----------|------|------|
| id | UUID | 아니오 | spec_3.md:528 | 사진 식별자 |
| localPath | String | 아니오 | spec_3.md:529 | 기기 내 로컬 경로 |
| remoteURL | String | 예 | spec_3.md:530 | Cloudflare R2 업로드 URL |
| capturedAt | Date | 아니오 | spec_3.md:531 | 촬영 시각 |
| holeNumber | Int | 예 | spec_3.md:532 | 연관 홀 번호 |
| caption | String | 예 | spec_3.md:533 | 사진 설명 |

### 값 타입: ShareOptions / HoleInfo

`ShareOptions`와 `HoleInfo`는 `@Model`이 아닌 Codable struct다 (spec_3.md:536-559).

```swift
struct ShareOptions: Codable {
    var nameVisibility: NameVisibility   // .real / .anonymous
    var accessControl: AccessControl     // .public / .pin(String)
}

struct HoleInfo: Codable {
    var number: Int
    var par: Int
    var teeLat: Double
    var teeLng: Double
    var greenLat: Double
    var greenLng: Double
}
```

`ShareOptions`는 Round.sharedOptions 필드로 보유. `HoleInfo`는 GolfCourse.holes 배열 원소로 사용 (§5 참조).

---

## 4. 관계와 Cascade 규칙

spec_3.md §6에 `@Relationship` 어노테이션 정의 없음 (spec 미정의).

현재 모델은 Round가 Player / HoleScore / RoundPhoto를 단순 배열로 보유하는 구조다. Cascade delete 정책, inverse 관계, fetch 옵션은 후속 보완 TODO:

- Round 삭제 시 연관 HoleScore / Player / RoundPhoto의 cascade delete 정책
- `@Relationship(deleteRule:)` 적용 여부 및 대상 필드
- 대용량 photos 배열에 대한 lazy fetch 옵션
- Watch-side 모델 경량화 여부

---

## 5. Course 데이터 경계

### GolfCourse @Model (spec_3.md:542-550)

```swift
@Model
final class GolfCourse {
    var id: String
    var name: String
    var region: String
    var clubhouseLat: Double
    var clubhouseLng: Double
    var holesCount: Int?          // 총 홀 수 (nil: 638곳은 미기재 → 라운드 시작 시 사용자 입력)
    var courseType: String?       // "CC", "GC" 등
    var phone: String?            // 전화번호 (카카오 enrichment)
    var kakaoPlaceUrl: String?    // 카카오 장소 URL
    var subCourses: [SubCourse]?  // 서브코스 목록 (후속 데이터 보강 필요)
    var holes: [HoleInfo]         // 홀별 정보 (complete/partial/minimal 코스에만 존재)
    var dataQuality: DataQuality  // complete / partial / minimal / low / unknown
}
```

| 필드 | 타입 | Optional | 출처 |
|------|------|----------|------|
| id | String | 아니오 | spec_3.md §6 |
| name | String | 아니오 | spec_3.md §6 |
| region | String | 아니오 | spec_3.md §6 |
| clubhouseLat | Double | 아니오 | spec_3.md §6 |
| clubhouseLng | Double | 아니오 | spec_3.md §6 |
| holesCount | Int | 예 | v3 신규 — 공공데이터/카카오 enrichment |
| courseType | String | 예 | v3 신규 — 공공데이터 |
| phone | String | 예 | v3 신규 — 카카오 enrichment |
| kakaoPlaceUrl | String | 예 | v3 신규 — 카카오 enrichment |
| subCourses | [SubCourse] | 예 | v3 신규 — 후속 데이터 보강 필요 |
| holes | [HoleInfo] | 아니오 | spec_3.md §6 |
| dataQuality | DataQuality | 아니오 | v3 재정의 |

### 신규 값 타입: SubCourse

```swift
/// 서브코스 값 타입 (동/서/남/북 또는 전반/후반 라벨)
struct SubCourse: Codable {
    var name: String          // 서브코스 라벨 — 서브코스 라벨 (동/서/남/북 또는 전반/후반)
    var holes: [HoleInfo]     // 해당 서브코스의 홀 정보 (v3에서는 비어있음, 후속 보강 예정)
}
```

### 번들 JSON 방식

`Ref-docs/golf-db-pack/` 에 정의된 번들 JSON (`courses.json`) 은 한국 골프장 DB v3 (1,163곳, 2026-05-12 빌드) 데이터를 앱 번들에 포함하는 방식이다. 스키마 상세는 [40-COURSE_DB_SCHEMA.md](../golf-db-pack/40-COURSE_DB_SCHEMA.md) 참조. 데이터 소스는 OpenStreetMap (ODbL 1.0) + 공공데이터 + 카카오 enrichment이며, 앱 내 설정 → 정보에 라이선스 표기 필수 (CLAUDE.md §PROJECT).

- 1,163곳 중 1,139곳은 `dataQuality: low` (클럽하우스 좌표만 보유)
- complete 3곳 (전체의 0.26%) / partial 12곳 / minimal 9곳
- F3 GPS 자동 감지 — 골프장 + 서브코스 단위 (홀 단위 자동 감지는 미제공, 수동 진행)
- `dataQuality` 값 기반 분기 처리 필수 (CLAUDE.md §PROJECT)

### DataQuality enum (v3 재정의)

```swift
enum DataQuality: String, Codable {
    case complete  // complete 3곳 (전체의 0.26%): 18홀 완전 매핑
    case partial   // partial 12곳: 9홀 이상 매핑
    case minimal   // minimal 9곳: 1~8홀 매핑
    case low       // low 1139곳: 홀 정보 없음 — 골프장+서브코스 GPS 감지만 동작
    case unknown   // 분류 미정 (안전 fallback)
}
```

### 두 정의의 병존

spec_3.md §6은 `GolfCourse`를 `@Model`로 정의하고, golf-db-pack은 번들 JSON 방식으로 제공한다. 두 정의가 병존한다. 어느 방식을 채택할지(또는 둘 다 사용할지)는 `20-ARCHITECTURE.md`(작성 예정)에서 결정한다 — 결정 시 고려 기준: 메모리/번들 사이즈, CloudKit private DB와의 sync 범위 충돌 여부, 코스 데이터 갱신 빈도. 본 문서는 단정적 권장을 하지 않는다.

Round 모델은 `courseId: String` 외래키로 코스를 참조하며, 어느 방식을 채택하더라도 동일하게 동작한다.

---

## 6. CloudKit 매핑

spec_3.md:111-114 (F7) 에 따르면 라운드 기록은 CloudKit으로 자동 동기화된다.

- iOS 17 SwiftData + CloudKit 자동 sync 지원
- private database 사용 (라운드 기록은 개인 정보)
- 정책: 로컬 우선(local-first), 네트워크 복구 시 자동 sync (spec_3.md:114)
- 여러 디바이스에서 동일 데이터 확인 가능 (spec_3.md:113)

**CloudKit 컨테이너 ID**: spec 미정의 — 후속 보완 TODO. 실제 결정은 배포 설정 문서(90-DEPLOYMENT.md 또는 후속 시리즈 외)에서 확정.

**충돌 해결 정책**: spec 미정의. 오프라인 큐 및 CloudKit 충돌 해결 정책은 `23-OFFLINE_BEHAVIOR.md` (작성 예정)에 위임.

---

## 7. HealthKit 연동 키

spec_3.md:116-119 (F8) 에 따르면 라운드를 `HKWorkoutActivityType.golf` 워크아웃으로 기록한다. 걸음 수, 칼로리, 심박수, 라운드 시간은 Apple Watch에서 자동 수집된다.

**Round 모델에 HealthKit UUID 매핑 필드 없음**: spec_3.md §6 정의 기준, Round에 HKWorkout UUID를 저장하는 필드가 없다 (spec 미정의). HKWorkout과의 영속 매핑이 필요하다면 Round 모델에 필드 추가가 필요하다 — 후속 보완 TODO.

매핑 필드 권장안은 §10 구현 제안 참조.

---

## 8. Viewer 공유 필드 의미

Round 모델의 공유 관련 4개 필드 (spec_3.md:502-505):

| 필드 | 타입 | 의미 |
|------|------|------|
| sharedShortId | String? | Viewer URL 단축 ID (`golf.zerolive.co.kr/{shortId}`) |
| sharedURL | String? | 전체 Viewer URL (생성 시 채워짐) |
| sharedExpiresAt | Date? | Viewer 만료 시각 (생성 시점 + 7일) |
| sharedEditToken | String? | Viewer 수정/삭제용 토큰 |

**7일 만료 처리**: Cloudflare KV/R2의 데이터 자동 삭제 후, Round 객체의 위 4개 필드를 nil로 초기화한다 (CLAUDE.md §PROJECT). nil 처리 트리거 시점(앱 재실행, 백그라운드 태스크 등)은 `23-OFFLINE_BEHAVIOR.md`에 위임.

Viewer 페이로드 직렬화 구조(JSON 스키마)와 Cloudflare Worker API는 `30-API_SPEC.md` (본 시리즈 #5)에서 다룬다.

---

## 9. 책임 경계

| 문서 | 담당 영역 |
|------|-----------|
| **본 문서 (21-DATA_MODEL)** | SwiftData 영속 모델 스키마 — @Model 클래스, 필드 타입, 값 타입 |
| `20-ARCHITECTURE.md` (작성 예정) | 전체 시스템 아키텍처, GolfCourse 방식 결정 (@Model vs 번들 JSON) |
| `22-STATE_MANAGEMENT.md` (작성 예정) | 라운드 진행 중 메모리 상태 (@Observable 뷰모델) |
| `23-OFFLINE_BEHAVIOR.md` (작성 예정) | 오프라인 큐, CloudKit 충돌 해결, Viewer 만료 nil 처리 |
| `30-API_SPEC.md` (본 시리즈 #5) | Viewer 페이로드 직렬화, Cloudflare Worker API |
| `40-COURSE_DB_SCHEMA.md` (golf-db-pack) | 번들 JSON 스키마, OSM 데이터 파이프라인 |

---

## 10. 구현 제안 (spec 외)

본 섹션은 `spec_3.md`에 없는 구현 권장안이며, 실제 결정은 `20-ARCHITECTURE.md` / `23-OFFLINE_BEHAVIOR.md` 등 후속 문서에서 확정한다. 본 문서가 명세화하지 않는다.

### GolfCourse 병존 처리 옵션

- **옵션 A — 번들 JSON 인메모리 로드**: 매 실행 시 `courses.json`을 `CourseRepository`로 메모리에 로드. SwiftData에 적재하지 않음. 쓰기 불필요(read-only), 앱 업데이트로 DB 갱신. 구현 단순.
- **옵션 B — 번들 JSON → SwiftData 캐시**: 첫 실행(또는 버전 변경) 시 JSON을 GolfCourse @Model로 SwiftData에 적재. 이후 SwiftData 쿼리로 조회. CloudKit private DB와의 sync 범위 주의 필요.

어느 옵션을 선택할지, 또는 두 방식을 혼용할지는 `20-ARCHITECTURE.md`에서 결정한다.

### `[UUID: Int]` SwiftData 영속화 검증 필요

HoleScore의 `counts`, `obCount`, `hazardCount` 세 필드는 모두 `[UUID: Int]` (Dictionary) 타입이다 (spec_3.md:521-523). iOS 17 `@Model`에서 `Dictionary<UUID, Int>` 직렬화 지원 여부는 구현 단계에서 반드시 검증해야 한다.

미지원 시 대안:

```swift
// 대안: Codable struct 배열 형태로 대체
struct ScoreEntry: Codable {
    var playerId: UUID
    var value: Int
}
// HoleScore 내 필드 변경 예시
var counts: [ScoreEntry]
var obCount: [ScoreEntry]
var hazardCount: [ScoreEntry]
```

또는 별도 @Model 서브엔티티로 분리. 세 필드 모두 동일하게 해당.

### HealthKit 매핑 필드 권장

Round 모델에 다음 필드 추가를 권장한다 (spec 미정의이므로, 확정 시 spec 보완 필요):

```swift
var healthKitWorkoutUUID: UUID?    // HKWorkout 연결 키
var healthKitStartDate: Date?      // HKWorkout 시작 시각 (검증용)
```

### VersionedSchema 마이그레이션 권장

스키마 변경에 대비해 SwiftData `VersionedSchema` + `SchemaMigrationPlan` 패턴 도입을 권장한다. 마이그레이션 정책 설계는 부록 후속 보완 TODO에서 추적.

> CloudKit 컨테이너 ID 예시값은 §6 본문에서 배포 설정 문서로 위임됨. 본 §10에서는 별도 예시를 두지 않는다.

---

### 부록: 후속 보완 TODO

#### spec 미정의 항목

- `@Relationship` cascade / inverse 정책 (Round → Player, HoleScore, RoundPhoto)
- CloudKit 컨테이너 ID (실제 값)
- HKWorkout 매핑 필드 (Round 모델에 추가 여부)
- 스키마 버전 관리 및 마이그레이션 정책 (VersionedSchema)
- Watch-side 경량 모델 분리 여부

#### 외부 문서 위임

- `20-ARCHITECTURE.md`: GolfCourse 방식 결정 (@Model vs 번들 JSON), 전체 레이어 구조
- `22-STATE_MANAGEMENT.md`: 라운드 진행 중 @Observable 메모리 상태
- `23-OFFLINE_BEHAVIOR.md`: CloudKit 충돌 해결, Viewer 만료 nil 처리 타이밍
- `30-API_SPEC.md`: Viewer JSON 페이로드 직렬화 스키마

---

*최종 업데이트: 2026-05-11*
