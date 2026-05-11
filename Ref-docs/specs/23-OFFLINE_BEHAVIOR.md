# 23 — 오프라인 동작 (Offline Behavior)

> **작성일**: 2026-05-11
> **버전**: v4 기반
> **출처 명세서**: [기능 명세서 v4](../golf-scorecard-app-spec_3.md) §F6 (107-109), §F7 (111-114), §F9 (121-129), §3.4 (277-284), §9 (655-672)
> **관련 문서**: `20-ARCHITECTURE.md`, `21-DATA_MODEL.md`, `22-STATE_MANAGEMENT.md`, `30-API_SPEC.md`, `13-HAPTICS_AND_MOTION.md`, `53-PERMISSIONS.md`

---

## 1. 개요 및 책임 경계

본 문서는 라운드온(Round-On) 앱의 **오프라인 동작 전략** 을 명세한다. 네트워크 단절 상황에서도 라운드 기록이 유실되지 않으며, 복귀 시 자동 복구되는 것을 보장한다.

### 본 문서 책임

NetworkMonitor 상태 감지, PendingOperation 오프라인 큐, CloudKit 복구 sync 위임 수신, viewer 7일 만료 nil 처리 타이밍, 재시도 백오프 정책, 사용자 알림 채널 정책.

### 본 문서 비책임 (위임)

| 영역 | 위임 문서 |
|------|----------|
| WC 메시지 큐잉, transferUserInfo fallback | `22-STATE_MANAGEMENT.md §5` |
| SwiftData @Model 스키마 | `21-DATA_MODEL.md §3` |
| Viewer 4개 필드 원본 정의 | `21-DATA_MODEL.md §8` |
| API 엔드포인트 계약, 에러 코드 | `30-API_SPEC.md §7`, `§9.6` |
| 알림 햅틱 이벤트 매핑 | `13-HAPTICS_AND_MOTION.md §3` |
| UNNotification 권한 요청 | `53-PERMISSIONS.md §6` |
| SyncCoordinator actor 배치 | `20-ARCHITECTURE.md §9` |

---

## 2. 네트워크 상태 모니터링

`NWPathMonitor`를 래핑한 actor `NetworkMonitor.shared` 가 앱 전역 네트워크 상태를 단일 소스로 관리한다. (spec_3.md:111-114 F7 로컬 우선 원칙)

### 네트워크 상태 enum

```swift
enum NetworkStatus: Equatable {
    case online
    case offlineCellularOff   // Wi-Fi 없음 + 셀룰러 없음
    case offlineAirplane      // 비행기 모드 (path.isExpensive == false, isConstrained == false, status == .unsatisfied)
    case constrained          // Low Data Mode (path.isConstrained == true)
}
```

`.offlineAirplane` 판별: `NWPath` 인터페이스 목록이 완전 비어있는 것으로 판별. `.offlineCellularOff`는 Wi-Fi 인터페이스가 있으나 `status == .unsatisfied`. 정확한 판별 로직은 구현 단계 확정 ([SPEC-UNDEFINED]).

### 상태 x 허용 작업 매트릭스

| 상태 | JSON sync (CloudKit) | 사진 업로드 | viewer 생성/수정 | viewer 조회 |
|------|---------------------|------------|----------------|------------|
| `.online` | 즉시 | 즉시 | 즉시 | 즉시 |
| `.constrained` (Low Data) | 즉시 | **보류** (큐 적재) | 보류 | 가능 |
| `.offlineCellularOff` | 큐 적재 | 큐 적재 | 큐 적재 | 캐시만 |
| `.offlineAirplane` | 큐 적재 | 큐 적재 | 큐 적재 | 캐시만 |

`.constrained` 상태에서 CloudKit sync는 허용한다. CloudKit 자체가 Low Data Mode를 인식하여 전송량을 조절하기 때문이다. 사진 업로드는 대역폭 소비가 크므로 큐에 적재한다.

### @Observable 게시

`NetworkMonitor`는 내부에 `@Observable final class State { var status: NetworkStatus = .online }`를 보유한다. `RoundViewModel`이 주입받아 `status`를 관찰하며 (22-STATE §3 VM 카탈로그 연계), 상태 변경은 MainActor로 dispatch하여 SwiftUI 갱신을 보장한다.

---

## 3. 오프라인 작업 큐 (PendingOperation)

Cloudflare Worker API 호출이 오프라인 또는 `.constrained` 상태에서 발생하면 **SwiftData 내 `PendingOperation` 레코드로 보류**된다. CloudKit을 통해 디바이스 간 큐를 공유하지 않는다 — **큐는 디바이스 로컬 전용** ([SPEC-UNDEFINED] 결정: 디바이스별 큐 분리, 중복 실행 방지 목적).

### @Model 스키마

```swift
@Model
final class PendingOperation {
    @Attribute(.unique) var id: UUID
    var type: OperationType
    var payload: Data         // Codable 직렬화 (JSON)
    var createdAt: Date
    var retryCount: Int
    var nextAttemptAt: Date
    var lastError: String?
    var roundId: UUID?        // dedup 키 (type에 따라 사용)
    var photoId: UUID?        // uploadPhoto / deletePhoto dedup 키
}

enum OperationType: String, Codable {
    case createShare
    case updateShare
    case uploadPhoto
    case deletePhoto
    case deleteShare
}
```

### Dedup 규칙

오프라인 중 동일 라운드의 편집이 반복될 수 있으므로, 큐 적재 시 아래 dedup 규칙을 적용하여 불필요한 중복 API 호출을 제거한다.

| Type | Dedup 기준 | 동작 |
|------|-----------|------|
| `updateShare` | 같은 `roundId` | 미실행 기존 항목 폐기 후 최신만 유지 |
| `uploadPhoto` | 같은 `(roundId, photoId)` | 미실행 기존 항목 폐기 후 최신만 유지 |
| `deletePhoto` | 같은 `(roundId, photoId)` | uploadPhoto 미실행 항목이 있으면 둘 다 폐기 (net-zero) |
| `createShare` | — | dedup 없음. 중복 방지는 `roundId`로 완료 여부 확인 후 skip |
| `deleteShare` | 같은 `roundId` | 중복 dedup (멱등 보장) |

**큐 최대 크기**: 500건 권장 ([SPEC-UNDEFINED]). 초과 시 가장 오래된 `uploadPhoto` 항목부터 폐기. `createShare` / `deleteShare` 는 마지막에 폐기.

### OperationQueueProcessor

`OperationQueueProcessor` actor는 `SyncCoordinator` (20-ARCHITECTURE §9) 하위에 위치한다.

- 네트워크 상태가 `.online`으로 전환되는 즉시 자동 drain 시작
- **우선순위 순서**: `deleteShare > createShare > updateShare > uploadPhoto > deletePhoto`
- 우선순위가 높을수록 먼저 처리. 동일 우선순위 내에서는 FIFO
- actor isolation 보장 — 동시 drain 시도는 guard로 차단

---

## 4. CloudKit 복구 시 sync 전략

22-STATE §6.2 충돌 해결 정책을 위임받아 구현 상세를 명세한다. iOS 17 SwiftData + CloudKit 자동 sync 전제 (spec_3.md:111-114 F7).

### 시나리오 A: 음영 지역 단방향 편집 후 복귀

```
오프라인 기간:
  iPhone (SwiftData write 즉시) → CloudKit push 보류

네트워크 복귀:
  iOS 17 SwiftData 자동 sync → 서버에 미반영분 push
  → 다른 디바이스 pull 없음 (단방향) → 충돌 없음

사용자 경험:
  Toast "동기화됨" (자동 사라짐 2초)
```

### 시나리오 B: 양쪽 디바이스 오프라인 편집 후 양쪽 복귀

```
Watch  (오프라인) → SwiftData(local write) → CloudKit push 시도
iPhone (오프라인) → SwiftData(local write) → CloudKit push 시도
       → CKError.serverRecordChanged 수신

라운드 상태 분기 (22-STATE §6.2):
  isFinished == false
    → LWW 자동 적용 + Toast "동기화됨"
  isFinished == true, 점수 동일
    → silent merge (알림 없음)
  isFinished == true, 점수 상이
    → 사용자 명시 머지 모달 표시 (아래 wireframe 참조)
```

### 충돌 모달 wireframe (라운드 종료 후 점수 상이, 단 1케이스)

```
┌─────────────────────────────────────┐
│  동기화 충돌 발견                     │
│  어느 기록을 유지할까요?               │
│  ─────────────────────────          │
│  [로컬 기기]      [클라우드]          │
│  총 82타          총 84타            │
│  Hole 7: +3       Hole 7: +5         │
│  (변경 홀 diff 강조 표시)             │
│  ─────────────────────────          │
│  [로컬 유지]  [클라우드 유지]  [수동]  │
└─────────────────────────────────────┘
```

- "수동" 선택: 홀별 점수 직접 비교 화면 진입 (11-COMPONENTS 후속 보완 TODO)
- 포그라운드 진입 시 1회만 표시. 중복 방지: `Round.conflictPending: Bool` 플래그 활용 권장

### F6 cold start 재개 시점

앱 재시작 후 라운드 재개 시 충돌이 있으면 **LWW 자동 적용** (spec_3.md:108-109). 사용자를 차단하지 않는다. (22-STATE §6.2 재개 시점 행)

---

## 5. Viewer 7일 만료 nil 처리 타이밍

21-DATA_MODEL §8 및 30-API §9.6 위임 수신. viewer 만료 시 4개 필드(`sharedShortId` / `sharedURL` / `sharedExpiresAt` / `sharedEditToken`)를 nil로 처리한다.

### 트리거 3종

**트리거 1 — Cold start 체크 (확실한 실행 보장)**

앱 실행 시 `App.init` 시점에 SwiftData fetch로 `Round.sharedExpiresAt < Date.now` 조건의 라운드를 일괄 검색하여 4개 필드를 nil 처리하고 `modelContext.save()`. 사용자 알림 없음 — 라운드 목록에서 공유 배지가 사라지는 것으로 묵시적 반영.

**트리거 2 — BGAppRefreshTask (best-effort, 6시간 간격) [SPEC-UNDEFINED]**

iOS BGAppRefreshTask는 실행 보장이 없다. 만료 임박(D-1) 또는 만료 경과 라운드를 점검하여 nil 처리한다. cold start 보완 수단이며 필수 경로로 의존하지 않는다.

**트리거 3 — 사용자 명시 삭제 ("공유 회수")**

라운드 상세 → "공유 회수" 탭 → `DELETE /api/share/{shortId}` 시도:
- 성공(204): 4개 필드 nil + Toast "공유가 회수되었습니다"
- 오프라인: `PendingOperation(type: .deleteShare)` 적재 + **즉시 로컬 nil 처리** + Toast "오프라인 — 서버 삭제는 복귀 후 처리됩니다"
- 410(이미 만료): 로컬 nil + Toast "공유가 이미 만료되었습니다"

### 410 응답 자동 감지

만료된 viewer 수정 시도(`PUT /api/share/{shortId}`) 시 410 수신:

```
410 수신
  → 즉시 4개 필드 nil
  → 배너 "공유가 만료되어 회수했습니다" (액션 없음)
  → PendingOperation에서 해당 roundId의 updateShare 항목 일괄 폐기
```

### D-1 만료 알림 [SPEC-UNDEFINED]

만료 하루 전 사용자에게 알림 발송 여부는 UX 결정이 필요하다. 발송 시 `UNNotificationRequest` 사용. 53-PERMISSIONS §6 알림 권한 활용 가능. 현재 구현 결정 보류.

---

## 6. 재시도 백오프 정책

### Exponential backoff 공식

```
delay(n) = min(2^n × 1.0s, 300s) × jitter(0.8, 1.2)
```

- `n`: `PendingOperation.retryCount` (0부터 시작)
- 최대 대기 시간: 300초 (5분)
- jitter: ±20% 균등 분포 (thundering herd 방지)

예: n=0 → 1.0s, n=3 → 8.0s, n=8 → 300s(cap).

### Type별 최대 재시도

| Type | 최대 재시도 | 누적 소요 시간 (cap 기준) | 비고 |
|------|-----------|----------------------|------|
| `createShare` | 8회 | 약 10분 | 사용자 의도 강함 |
| `updateShare` | 8회 | 약 10분 | 동일 |
| `uploadPhoto` | 5회 | 약 5분 | 대역폭 비용 고려 |
| `deleteShare` | 12회 | 약 30분 | 멱등 안전, 보안 중요 |
| `deletePhoto` | 12회 | 약 30분 | 동일 |

최대 재시도 초과 시 `lastError` 기록 + 항목 폐기 + 배너 알림.

### HTTP 상태별 분기

| HTTP 상태 / 조건 | 동작 |
|----------------|------|
| 401 | 즉시 폐기 + 배너 "편집 토큰이 만료되었습니다. 공유를 새로 생성해 주세요" |
| 410 | 즉시 폐기 + §5 트리거 3 흐름 (viewer 만료 nil 처리) |
| 413 | 즉시 폐기 + 배너 "사진 파일이 너무 큽니다 (최대 10MB)" |
| 429 | `Retry-After` 헤더값 우선 사용. 헤더 없으면 백오프 적용 |
| 5xx | 백오프 재시도 |
| 네트워크 오류 (URLError) | 백오프 재시도 |
| 200 / 201 / 204 | 성공 → `PendingOperation` 레코드 삭제 + 관련 Round 필드 업데이트 |

`deleteShare` / `deletePhoto`는 서버 측 멱등 처리 가능. `createShare`는 `Idempotency-Key` 헤더 활용 권장 (30-API §9.7).

---

## 7. 사용자 알림 정책

오프라인 관련 알림은 4채널로 분류한다. 채널 선택 기준: **사용자 주의를 얼마나 차단하는가**.

| 채널 | 지속 시간 | 사용 시나리오 | 햅틱 (13-HAPTICS §3) |
|------|---------|------------|---------------------|
| Toast (자동 2초) | 비차단 | "동기화됨" / "오프라인 — 로컬 저장" / "공유가 회수되었습니다" / "오프라인 — 복귀 시 공유" | 무음 |
| 배너 (액션 가능) | 비차단, 사용자 해제 | 영구 실패 — "공유 생성 실패. 다시 시도" / 401 editToken 만료 / 413 파일 너무 큼 | `.warning` |
| 모달 (차단) | 사용자 응답 필요 | CloudKit 충돌 (라운드 종료 후 점수 상이) — 단 1케이스 | `.warning` |
| 무알림 | — | silent merge / F6 재개 LWW / cold start nil 처리 / dedup 폐기 | 무음 |

모달은 1케이스에만 사용한다. 진행 중 / 재개 시 / 동일 점수 충돌은 모두 자동 처리하여 라운드 집중을 방해하지 않는다 (CLAUDE.md §PROJECT 절제·미니멀 원칙).

---

## 8. 시나리오별 종합 동작

**S1. 음영 지역 18홀 완주 → 클럽하우스 복귀**
오프라인 동안 모든 카운터 입력이 SwiftData 즉시 write (21-DATA_MODEL §3). 복귀 시 `NetworkMonitor: .offlineCellularOff → .online` 감지 → iOS 17 SwiftData 자동 sync → CloudKit push → Toast "동기화됨". 데이터 손실 없음, 사용자 개입 불필요.

**S2. 비행기 모드에서 viewer 생성 시도**
라운드 종료 후 "공유하기" 탭 시 상태가 `.offlineAirplane` → `PendingOperation(type: .createShare)` 적재 + Toast "오프라인 — 복귀 시 공유" + 라운드 상세에 "공유 대기 중" 배지 표시. 비행기 모드 해제 시 큐 drain → `POST /api/share 201` 성공 → 4개 필드 업데이트 → Toast "공유됨".

**S3. Watch만 온라인, iPhone 오프라인 (희박)**
Watch 입력이 WC `sendMessage` 실패 → `transferUserInfo` 큐잉 (22-STATE §5 fallback). iPhone 복귀 시 FIFO 큐 drain → SwiftData write → CloudKit push.

**S4. 사진 30장 일괄 업로드 중 단절**
완료된 사진은 `remoteURL` 업데이트 완료 상태 유지. 미완료 사진(`remoteURL == nil`)은 `PendingOperation(type: .uploadPhoto)` 적재. 복귀 시 우선순위 큐에서 `uploadPhoto`가 마지막에 처리됨.

**S5. 7일 만료 viewer 수정 시도**
`PUT /api/share/{shortId}` 또는 `POST /photos` 호출 → Cloudflare Worker 410 응답 → 4개 필드 즉시 nil + 배너 "공유가 만료되어 회수했습니다" + 해당 `roundId`의 `updateShare` / `uploadPhoto` 큐 항목 일괄 폐기 + "공유하기" 버튼 재활성화.

---

## 9. 책임 경계

| 문서 | 담당 영역 |
|------|----------|
| **본 문서** | NetworkMonitor, PendingOperation 큐, CloudKit 복구 위임 수신, viewer 만료 nil 트리거, 백오프, 알림 정책 |
| `20-ARCHITECTURE.md` | SyncCoordinator / OperationQueueProcessor actor 배치 위치 |
| `21-DATA_MODEL.md` | SwiftData @Model 스키마, viewer 4개 필드 원본 정의 |
| `22-STATE_MANAGEMENT.md` | @Observable ViewModel, WC 메시지 큐잉, 충돌 해결 알고리즘 |
| `30-API_SPEC.md` | 엔드포인트 계약, HTTP 에러 코드 (401/410/413/429 등) |
| `33-SECURITY.md` | Rate limit 상세, editToken 만료 시간, bcrypt cost factor |
| `53-PERMISSIONS.md` | UNNotification 권한 요청 (D-1 알림 발송 결정 시) |
| `11-COMPONENTS.md` | BannerNotice / Toast / 충돌 모달 컴포넌트 (후속 보완 TODO) |
| `13-HAPTICS_AND_MOTION.md` | 배너 / 모달 `.warning` 햅틱 이벤트 라우팅 |

---

## 10. [SPEC-UNDEFINED] 및 구현 제안

### [SPEC-UNDEFINED] 항목

| 항목 | 현황 | 본 문서 결정 또는 보류 |
|------|------|----------------------|
| PendingOperation CloudKit sync 여부 | spec_3.md 미정의 | **로컬 전용** — 디바이스별 큐 분리, 중복 실행 방지 |
| 오프라인 큐 최대 크기 | spec_3.md 미정의 | **500건 권장** — 초과 시 오래된 uploadPhoto부터 폐기 |
| BGAppRefreshTask 실행 간격 | spec_3.md 미정의 | **6시간 권장** (iOS 정책상 best-effort, 실행 보장 없음) |
| D-1 만료 알림 발송 여부 | spec_3.md 미정의 | **보류** — UX 결정 + 53-PERMISSIONS §6 알림 권한 확보 후 진행 |
| 충돌 모달 컴포넌트 디자인 | spec_3.md 미정의 | **11-COMPONENTS 후속 보완 TODO** |
| `.offlineAirplane` vs `.offlineCellularOff` 판별 로직 | spec_3.md 미정의 | 구현 단계에서 NWPath 인터페이스 분석으로 확정 |

### 구현 제안 (spec 외, 비규범)

본 섹션은 spec_3.md에 없는 구현 권장안이다. 실제 결정은 구현 단계에서 확정.

**OperationQueueProcessor drain 로직 핵심 패턴:**

```swift
actor OperationQueueProcessor {
    private var isDraining = false

    func drain(context: ModelContext) async {
        guard !isDraining else { return }
        isDraining = true
        defer { isDraining = false }
        for op in fetchPending(context: context) {  // 우선순위 + createdAt 정렬
            guard NetworkMonitor.shared.state.status == .online else { break }
            do {
                try await execute(op); context.delete(op); try context.save()
            } catch {
                op.retryCount += 1
                op.nextAttemptAt = Date.now.addingTimeInterval(
                    min(pow(2.0, Double(op.retryCount)), 300.0) * Double.random(in: 0.8...1.2)
                )
                if op.retryCount > maxRetry(for: op.type) {
                    notifyPermanentFailure(op); context.delete(op)
                }
                try? context.save()
            }
        }
    }
}
```

**상태 전환 트리거**: `SyncCoordinator`가 `withObservationTracking`으로 `NetworkMonitor.state.status`를 관찰하여 `.online` 전환 시 `OperationQueueProcessor.drain()` 호출.

---

*최종 업데이트: 2026-05-11*
