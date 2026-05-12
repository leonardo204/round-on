# 22 — 상태 관리 (State Management)

> **작성일**: 2026-05-11
> **버전**: v4 기반
> **출처 명세서**: [기능 명세서 v4](../golf-scorecard-app-spec_3.md) §F4 (75-90), §F5 (91-105), §F6 (107-109), §F7 (111-114), §7.1-7.2 (566-606)
> **관련 문서**: `20-ARCHITECTURE.md`, `21-DATA_MODEL.md`, `23-OFFLINE_BEHAVIOR.md` (작성 예정), `11-COMPONENTS.md`, `13-HAPTICS_AND_MOTION.md`, `30-API_SPEC.md`

---

## 1. 개요 및 책임 경계

본 문서는 라운드온(Round-On) 앱의 **런타임 상태 관리**를 명세한다.

### 본 문서 책임

| 영역 | 내용 |
|------|------|
| ViewModel 카탈로그 | 5종 `@Observable` ViewModel 정의 및 의존 그래프 |
| WatchConnectivity 메시지 카탈로그 | 3종 WC 메시지 페이로드 스키마 |
| 충돌 해결 알고리즘 | N=2 노드 tiebreaker 정책 + CloudKit 충돌 모달 조건 |
| write 타이밍 정책 | 이벤트별 SwiftData write / WC 전송 / CloudKit push 매트릭스 |

### 본 문서 비책임 (위임)

| 영역 | 위임 문서 |
|------|----------|
| SwiftData `@Model` 스키마 (HoleScore, Round 등) | `21-DATA_MODEL.md` |
| 오프라인 큐, CloudKit 충돌 복구 상세 | `23-OFFLINE_BEHAVIOR.md` |
| Viewer API 호출 후 4개 필드 업데이트 | `30-API_SPEC.md` |
| HapticEngine 모듈 위치 및 이벤트 라우팅 | `13-HAPTICS_AND_MOTION.md` |
| SyncCoordinator actor 배치 위치 | `20-ARCHITECTURE.md §9` |

---

## 2. 상태 계층 모델

라운드온 상태는 3계층으로 구분된다. **Single Source of Truth = SwiftData (디스크)**.

```
┌──────────────────────────────────────────────────────────┐
│                    SwiftData (디스크)                     │
│  Round / HoleScore / Player / GolfCourse  @Model         │
│  → 앱 재시작 후에도 복구 가능 (spec_3.md:108-109)          │
└────────────────────────┬─────────────────────────────────┘
                         │ read / write (즉시 sync)
                         ▼
┌──────────────────────────────────────────────────────────┐
│                  ViewModel 계층 (메모리)                   │
│  @Observable — MainActor 격리                            │
│  SwiftData 읽기 캐시 + UI 바인딩 제공                     │
└───────┬────────────────┬─────────────────────────────────┘
        │ @Observable    │ WC 델타 전송
        ▼                ▼
┌───────────────┐  ┌─────────────────────────────────────┐
│  View (SwiftUI)│  │  WatchConnectivity (디바이스 간 델타) │
│  렌더링만       │  │  sendMessage / updateApplicationContext │
│  상태 보유 X   │  │  / transferUserInfo                  │
└───────────────┘  └─────────────────────────────────────┘
```

**원칙**: View는 상태를 직접 보유하지 않는다. ViewModel이 SwiftData 캐시를 보유하며, 모든 변경은 SwiftData를 통해 영속된 후 `@Observable`이 View를 갱신한다. (20-ARCHITECTURE §4)

---

## 3. @Observable ViewModel 카탈로그

### VM 5종 의존 그래프

```
        RoundViewModel  ← 현재 라운드 루트 (앱 전역 1개)
              │
       ┌──────┼──────────────┬──────────────┐
       ▼      ▼              ▼              ▼
   HoleVM  PlayerListVM  ScoreCardVM    ShareVM
  (현재 홀)  (1-4명)      (4×18 파생)   (viewer 모달)
```

RoundViewModel이 나머지 4개 VM의 부모다. RoundViewModel이 nil이면 하위 VM은 비활성 상태를 유지한다.

---

| VM | 핵심 props | 책임 | 출처 |
|----|-----------|------|------|
| **RoundViewModel** | `round: Round?`, `isActive: Bool` | 라운드 라이프사이클, 하위 VM 생성, F6 복구 | spec_3.md:107-114 |
| **HoleViewModel** | `currentHoleIndex: Int`, `currentPar: Int`, `currentSubCourseIndex: Int`, `subCourseName: String?`, `gpsMatchState` | 수동 홀 진행 모드 (스와이프/탭), F3 골프장+서브코스 GPS 감지는 모든 코스에서 동작. 홀 단위 자동 감지는 미제공. Round.courseSubName 바인딩 | spec_3.md:97 |
| **PlayerListViewModel** | `players: [Player]`, `activePlayerIndex: Int` | 동반자 전환 (상/하 스와이프), 표시명/익명 | spec_3.md:98 |
| **ScoreCardViewModel** | `holes: [HoleScore]`, computed `totalScore`, `scoreVsPar` | 4×18 그리드 캐싱, ±par 실시간 계산, counts/obCount/hazardCount | spec_3.md:86, 103 |
| **ShareViewModel** | `isPresented`, `anonymousMode`, `accessMode`, `shareURL?` | 공유 옵션 모달, POST `/api/share` 위임 | spec_3.md:573-580 |

모든 VM은 `@Observable @MainActor final class`로 선언하며 `SyncCoordinator`(20-ARCHITECTURE §9)를 주입받는다.

---

## 4. 카운터 입력 → 저장 파이프라인

별도 "저장" 버튼 없음. **매 +1마다 즉시 SwiftData write** (spec_3.md:108-109, 20-ARCHITECTURE §3.1).

```
[Watch 큰탭 / Digital Crown 회전]
[iPhone 셀 탭 / 길게 누르기]          spec_3.md §F5 (91-105)
              │
              ▼
   VM.increment(player:, hole:)
   또는 VM.decrement(player:, hole:)
              │
              ▼
   clamp(0, ∞) 검증                  §6.3 참조
   — 0 미만이면 무시 + Haptic .warning (13-HAPTICS §3 F5)
              │
              ▼
   SwiftData write (즉시 sync)        21-DATA_MODEL §3
              │
              ▼
   @Observable willChange → View 리렌더
              │
              ▼
   SyncCoordinator.broadcastShot()    20-ARCHITECTURE §9
              │
              ▼
   WC.sendMessage(ShotEvent)          §5 WC 카탈로그
   → 상대 디바이스 수신 처리
```

**에러 처리**: SwiftData write 실패 시 VM 메모리 캐시 롤백 + Toast 표시. 햅틱은 write 완료를 기다리지 않고 입력 발생 즉시 발화 (13-HAPTICS §4 동기화 정책).

---

## 5. WatchConnectivity 메시지 카탈로그 (3종)

`transferFile` 미사용 (이 앱에서 파일 전송 시나리오 없음). (20-ARCHITECTURE §3.2 위임 수신)

| 메시지 종류 | WC API | 용도 | 페이로드 |
|------------|--------|------|---------|
| 즉시 이벤트 | `sendMessage(_:replyHandler:errorHandler:)` | 카운터 ±1, OB/해저드/OK, 홀 이동, 동반자 전환 | `ShotEvent`, `HoleChange`, `PlayerSwitch` |
| 초기 스냅샷 | `updateApplicationContext(_:)` | 라운드 시작 시 골프장·동반자·par 배열 전달 | `RoundSnapshot` |
| 백그라운드 큐잉 | `transferUserInfo(_:)` | Watch 백그라운드 시 ShotEvent FIFO 큐잉 fallback | `ShotEvent` (FIFO 순서 보존) |

### 페이로드 Codable 스키마

```swift
/// 카운터 변경 이벤트 (즉시 sendMessage + 백그라운드 transferUserInfo fallback)
struct ShotEvent: Codable {
    let type: ShotType         // .increment / .decrement / .ob / .hazard / .ok
    let playerId: UUID
    let holeNumber: Int        // 1-18
    let timestamp: Date        // 충돌 해결용 timestamp_ms 기준
    let deviceId: String       // "iPhone" / "Watch"
    let perDeviceCounter: UInt64  // 디바이스별 단조 증가 카운터
}

/// 홀 이동 이벤트
struct HoleChange: Codable {
    let newHoleNumber: Int
    let trigger: ChangeTrigger  // .manualSwipe (홀 단위 자동 감지 미제공 — F3는 골프장+서브코스 단위만 지원)
    let subCourseName: String?  // Round.courseSubName — 서브코스 라벨 (동/서/남/북 또는 전반/후반)
    let timestamp: Date
    let deviceId: String
    let perDeviceCounter: UInt64
}

/// 동반자 전환 이벤트
struct PlayerSwitch: Codable {
    let newPlayerIndex: Int
    let timestamp: Date
    let deviceId: String
    let perDeviceCounter: UInt64
}

/// 라운드 시작 스냅샷 (updateApplicationContext)
struct RoundSnapshot: Codable {
    let roundId: UUID
    let courseId: String
    let players: [Player]
    let activeHoleNumber: Int
    let activePlayerIndex: Int
    let parArray: [Int]        // 18홀 par 배열
}
```

**sendMessage vs transferUserInfo 분기 기준**: `WCSession.isReachable == true`이면 `sendMessage` 사용. `isReachable == false` (Watch 백그라운드 또는 미연결)이면 `transferUserInfo` 큐잉 — Watch 포그라운드 복귀 시 FIFO 순서로 처리. (spec_3.md §F5 자동 sync 명세 기반)

---

## 6. 충돌 해결 알고리즘

### 카운터 이벤트 = LWW 아닌 Delta-merge (핵심 설계)

F4 "샷마다 +1"의 의미는 **누적 카운트의 단조 증가 델타**다. 절대값 LWW(Last-Write-Wins)를 적용하면 "Watch +1과 iPhone +1이 거의 동시에 발생할 경우 한쪽이 묻혀 의도 손실"이 발생한다. 따라서:

- **각 ShotEvent는 고유 `eventId: UUID`로 식별되며 dedupe 후 적용**
- `counts[playerId]` 최종값 = **모든 적용된 ShotEvent.delta의 합** (delta는 +1, +2(OB), -1 등)
- `(timestamp_ms, deviceId, perDeviceCounter)` tuple은 **이벤트 순서 결정용**이며 동일 eventId 재수신 시 무시
- 절대값 비교 LWW는 **카운터 외 필드(player.name, hole.par 등)에만 적용**

이렇게 하면 N=2 노드 시계 스큐(NTP 미동기, 수백ms~수초)가 있어도 누적 카운트는 보존된다.

### N=2 노드 이벤트 순서 결정용 tiebreaker

라운드온의 노드는 Watch + iPhone 2개 고정. **Lamport clock은 N=2에 과도하므로 미채택** (N≥3 시 재검토). 순서가 필요한 경우(예: 라이트박스 UI 동기화) 다음 사전식 비교:

1. `timestamp_ms` (Date.timeIntervalSince1970 × 1000) 큰 쪽 우선
2. 동률 시 `devicePriority` enum (`.watch = 0`, `.iPhone = 1`) 작은 값 우선 (확장 시 명시 상수 매핑)
3. 동률 시 `perDeviceCounter` 큰 쪽 우선

`perDeviceCounter`는 디바이스 재시작 시 UserDefaults에 저장된 마지막 값에서 이어서 단조 증가한다.

---

### 6.1 로컬 충돌 (Watch ↔ iPhone WC 동시 편집)

동일 `(playerId, holeNumber)` 셀에 Watch와 iPhone이 동시에 이벤트를 보낼 때:

1. SyncCoordinator actor가 이벤트를 직렬 수신 (20-ARCHITECTURE §9)
2. **각 ShotEvent의 `eventId`로 dedupe** — 이미 적용된 eventId는 무시
3. dedupe 통과한 이벤트의 `delta`를 `counts[playerId]`에 누적 합산 (LWW 아님)
4. 카운터 외 필드(예: 라운드 메타) 충돌은 tiebreaker로 LWW 적용
5. 누적 후 SwiftData write 1회
6. clamp(0, ∞) 적용 — 음수 합 결과는 0으로 보정

---

### 6.2 CloudKit 충돌 (21-DATA_MODEL §6 위임 수신)

iOS 17 SwiftData + CloudKit 자동 sync 충돌 처리 정책:

| 시점 | 조건 | 정책 | 사용자 경험 |
|------|------|------|------------|
| 라운드 **진행 중** (`isFinished == false`) | 모든 충돌 | **LWW(Last-Write-Wins) 자동 적용** | Toast "동기화됨" — 사용자 차단 없음 |
| 라운드 **종료 후** (`isFinished == true`) | 점수 동일 | Silent merge | 알림 없음 |
| 라운드 **종료 후** (`isFinished == true`) | 점수 상이 — 판정식: `localTotal != remoteTotal` OR `any(holes.counts/obCount/hazardCount diff)` | **사용자 명시 머지 모달** | "어느 기록을 유지할까요?" 선택지 |
| 라운드 **재개 시점** (F6 cold start) | 모든 충돌 | **LWW 자동 적용** | Toast "동기화됨" — 자동 복구 원칙 준수 (spec_3.md:108-109) |

**설계 근거**: 진행 중에는 실시간성이 우선이므로 사용자를 차단하지 않는다. 라운드 종료 후 최종 점수가 다른 경우에만 사용자 판단이 필요하다.

---

### 6.3 clamp(0, ∞) 정책 표

| 필드 | lower bound | -1 입력 시 동작 |
|------|------------|----------------|
| `counts[playerId]` | 0 | 무시 + Haptic `.warning` (13-HAPTICS §3 F5 권한 거부/에러 행) |
| `obCount[playerId]` | 0 | 무시 + Haptic `.warning` |
| `hazardCount[playerId]` | 0 | 무시 + Haptic `.warning` |

"무시"는 SwiftData write 없이 VM 상태 변경 없이 반환함을 의미한다. `okCount`는 spec_3.md 정의 상 별도 카운터 없이 counts에 합산되므로 별도 행 없음.

---

## 7. 저장 타이밍 정책 매트릭스

| 이벤트 | SwiftData write | WC 전송 | CloudKit push |
|--------|----------------|---------|--------------|
| 카운터 ±1 | 즉시 (sync) | `sendMessage` 즉시 | iOS 17 자동 sync (디바운스 약 2s) |
| OB / 해저드 / OK | 즉시 | `sendMessage` 즉시 | 디바운스 약 2s |
| 홀 이동 | 즉시 | `sendMessage` 즉시 | 디바운스 약 2s |
| 동반자 전환 | 즉시 (UI 상태 영속) | `sendMessage` 즉시 | (필요 없음, 세션 범위) |
| 사진 추가 | 즉시 (파일 경로 저장) | 해당 없음 | 즉시 (CKAsset) |
| 라운드 시작 | 즉시 | `updateApplicationContext` | 즉시 |
| 라운드 종료 | 즉시 | `sendMessage` 즉시 | 즉시 flush (디바운스 우선 적용) |
| Watch 백그라운드 fallback | — | `transferUserInfo` 큐 | — |

**CloudKit 디바운스 약 2s**: iOS 17 SwiftData가 자동 처리하는 권장값. 실측 후 조정 가능 (§10 [SPEC-UNDEFINED] 참조).

---

## 8. 라운드 재개 (F6) 상태 복구

앱 강제 종료 또는 배터리 방전 후 재시작 시 자동 복구한다. (spec_3.md:108-109)

```
앱 cold start
      │
      ▼
SwiftData 쿼리: Round.isFinished == false
      │
      ├── 없음: 홈 화면 (새 라운드 시작 유도)
      │
      └── 있음:
              │
              ▼
        RoundViewModel 재구성
        HoleViewModel: 마지막 activeHoleNumber 복원
        ScoreCardViewModel: HoleScore 전체 로드 + 합계 재계산
              │
              ▼
        Watch 재연결 감지 (WCSessionDelegate.sessionReachabilityDidChange)
              │
              ▼
        updateApplicationContext(RoundSnapshot) 전송
        → Watch가 현재 상태로 UI 동기화
```

**원칙**: "라운드 종료" 버튼 탭 전까지는 `isFinished == false`가 유지된다. 사용자의 명시적 종료 없이는 자동 복구가 항상 발동한다.

---

## 9. 책임 경계

| 문서 | 담당 영역 | 상태 |
|------|----------|------|
| **본 문서 (22-STATE_MANAGEMENT)** | @Observable VM 카탈로그, WC 메시지 3종, 충돌 알고리즘, write 타이밍 | 작성 완료 |
| `20-ARCHITECTURE.md` | SyncCoordinator actor 위치, 3타깃 모듈 분리, 데이터 흐름 화살표 | 작성 완료 |
| `21-DATA_MODEL.md` | SwiftData `@Model` 스키마 (HoleScore counts, Round 등) | 작성 완료 |
| `23-OFFLINE_BEHAVIOR.md` | 오프라인 큐, CloudKit 충돌 복구 상세, viewer 만료 nil 처리 | 작성 예정 |
| `11-COMPONENTS.md` | ShotButton 단방향 데이터 흐름 props, onIncrement/onDecrement 콜백 | 작성 완료 |
| `13-HAPTICS_AND_MOTION.md` | -1 입력 무시 시 `.warning` 햅틱, Watch↔iPhone 동기화 정책 | 작성 완료 |
| `30-API_SPEC.md` | POST `/api/share` 후 sharedShortId 등 4개 필드 업데이트 계약 | 작성 완료 |

---

## 10. 미정의 / 구현 검증 + 구현 제안

### [SPEC-UNDEFINED] 미정의 또는 실측 필요

1. **즉시 write 배터리·IO 영향**: 18홀 라운드 4-5시간 × 플레이어당 약 300 write 가정. 실제 SwiftData 트랜잭션 비용은 구현 단계에서 측정. 영향 확인 시 폴백: **100ms debounce 그룹 write** — UI 반응성은 메모리 캐시(@Observable)가 즉시 갱신하여 유지, write만 그룹화. **트레이드오프**: 100ms 윈도우 내 앱 강제 종료 시 마지막 그룹은 F6 복구 데이터에서 손실 가능 (약 1-3 탭). §4 파이프라인은 폴백 발동 시 "메모리 캐시 즉시 + SwiftData write 100ms 그룹화"로 흐름 분기.

5. **디바이스 시계 스큐**: Watch/iPhone NTP 동기화 부재 시 `timestamp_ms`가 수백ms~수초 어긋날 수 있음. §6의 카운터 delta-merge 정책 덕분에 카운터 누적은 영향받지 않으나, 카운터 외 필드(라운드 메타 등) LWW 적용 시 순서 역전 가능. WC 핸드셰이크 시 clock offset 측정 후 보정 권장 — 구현 단계 결정.

2. **WC sendMessage 손실률**: `isReachable == true`인 foreground 상태에서 `sendMessage`는 reliable. Watch 백그라운드 진입 타이밍에 따라 손실 가능. `transferUserInfo` fallback 전환 시점(isReachable 변경 → 몇 ms 이내)의 실측 데이터 없음.

3. **CloudKit private DB 디바운스 약 2s**: 본 문서 권장값. iOS 17 SwiftData 자동 sync 내부 구현에 따라 실제 값이 다를 수 있음 — 실측 후 조정 예정.

4. **Watch 앱 독립 SwiftData 여부**: Watch가 독자 ModelContainer를 가질지, iPhone에서만 SwiftData write가 발생할지 미결 (20-ARCHITECTURE §10 항목 5). 본 문서 파이프라인은 iPhone SyncCoordinator 단일 write 경로를 가정하며, 결정 변경 시 §4 파이프라인 업데이트 필요.

---

### 구현 제안 (spec 외, 비규범)

> 본 섹션은 spec_3.md에 없는 구현 권장안이며, 실제 결정은 구현 단계에서 확정.

**ScoreCardViewModel 핵심 흐름** (`Shared` 타깃, 20-ARCHITECTURE §5):

```swift
@Observable @MainActor
final class ScoreCardViewModel {
    private(set) var holes: [HoleScore]
    private let coordinator: SyncCoordinator  // 20-ARCHITECTURE §9

    func increment(player: UUID, hole: Int) async throws {
        // 1. 메모리 캐시 즉시 갱신 (@Observable → View 리렌더)
        holes[hole].counts[player, default: 0] += 1
        // 2. SwiftData write (즉시) — 실패 시 롤백 + 호출부 Toast
        try await coordinator.persist(holes[hole])
        // 3. WC 전송
        await coordinator.broadcastShot(ShotEvent(type: .increment, playerId: player,
            holeNumber: hole + 1, timestamp: Date(),
            deviceId: DeviceIdentifier.current,
            perDeviceCounter: coordinator.nextCounter()))
    }

    func decrement(player: UUID, hole: Int) async {
        // clamp: 0 미만 무시 + Haptic .warning (13-HAPTICS §3)
        guard holes[hole].counts[player, default: 0] > 0 else {
            HapticEngine.shared.play(.countBelowZeroRejected)
            return
        }
        holes[hole].counts[player, default: 0] -= 1
        try? await coordinator.persist(holes[hole])
        await coordinator.broadcastShot(ShotEvent(type: .decrement, ...))
    }
}
```

`perDeviceCounter`는 `UserDefaults`에 영속하여 앱 재시작 후에도 단조 증가를 유지한다.

---

*최종 업데이트: 2026-05-11*
