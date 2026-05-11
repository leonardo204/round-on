# 13 — 햅틱 패턴 및 모션 (Haptics & Motion)

| 항목 | 값 |
|------|----|
| 문서 번호 | 13 |
| 제목 | 햅틱 패턴 및 모션 |
| 상태 | 확정 (v1) |
| 원본 출처 | spec_3.md §7.3, spec_3.md:100, spec_3.md:643, spec_3.md:908 |
| 최종 업데이트 | 2026-05-11 |
| 관련 문서 | 02-USER_FLOWS, 10-DESIGN_SYSTEM, 11-COMPONENTS, 20-ARCHITECTURE, 53-PERMISSIONS |

---

## 1. 개요 및 원칙

### 햅틱 철학

라운드온은 "절제·미니멀" 디자인 톤(CLAUDE.md §PROJECT)을 햅틱에도 동일하게 적용한다. 모든 진동은 사용자의 현재 인터랙션을 확인하는 피드백이어야 하며, 불필요한 알림이나 반복 패턴으로 주의를 분산시키지 않는다.

**3원칙**:

1. 의미 있는 이벤트에만 발화한다. 화면 스크롤, 일반 탭 탐색 등 탐색성 인터랙션에는 사용하지 않는다.
2. 강도는 이벤트 무게에 비례한다. 라운드 종료 > 홀 전환 > 카운터 입력 순으로 강도를 높인다.
3. 시각과 함께 발화한다. Haptic은 독립 알림이 아니라 시각 피드백의 동반 채널이다 (spec_3.md:908).

### 모션 철학

- Apple HIG "clarity" 원칙 준수: 트랜지션은 공간 관계를 명확히 전달하는 용도로만 사용
- 야외 가독성 우선 (spec_3.md §12): 장황한 애니메이션보다 즉각적인 상태 전달이 중요
- 본 문서가 결정하는 것: 햅틱 이벤트 매핑, 트랜지션 패턴, 타이밍 토큰, Reduce Motion 정책, Watch↔iPhone 동기화
- 본 문서가 위임받는 것: 정적 컬러/타이포 토큰(10-DESIGN_SYSTEM), 컴포넌트별 인터랙션 호출 지점(11-COMPONENTS), VoiceOver/Dynamic Type(14-ACCESSIBILITY 작성 예정)

---

## 2. 햅틱 API 카탈로그

### iOS (UIKit — SwiftUI에서 호출)

| 종류 | 클래스 | 강도 옵션 |
|------|--------|-----------|
| Impact | `UIImpactFeedbackGenerator` | `.light` / `.medium` / `.heavy` / `.soft` / `.rigid` |
| Notification | `UINotificationFeedbackGenerator` | `.success` / `.warning` / `.error` |
| Selection | `UISelectionFeedbackGenerator` | (단일, 값 변경 시) |

사용 패턴: `prepare()` 호출 후 즉시 `impactOccurred()` / `notificationOccurred(_:)` / `selectionChanged()` 순서로 실행한다. `prepare()`를 생략하면 첫 발화에 지연이 생길 수 있으므로 이벤트 예측 가능 시점에 미리 준비한다.

### watchOS (WatchKit)

`WKInterfaceDevice.current().play(_:)` 로 호출한다. 커스텀 패턴은 지원되지 않으며, 시스템 제공 `WKHapticType` 9종을 조합해 의미를 표현한다.

| WKHapticType | 의미 | 주요 사용처 |
|-------------|------|------------|
| `.click` | 짧은 기계적 클릭감 | 카운터 입력, 일반 확인 |
| `.start` | 시작 신호 | 라운드 시작, GPS 홀 자동 전환 |
| `.stop` | 종료 신호 | 라운드 종료 |
| `.success` | 성공 완료 | GPS 매칭 완료 |
| `.failure` | 실패/오류 | 권한 거부, 에러 |
| `.retry` | 재시도 요청 | 연결 재시도 (향후 확장) |
| `.notification` | 일반 알림 | 시스템 수준 공지 |
| `.directionUp` | 상향/강조 | OB 벌타 (강한 경고) |
| `.directionDown` | 하향 | 해저드 벌타 |

Crown 회전(홀 이동)의 햅틱은 SwiftUI `.digitalCrownRotation` modifier가 시스템 기본 피드백을 제공하므로 별도 커스텀은 불필요하다.

---

## 3. F1~F14 햅틱 매핑

spec_3.md §7.3의 10개 행을 전부 포함하고, 산재 명세(spec_3.md:100, :643, :908)와 본 문서 확장을 통합한다.

| 인터랙션 | Watch (WKHapticType) | iPhone (Generator) | 출처 | 비고 |
|---------|---------------------|-------------------|------|------|
| F4 카운터 +1 | `.click` | `.light` (Impact) | spec_3.md §7.3, spec_3.md:100 | 가벼운 진동 |
| F4 카운터 -1 (수정) | `.click` (단일) | `.light` (Impact) | spec_3.md §7.3 | "다른 톤" 처리 방침은 §9 참조 |
| F4 OB +2 | `.directionUp` | `.warning` (Notification) | spec_3.md §7.3 | 강한 경고 진동 |
| F4 해저드 +1 | `.click × 2` | `.medium` (Impact) | spec_3.md §7.3 | 더블 클릭 패턴 + 시각 강조(컴포넌트 색상 변화) 권장 |
| F4 OK +1 | `.success` | `.success` (Notification) | spec_3.md §7.3 | 짧은 성공음 |
| F3 GPS 홀 자동 전환 | `.start` + 시각 토스트 | `.success` (Notification) | spec_3.md §7.3, spec_3.md:643 | 토스트로 시각 보완; "다른 톤의 click" = `.start` 로 해석 |
| F4 수동 홀 전환 (스와이프) | `.directionUp` / `.directionDown` | `.light × 2` (Impact) | spec_3.md §7.3, spec_3.md:100 | 방향별 구분; "홀 전환 시 더블 진동" |
| F2 동반자 전환 | `.click × 2` | `.selection` (Selection) | spec_3.md §7.3 | Watch 더블 클릭 + 동반자 칩 하이라이트로 시각 구분 (해저드와 동일 패턴 회피) |
| F3 GPS 매칭 완료 | `.success` | `.success` (Notification) | spec_3.md §7.3 | 골프장 자동 선택 확인 |
| F5 라운드 종료 | `.stop` | `.success` (Notification) | spec_3.md §7.3 | 양쪽 동시 발화 (§4 참조); "길게" = `.stop` |
| F5 권한 거부 / 에러 | `.failure` | `.error` (Notification) | 본 문서 확장 | spec 명세 없음 |
| F9 viewer 공유 완료 | (Watch 미참여) | `.success` (Notification) | 본 문서 확장 | ShareSheet 닫힘 시점 |
| F11 사진 첨부 | (Watch 미참여) | `.light` (Impact) | 본 문서 확장 | 갤러리 선택 완료 |
| F12 viewer 만료 안내 | (Watch 미참여) | `.warning` (Notification) | 본 문서 확장 | 410 응답 수신 시 |

### 매핑 테이블 설명

- **Watch 미참여**: iPhone 전용 기능(사진 첨부, viewer 공유, 만료 안내)은 Watch에 대응 이벤트가 없다.
- **`× 2` 표기**: 동일 WKHapticType을 짧은 간격(약 100ms)으로 2회 연속 발화함을 의미한다.
- **"본 문서 확장"**: spec_3.md에 명시되지 않은 항목으로, 구현 단계에서 팀 합의 후 조정 가능하다.
- **iPhone `.light × 2`**: `UIImpactFeedbackGenerator` `.light` 를 약 80ms 간격으로 2회 발화한다. SwiftUI에서는 `Task { impactOccurred(); try? await Task.sleep(nanoseconds: 80_000_000); impactOccurred() }` 패턴을 사용한다.

---

## 4. Watch — iPhone 동기화 정책

Haptic 동기화 원칙: 시각과 진동을 함께 발화하되(spec_3.md:908), 동일 이벤트가 양쪽에서 중복 발화되어 사용자를 혼란스럽게 하지 않는다.

| 케이스 | Watch 햅틱 | iPhone 햅틱 | 정책 |
|--------|-----------|-------------|------|
| 입력 발생 디바이스만 (F4 카운터 +1/-1, 벌타) | Watch에서 입력 시 Watch만 | iPhone에서 입력 시 iPhone만 | 중복 발화 회피; 상대 디바이스는 UI 업데이트만 수신 |
| 양쪽 동시 발화 (F3 GPS 홀 자동 전환, F5 라운드 종료) | `.start` / `.stop` | `.success` (Notification) | 사용자가 어느 디바이스를 보고 있어도 이벤트를 인지 가능 (spec_3.md:908) |
| Watch 미연결 — iPhone 단독 모드 | 없음 | 모든 햅틱을 iPhone이 자체 발화 | 폴백 처리; 플로우 분기는 `02-USER_FLOWS F-B` 참조 |
| Reduce Motion + 무음 모드 동시 활성 | 없음 | 없음 | 시각 피드백(토스트, 배지)만 동작 |

WatchConnectivity 메시지 전달 지연이 있을 경우 햅틱은 먼저 발화하고, UI 동기화가 이후에 따라온다. 햅틱 발화를 동기화 완료 응답에 의존시키지 않는다.

---

## 5. 트랜지션 및 화면 전환

### SwiftUI 트랜지션 카탈로그

| API | 설명 | 기본 방향 |
|-----|------|----------|
| `.transition(.opacity)` | 페이드 인/아웃 | — |
| `.transition(.move(edge:))` | 슬라이드 (push/pop) | `.leading` / `.trailing` / `.bottom` |
| `.transition(.scale)` | 확대·축소 (모달 등장) | 중심 기준 |
| `.transition(.asymmetric(insertion:removal:))` | 등장·퇴장 별도 지정 | 각각 독립 |

### 화면 전환 패턴

| 시나리오 | SwiftUI API | 트랜지션 | 타이밍 토큰 |
|---------|-----------|---------|------------|
| 홀 → 다음 홀 (수동 스와이프) | `TabView(.page)` | slide (leading/trailing) | `--motion-short` |
| 동반자 전환 (상/하 스와이프) | `TabView(.page)` | slide (top/bottom) | `--motion-short` |
| 라운드 종료 → 요약 화면 | `NavigationStack` push | push (trailing) | `--motion-default` |
| 요약 → 공유 옵션 | `.sheet(isPresented:)` | sheet bottom-up | `--motion-default` |
| 사진 라이트박스 | `.fullScreenCover` | scale + fade (asymmetric) | `--motion-default` (시스템 기본 fade, 커스텀 modal 사용 시에만 asymmetric 적용 가능) |
| GPS 홀 자동 전환 토스트 | `ZStack` overlay | opacity | `--motion-instant` |
| 권한 요청 다이얼로그 | iOS 시스템 | 시스템 기본 | — |
| 에러/확인 알림 | `.alert(isPresented:)` | 시스템 기본 | — |

### Watch 트랜지션

watchOS 10+에서 `TabView(.page)` 제스처 전환은 시스템 기본 슬라이드를 사용한다. 커스텀 트랜지션은 Watch에서 권장하지 않으며, 햅틱으로 전환 의미를 보완한다.

Watch 화면 크기(41mm/45mm/49mm)의 제약상 트랜지션 지속 시간을 길게 설정하면 사용성이 저하된다. `--motion-short` (0.2s) 이하로 유지하는 것을 원칙으로 한다.

---

## 6. 타이밍 토큰

10-DESIGN_SYSTEM §7의 위임을 수신하여 본 문서가 모션 토큰을 정의한다. 이징은 `easeInOut`을 기본으로 하며, 강조 트랜지션에는 `easeOut`을 사용한다.

| 토큰 | 값 | 이징 | 사용 케이스 |
|------|-----|------|------------|
| `--motion-instant` | 0.1s | easeOut | 햅틱과 동기 시각 피드백, 토스트 등장 |
| `--motion-short` | 0.2s | easeInOut | 페이지 전환, 동반자 전환, 카운터 숫자 업데이트 |
| `--motion-default` | 0.3s | easeInOut | 모달, 시트, 일반 트랜지션 |
| `--motion-slow` | 0.5s | easeOut | 강조 트랜지션 (라운드 종료 요약 화면 등장) |

SwiftUI 적용 예시 — `withAnimation(.easeInOut(duration: 0.2))` 형태로 인라인 사용하거나, 토큰 값을 상수로 정의하여 일관성을 유지한다.

---

## 7. Reduce Motion 및 접근성

### Reduce Motion 감지

```swift
UIAccessibility.isReduceMotionEnabled
```

`@Environment(\.accessibilityReduceMotion)` SwiftUI 환경 변수로도 읽을 수 있다.

### 적용 방침

| 대상 | Reduce Motion OFF (기본) | Reduce Motion ON |
|------|------------------------|-----------------|
| 페이지 전환 (slide, scale) | 정상 트랜지션 | `.opacity` 페이드로 강등 |
| 토스트 등장/소멸 | opacity + scale | opacity만 |
| 라운드 종료 강조 트랜지션 | `--motion-slow` easeOut | `--motion-instant` opacity |
| 햅틱 | 정상 발화 | 정상 발화 (접근성 별개 채널, Apple HIG 준수) |

햅틱은 Reduce Motion과 무관하게 동작한다. Reduce Motion은 시각 모션에 민감한 사용자를 위한 설정이며, 진동 피드백은 별도 채널이다. 진동을 원하지 않는 사용자는 기기 진동 설정(Haptics)으로 개별 제어한다.

### Differentiate Without Color

par 대비 색상 클래스(언더파/이븐파/오버파)에 패턴·굵기 보완은 10-DESIGN_SYSTEM에 위임한다. 상세 내용은 14-ACCESSIBILITY(작성 예정)에서 다룬다.

---

## 8. 책임 경계

| 문서 | 담당 영역 |
|------|----------|
| **본 문서 (13-HAPTICS_AND_MOTION)** | 햅틱 이벤트 매핑, 트랜지션 패턴, 타이밍 토큰, Reduce Motion 정책, Watch↔iPhone 동기화 |
| `10-DESIGN_SYSTEM.md` | 정적 토큰 (컬러, 타이포, 간격, 그림자) — 모션 토큰은 본 문서에 위임 |
| `11-COMPONENTS.md` | 각 컴포넌트의 인터랙션 정의 (HapticEngine.Event 호출 지점만 표기) |
| `02-USER_FLOWS.md` | 플로우 단계별 화면 전환 흐름 (햅틱 디테일은 본 문서 참조) |
| `20-ARCHITECTURE.md` | HapticEngine 모듈 위치 (Shared 타깃) 및 WatchConnectivity 세션 관리 |
| `53-PERMISSIONS.md` | 권한 요청 시점 및 거부 플로우 (햅틱 발화 지점만 본 문서에서 정의) |
| `14-ACCESSIBILITY.md` (작성 예정) | VoiceOver, Dynamic Type, Differentiate Without Color 상세 — Reduce Motion 크로스 레퍼런스 포함 |

---

## 9. 미정의 항목 및 구현 가이드

### 미정의 항목 처리

**spec §7.3 "다른 톤의 click" (−1 수정)**

spec_3.md §7.3은 −1 수정 햅틱을 "`.click` (다른 톤)"으로 표기하나 WKHapticType은 톤 변형을 지원하지 않는다. 본 문서는 다음 방침으로 처리한다.

- Watch: `.click` 단일 발화 (기본과 동일). 시각 피드백(숫자 감소 + 색상 변화)으로 의미를 구분한다.
- iPhone: `.light` (Impact) 동일. 숫자 감소 애니메이션으로 보완.

시각 구분이 부족하다고 판단되면 구현 단계에서 −1에 짧은 `delay` 후 `.click × 2` 더블 패턴으로 변경을 검토할 수 있다. 최종 결정은 구현 단계에서 확정한다.

**spec §7.3 "홀 수동 전환 `.directionUp/Down`"**

좌→우 스와이프(다음 홀)는 `.directionUp`, 우→좌 스와이프(이전 홀)는 `.directionDown`으로 매핑한다. spec_3.md:100의 "홀 전환 시 더블 진동"은 iPhone 측 `.light × 2` 연속 발화로 구현한다.

**Crown 회전 커스텀 햅틱**

`.digitalCrownRotation` modifier의 `feedback` 파라미터(watchOS 9+)가 시스템 기본 피드백을 제공하므로 별도 커스텀은 불필요하다.

**F9 ShareSheet 닫힘 햅틱**

spec 명세 없음. 본 문서가 `.success` (Notification)으로 확장 정의한다. ShareSheet `.onDismiss` 콜백 시점에 발화한다.

### 구현 가이드 (비규범)

본 섹션은 spec_3.md에 없는 구현 권장안이며, 실제 결정은 구현 단계에서 확정한다.

```swift
// Shared 타깃에 HapticEngine 액터로 정의 (20-ARCHITECTURE §9 참조)
actor HapticEngine {
    static let shared = HapticEngine()

    enum Event {
        case shotIncrement       // F4 +1
        case shotDecrement       // F4 -1
        case penaltyOB           // F4 OB +2
        case penaltyHazard       // F4 해저드 +1
        case penaltyOK           // F4 OK +1
        case holeAutoChange      // F3 GPS 자동 전환
        case holeManualChange    // F4 수동 스와이프
        case playerSwitch        // F2 동반자 전환
        case gpsMatchComplete    // F3 GPS 매칭 완료
        case roundStart          // F5 라운드 시작
        case roundEnd            // F5 라운드 종료
        case shareSuccess        // F9 viewer 공유 완료
        case shareError          // F9 공유 실패
        case photoAttach         // F11 사진 첨부
        case viewerExpired       // F12 viewer 만료 (iPhone only, Watch 미참여)
        case permissionDenied    // F5 권한 거부
    }

    func play(_ event: Event) async { /* §3 매핑 호출 */ }
}
```

HapticEngine은 플랫폼 조건부 컴파일(`#if os(watchOS)` / `#if os(iOS)`)로 각 플랫폼 API를 분기한다. Watch 미연결 시 iPhone 단독 모드에서는 모든 이벤트를 iPhone API로 발화한다.

---

## 10. 부록 — 변경 이력 및 후속 문서

### 변경 이력

| 버전 | 날짜 | 내용 |
|------|------|------|
| v1 | 2026-05-11 | 최초 작성. spec_3.md §7.3 전체 통합 + 산재 명세 (:100/:643/:908) 반영 |

### 후속 작업

- **14-ACCESSIBILITY.md** 작성 시 §7 Reduce Motion 항목과 크로스 레퍼런스 추가
- **11-COMPONENTS.md** 업데이트 시 각 컴포넌트에 `HapticEngine.Event` 호출 지점 표기 권장 (선택)
- **20-ARCHITECTURE.md** HapticEngine 모듈 배치 및 WatchConnectivity 이벤트 라우팅 구체화 필요
- spec §7.3 "다른 톤의 click" 최종 결정 후 §3 매핑 테이블 업데이트
- 실기기 테스트 후 `× 2` 연속 발화 간격(80-100ms)을 사용성에 맞게 미세 조정

### 관련 PR / 이슈 추적

구현 시 `HapticEngine` PR에 본 문서 §9 구현 가이드를 수용 기준으로 포함할 것을 권장한다. 변경이 생기면 본 문서 §3 매핑 테이블과 §10 변경 이력을 동시에 업데이트한다.

---

*최종 업데이트: 2026-05-11*
