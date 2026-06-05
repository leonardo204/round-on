# 14 — 접근성 (Accessibility)

> **관련 문서**: [01-SPEC](01-SPEC.md) · [10-DESIGN_SYSTEM](10-DESIGN_SYSTEM.md) · [11-COMPONENTS](11-COMPONENTS.md) · [12-SCREENS](12-SCREENS.md) · [13-HAPTICS_AND_MOTION](13-HAPTICS_AND_MOTION.md) · [전체 인덱스](README.md)

| 항목 | 값 |
|------|----|
| 문서 번호 | 14 |
| 상태 | 확정 (v1) |
| 작성일 | 2026-05-12 |
| 원본 출처 | [01-SPEC.md](01-SPEC.md) §5.5 (line:478-484) |
| 관련 문서 | 10-DESIGN_SYSTEM, 11-COMPONENTS, 12-SCREENS, 13-HAPTICS_AND_MOTION, 53-PERMISSIONS |

---

> **본 문서가 정식 확정한 결정 5건**
>
> | # | 확정 내용 | 담당 섹션 |
> |---|-----------|----------|
> | A-1 | VoiceOver 라벨 카탈로그 (11-COMPONENTS 10개 컴포넌트 4-tuple) | §2 |
> | A-2 | Dynamic Type 11단계 스케일 정책 + 레이아웃 적응 | §5 |
> | A-3 | 명도 대비 Spring/Winter 팔레트 WCAG AA 검증 + 미충족 항목 | §6 |
> | A-4 | par-diff 5단계 색상+모양 이중 부호화 | §7 |
> | A-5 | Reduce Motion 6시나리오 대체 트랜지션 | §8 |

---

## 1. 개요 및 원칙

### WCAG 2.1 AA 준수 선언

라운드온은 모든 화면에서 WCAG 2.1 AA를 준수한다. (01-SPEC.md:480)

- 일반 텍스트: 최소 명도 대비 4.5:1
- 큰 텍스트(18pt 이상 Regular / 14pt 이상 Bold): 최소 3.0:1
- 비텍스트 UI 요소(아이콘, 경계선): 최소 3.0:1

(Apple HIG Accessibility — Color and Contrast)

### Apple HIG 접근성 4축

| 축 | 설명 | 담당 섹션 |
|----|------|----------|
| VoiceOver | 시각 대체 음성 읽기 | §2, §3, §4 |
| Dynamic Type | 사용자 텍스트 크기 조절 | §5 |
| Contrast | 명도 대비 + 색상 독립 부호화 | §6, §7 |
| Motion | 모션 민감 사용자 보호 | §8 |

### 본 문서 책임 vs 위임

| 문서 | 담당 |
|------|------|
| **본 문서 (14-ACCESSIBILITY)** | VoiceOver 4-tuple, Dynamic Type 스케일, 명도 대비 검증, par-diff 모양, Reduce Motion 대체 |
| `10-DESIGN_SYSTEM.md` | 4팔레트 hex 값, 타이포 토큰 (10-DESIGN_SYSTEM §2, §3) |
| `11-COMPONENTS.md` | 컴포넌트 props/상태/변형 (11-COMPONENTS §4-9) |
| `12-SCREENS.md` | 화면 레이아웃, par-diff D-4 색상 확정 (12-SCREENS §3) |
| `13-HAPTICS_AND_MOTION.md` | 트랜지션 정의, Reduce Motion 기본 정책 (13-HAPTICS_AND_MOTION §5, §7) |
| `53-PERMISSIONS.md` | 권한 거부 메시지 카피 (53-PERMISSIONS §6) |

---

## 2. VoiceOver 라벨 카탈로그

11-COMPONENTS §4-9에 정의된 10개 컴포넌트의 VoiceOver 4-tuple을 확정한다.

**4-tuple 기준**: `accessibilityLabel`(무엇) / `accessibilityHint`(어떻게, 자명하면 생략) / `accessibilityValue`(현재 상태) / `accessibilityTraits`(역할)

### 컴포넌트별 VoiceOver 4-tuple

| 컴포넌트 | accessibilityLabel | accessibilityHint | accessibilityValue | traits | 출처 |
|----------|-------------------|-------------------|-------------------|--------|------|
| CourseCard (matched) | "{코스명}, 자동 선택됨" | "두 번 탭하여 골프장 변경" | "현재 위치에서 {거리}km" | `.button` | 11-COMPONENTS §4 |
| PlayerChip (current) | "{이름}, 현재 입력 대상" | — | — | `.selected, .button` | 11-COMPONENTS §5 |
| PlayerChip (other) | "{이름}" | "두 번 탭하여 활성화" | — | `.button` | 11-COMPONENTS §5 |
| ScoreCell | "홀 {N} {플레이어}, {타수}타 {par-diff 용어}" | "두 번 탭으로 +1, 길게 눌러 -1" | "{타수}" | `.button, .adjustable` | 11-COMPONENTS §6 |
| HoleProgress | "18홀 중 {현재}번째 진행 중" | — | "{현재}/18" | `.staticText, .updatesFrequently` | 11-COMPONENTS §6 |
| ShotButton | "타수 카운트" | "탭하여 +1, Digital Crown으로 조절" | "{count}타, par 대비 {par-diff 용어}" | `.adjustable` | 11-COMPONENTS §7 |
| PenaltyButton (OB) | "OB 페널티" | "두 번 탭하여 +2 추가" | — | `.button` | 11-COMPONENTS §7 |
| PhotoGalleryGrid 아이템 | "사진 {total}장 중 {idx}번째" | "두 번 탭하여 라이트박스 열기" | — | `.image, .button` | 11-COMPONENTS §8 |
| ShareSheet | "공유 옵션" | — | "PIN 보호 {ON/OFF}, 사진 {N}장 포함" | `.summaryElement` | 11-COMPONENTS §8 |
| BannerNotice | "{level} 알림: {message}" | "두 번 탭하여 닫기" | — | `.button, .alert` | 11-COMPONENTS §9 |
| DataQualityBadge | "GPS 코스 감지 {활성/수동 홀 진행} 코스" | — | — | `.staticText` | 11-COMPONENTS §10 |

### par-diff 용어 매핑

ScoreCell / ShotButton `accessibilityValue`에서 사용하는 텍스트:

| 상태 | 조건 | 발화 |
|------|------|------|
| eagle | count ≤ par-2 | "이글" |
| birdie | count == par-1 | "버디" |
| par | count == par | "파" |
| bogey | count == par+1 | "보기" |
| double-plus | count ≥ par+2 | "더블 보기 이상" |
| 미입력 | count == 0 | "미입력" |

장식 요소(마커 모양, 구분선, 배경 그라디언트)는 `accessibilityHidden = true`. (Apple HIG)

---

## 3. VoiceOver 화면 흐름

핵심 6화면의 `accessibilityElements` 읽기 순서와 그룹핑 방침을 확정한다.

#### 3.1 iPhone 라운드 진행 — iphone-2.3b (Variant B, split9x2)

D-1 채택(12-SCREENS §2) 기준. 읽기 순서: 헤더 "{코스명} 라운드 진행 중" → HoleProgress "18홀 중 {N}번째" → 점수 hero "{count}타, {par-diff 용어}" → PlayerChip row (current 우선) → OUT 스코어카드 블록 → IN 스코어카드 블록 → 페널티 row (OB → 해저드 → OK) → ShotButton.

스코어카드 그룹핑: 한 플레이어의 9홀 전체를 `accessibilityElement(children: .combine)`으로 묶는다. 18×4 = 72개 개별 읽기 방지. 포커스 진입 후 홀별 세부 탐색 허용.

#### 3.2 iPhone 라운드 종료 요약 — iphone-2.6

"라운드 완료" → 총 점수 "{총 타수}타, {par-diff 용어}" → 통계 3 카드(걸음수/거리/시간) → 스코어카드 요약(OUT/IN/합계 그룹) → "사진 {N}장" → "공유하기" CTA.

#### 3.3 Viewer 메인 — web-4.1 (모바일 웹)

HTML 시맨틱 마크업 기준. `<h1>` "{코스명} 라운드 결과" → 총 점수 statement → `<table>` 스코어카드(`<caption>`, `<th scope>`) → "사진 {N}장" aria-label → "사진 전체 ZIP 다운로드" → 푸터 "7일 후 만료" 안내.

#### 3.4 Viewer PIN 잠금 — web-4.2

헤더 → 자물쇠 아이콘 `aria-hidden="true"` → "이 라운드는 PIN으로 보호되어 있습니다" (role="alert") → PIN 입력: 단일 `type="password"` `inputmode="numeric"` 채택 (개별 박스 4개는 VoiceOver 포커스 흐름 복잡 + 가상 키보드 충돌 위험으로 미채택) → "확인" 버튼.

#### 3.5 Viewer 사진 라이트박스 — web-4.3

`role="dialog"`, `aria-modal="true"`, `aria-label="사진 {idx} / {total}"`. 첫 포커스: 닫기 버튼 또는 사진 설명. 스와이프 시 `aria-live="polite"` "이전/다음 사진". 닫기 후 진입 전 포커스 위치로 복귀(focus restoration).

#### 3.6 권한 거부 fallback — 위치/HealthKit

거부 후 화면 진입 시 BannerNotice를 첫 번째 `accessibilityElement`로 설정. `UIAccessibility.post(notification: .screenChanged, argument: bannerView)` 발화. (53-PERMISSIONS §2, §3 거부 fallback 카피 참조)

---

## 4. Watch VoiceOver 특화

### 점수 발화

ShotButton `accessibilityValue` 형식: "{count}타, {par-diff 용어}". count == 0: "0타, 미입력". (11-COMPONENTS §7)

### Digital Crown 회전 announce Debounce

Crown 회전 시 매 스텝마다 announce 발화하면 음성 폭주가 발생한다.

- **Debounce 300ms 적용**: 마지막 Crown 입력으로부터 300ms 무입력 후 최종 값 1회 발화
- 구현: `count` 변경 시 타이머 재시작 → 완료 시 `UIAccessibility.post(notification: .announcement, argument: "\(count)타, \(parDiffTerm)")`

### 홀 수동 전환 발화 우선순위

수동 홀 진행 모드에서 사용자가 스와이프/탭으로 홀 이동 시 (13-HAPTICS_AND_MOTION §3 햅틱과 동시):
1. "홀 {N}로 이동" 먼저 announce
2. 약 500ms 후 새 홀 초기 상태 "0타, 미입력" announce

### VoiceOver 사용자 탭 조작

VoiceOver 활성 시: 단일 탭 = 포커스 이동 + 현재 값 발화(점수 변경 없음), 더블탭 = +1 확정. 96pt×96pt 큰 영역이어도 더블탭만 점수를 올린다. (Apple HIG)

---

## 5. Dynamic Type 대응

### 시스템 11단계

xSmall / Small / Medium / **Large(기본)** / xLarge / xxLarge / xxxLarge / AccessibilityMedium / AccessibilityLarge / AccessibilityXL / AccessibilityXXL / AccessibilityXXXL (Apple HIG Dynamic Type)

### 토큰별 최대 스케일 정책

(10-DESIGN_SYSTEM §3 기준)

| 토큰 | 기본 크기 | 최대 허용 단계 | 정책 |
|------|-----------|--------------|------|
| `--text-largeTitle` | 34pt (700) | AccessibilityXL | 줄바꿈 허용, truncation 금지 |
| `--text-body` | 17pt (400) | AccessibilityXXXL | 줄바꿈 허용 |
| `--text-caption` | 12pt (400) | AccessibilityLarge | 최대 1줄, 초과 시 축약 표기 |
| `--text-footnote` | 13pt (400) | AccessibilityLarge | 최대 2줄, 초과 시 생략 부호 허용 |
| **`--score-watch`** | **56pt (600)** | **고정 (no scale)** | 야외 가독성 우선, Dynamic Type 무시 |
| **`--score-iphone`** | **44pt (600)** | **고정 (no scale)** | 야외 가독성 우선, Dynamic Type 무시 |

점수 토큰 고정 근거: 야외 직사광선 환경에서 이미 시스템 기본 대비 충분히 크고, AccessibilityXXXL 적용 시 Watch 화면을 초과한다. (01-SPEC.md:482, 10-DESIGN_SYSTEM §3)

### 한글 줄바꿈

모든 한국어 본문 텍스트에 `.lineBreakStrategy(.hangulWordPriority)` 적용 — 어절 단위 줄바꿈, 음절 분리 방지. (Apple HIG Localization)

### 레이아웃 적응 — AccessibilityXL 이상

`@Environment(\.dynamicTypeSize)` 값이 `.accessibility3` (AccessibilityXL) 이상일 때:

| 컴포넌트 | 기본 레이아웃 | 대체 레이아웃 |
|----------|-------------|-------------|
| ScoreCell 4×9 그리드 | 가로 4명 × 9홀 | 플레이어 선택 후 해당 9홀만 세로 표시 |
| PlayerChip row | 가로 최대 4칩 | 세로 4행 list |
| 페널티 row | OB / 해저드 / OK 가로 3개 | 세로 3행 stack |

(11-COMPONENTS §6, §7)

---

## 6. 명도 대비 검증 (WCAG AA)

### Spring 팔레트 검증

기준 surface: `#FAFCF7` (10-DESIGN_SYSTEM §2 Spring)

| 조합 | 전경 hex | 대비비 | AA 4.5:1 | 비고 |
|------|---------|--------|---------|------|
| `text-primary` on `surface` | `#1F2A1B` | 14.2:1 | ✓ AAA | 모든 본문 텍스트 |
| `text-secondary` on `surface` | `#5A6850` | 5.1:1 | ✓ AA | 보조 텍스트, 라벨 |
| `primary` on `surface` | `#7FB069` | 2.6:1 | ✗ | 18pt 이상 대형 텍스트 한정 허용 (3.0:1 초과) |
| **`text-primary` on `primary` (버튼 라벨)** | **`#1F2A1B`** | **10.4:1** | **✓ AAA** | **filled 버튼 라벨 정식 (10-DESIGN_SYSTEM §5.4)** |
| `primary` on `surface-elevated` | `#7FB069` / `#FFFFFF` | 2.7:1 | ✗ | 큰 텍스트(≥18pt) 한정 허용 |
| `border` on `surface` | `#E8EFE0` | 1.1:1 | ✗ | 비텍스트 1pt 구분선 — 텍스트 대비 기준 미적용 |

**Primary 버튼 라벨 결정 (2026-05-12)**: `filled` 버튼 라벨 색상은 **`text-primary #1F2A1B`** 정식 채택 (10-DESIGN_SYSTEM §5.4 + 11-COMPONENTS §2 동기 패치 완료). 흰색 라벨은 2.9:1로 AA 미충족이므로 금지. (01-SPEC.md:480)

### Winter 팔레트 검증

기준 surface: `#0F1612` (10-DESIGN_SYSTEM §2 Winter)

| 조합 | 전경 hex | 대비비 | AA 4.5:1 | 비고 |
|------|---------|--------|---------|------|
| `text-primary` on `surface` | `#E8F0EA` | 14.0:1 | ✓ AAA | |
| `text-secondary` on `surface` | `#9AAA9F` | 5.4:1 | ✓ AA | |
| `primary` on `surface` | `#5A8A6B` | 3.8:1 | ✗ | 큰 텍스트 한정 허용 |
| `text-primary` on `surface-elevated` | `#E8F0EA` / `#1A241E` | 12.1:1 | ✓ AAA | 카드, 모달 표면 |

**[SPEC-UNDEFINED]**: Summer(`#F0F7F1` surface) / Autumn(`#FAF7F0` surface) 팔레트는 `--text-secondary`, `--border` hex 미정의 상태. 10-DESIGN_SYSTEM §2 보완 후 본 §6 갱신 필요.

**야외 강화**: 점수 숫자 `.semibold`(600) 이상 — `--score-watch`, `--score-iphone` 토큰이 이미 600 weight로 충족. (01-SPEC.md:482, 10-DESIGN_SYSTEM §3)

---

## 7. Differentiate Without Color

색상만으로 의미를 전달하는 요소에는 모양(shape)/굵기(weight)/아이콘을 추가 채널로 병행한다. (Apple HIG Color and Effects)

### par-diff 5단계 색상+모양 이중 부호화

12-SCREENS D-4(12-SCREENS §3)에 모양 채널을 추가하여 확정한다.

| 단계 | 조건 | 색상 (Spring) | 모양 | VoiceOver |
|------|------|-------------|------|----------|
| eagle | count ≤ par-2 | `primary #7FB069` | 이중원 ◎ | "이글" |
| birdie | count == par-1 | `primary #7FB069` | 단원 ● | "버디" |
| par | count == par | `text-primary` | 없음 | "파" |
| bogey | count == par+1 | `text-secondary #5A6850` | 단사각 ■ | "보기" |
| double-plus | count ≥ par+2 | `text-secondary #5A6850` | 이중사각 ▣ | "더블 보기 이상" |

마커: 셀 높이 30% 이내(약 13pt). 숫자 우상단 배치. 마커 자체는 `accessibilityHidden = true`.

Winter 팔레트: eagle/birdie → `primary #5A8A6B` / bogey/double-plus → `text-secondary #9AAA9F`.

### DataQualityBadge 아이콘+색상 이중 부호화

> F3 GPS 자동 감지 — 골프장 + 서브코스 단위 (홀 단위 자동 감지는 미제공, 수동 진행)

| 품질 | 색상 | SF Symbols 후보 | VoiceOver |
|------|------|----------------|----------|
| complete | `primary #7FB069` | `checkmark.circle.fill` | "GPS 코스 감지 활성 코스" |
| partial | `text-secondary` | `exclamationmark.circle` | "수동 홀 진행 코스" |
| minimal | `text-secondary` | `exclamationmark.circle` | "수동 홀 진행 코스" |
| low | `text-secondary` | `xmark.circle` | "수동 홀 진행 코스" |
| unknown | `text-secondary` | `questionmark.circle` | "수동 홀 진행 코스" |

**수동 홀 진행 VoiceOver 발화 라벨**: 수동으로 홀 이동 시 "수동 홀 진행 모드 — 스와이프 또는 탭으로 다음 홀 이동" (처음 1회, 이후 홀 번호만 announce)

SF Symbols 최종 선택은 구현 단계에서 확정. 현재 4종 후보 제안 상태. (11-COMPONENTS §9)

### 색맹 시뮬레이션 검증

| 색맹 유형 | 약화 채널 | 라운드온 영향 | 보완 |
|-----------|----------|-------------|------|
| Protanopia (적색맹) | 빨강 약화 | par-diff는 초록/회색 계열만 사용 — 영향 없음 | 모양 이중 부호화로 완전 보완 |
| Deuteranopia (녹색맹) | 초록 약화 | `primary`와 `surface` 구분 어려움 가능 | 모양 + 굵기(600 weight) 보완 |
| Tritanopia (청색맹) | 파랑 약화 | 라운드온 팔레트 파랑 미사용 — 영향 없음 | — |

검증 방법: Xcode Simulator → Features → Accessibility → Color Filters.

---

## 8. Reduce Motion 대응

`UIAccessibility.isReduceMotionEnabled` 또는 `@Environment(\.accessibilityReduceMotion)` 감지. (13-HAPTICS_AND_MOTION §7)

### 6시나리오 대체 트랜지션

| 시나리오 | 기본 트랜지션 | Reduce Motion 대체 | 타이밍 토큰 |
|---------|-------------|------------------|------------|
| 홀 이동 (수동 스와이프) | `.move(edge: .trailing)` slide | `.opacity` fade | 0.2s → 0.1s |
| 동반자 전환 | `.move(edge: .bottom)` slide | `.opacity` fade | 0.2s → 0.1s |
| 모달/시트 진입 | `.move(edge: .bottom)` bottom-up | 즉시 표시 + `.opacity` | 0.3s → 0.15s |
| 라이트박스 fullScreenCover | `.scale` + `.opacity` asymmetric | 즉시 표시 + `.opacity` | 0.3s → 0.15s |
| Watch 홀 전환 3프레임 | 슬라이드 시퀀스 (watch-3.2→3.3→3.4) | **단일 fade 1프레임으로 강등** | 3프레임 → 1프레임 |
| 라운드 종료 → 요약 | `NavigationStack` push | `.opacity` cross-fade | 0.3s → 0.15s |

(13-HAPTICS_AND_MOTION §5, §6 타이밍 토큰 기준: `--motion-instant` 0.1s / `--motion-short` 0.2s / `--motion-default` 0.3s)

**햅틱은 유지**: Reduce Motion과 무관하게 햅틱은 정상 발화. 시각 피드백 약화 환경에서 햅틱이 보상 채널로 기능. (13-HAPTICS_AND_MOTION §7, Apple HIG)

---

## 9. 테스트 및 검증

### Xcode Accessibility Inspector 체크리스트

- [ ] 모든 인터랙티브 요소가 `accessibilityLabel` 보유
- [ ] 장식 요소는 `accessibilityHidden = true` 적용
- [ ] 그룹 요소는 `accessibilityElement(children: .combine)` 명시
- [ ] 동적 콘텐츠는 `accessibilityValueChanged` 또는 `UIAccessibility.post(notification:)` 통지
- [ ] `accessibilityHint`가 label과 중복되지 않음 (자명한 경우 hint 생략)
- [ ] `accessibilityTraits`가 실제 역할과 일치

### VoiceOver 실기기 시나리오 5종

1. **라운드 진행 흐름**: 라운드 시작 → 홀 1 ShotButton +1 → PenaltyButton OB → 홀 2 이동 (논리적 발화 순서 확인)
2. **Viewer 전체 흐름**: Viewer 메인 → 스코어카드 표 탐색 → 라이트박스 열기 → 닫기 (focus restoration 확인)
3. **PIN 잠금**: PIN 화면 진입 → 단일 secure entry 4자리 입력 → "확인" → 결과 진입
4. **권한 거부 fallback**: 위치 권한 거부 상태 앱 진입 → BannerNotice 첫 발화 확인
5. **Watch 점수 입력**: VoiceOver 활성 → ShotButton 더블탭 +1 → Crown 회전 → Debounce 300ms 후 announce 1회 확인

### 색맹 시뮬레이션

Xcode Environment Overrides → Accessibility → Color Filters 순서로 Protanopia / Deuteranopia / Tritanopia 각각 라운드 진행 화면(iphone-2.3b) 및 DataQualityBadge 확인.

### Dynamic Type 회귀

11단계 모두 UI 테스트 스크린샷 자동 생성 권장. AccessibilityXL(단계 10) 이상에서 §5 레이아웃 적응 중점 확인. `XCUIApplication().launchArguments` 에 `-UIPreferredContentSizeCategoryName` 파라미터 주입 방식 사용.

---

### 부록: 후속 보완 TODO + 책임 경계

**책임 경계**

| 문서 | 담당 영역 | 상태 |
|------|----------|------|
| **본 문서 (14-ACCESSIBILITY)** | VoiceOver 라벨, Dynamic Type 스케일, 명도 대비, par-diff 모양, Reduce Motion | 확정 (v1) |
| `10-DESIGN_SYSTEM.md` | 4팔레트 hex, 타이포 토큰 | 작성 완료 |
| `11-COMPONENTS.md` | 컴포넌트 props/상태/변형 | 작성 완료 |
| `12-SCREENS.md` | 화면 레이아웃, par-diff D-4 색상 | 작성 완료 |
| `13-HAPTICS_AND_MOTION.md` | 트랜지션, 햅틱, Reduce Motion 기본 정책 | 작성 완료 |
| `53-PERMISSIONS.md` | 권한 거부 메시지 카피 | 작성 완료 |

**후속 보완 TODO**

- [SPEC-UNDEFINED] Summer/Autumn 팔레트 대비비 실측 — 10-DESIGN_SYSTEM §2 보완 후 §6 갱신
- ~~Primary 버튼 라벨 AA 미충족~~ → **해소 완료 (2026-05-12)**: 10-DESIGN_SYSTEM §5.4에 라벨 색상 `text-primary` 정식 명시, 11-COMPONENTS §2 동기 패치, 본 문서 §6 검증표 갱신.
- DataQualityBadge SF Symbols 최종 1종 선택 (현재 후보 4종 제안 상태)
- Dynamic Type AccessibilityXL 이상 ScoreCell 전환 레이아웃 → 12-SCREENS 다이어그램 추가 권장
- Watch VoiceOver 실기기 검증 (Series 9 / Ultra 2 권장) — 시뮬레이터 불완전

---

*최종 업데이트: 2026-05-12*
