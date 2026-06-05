# 10 — 디자인 시스템 (Design System)

> **관련 문서**: [01-SPEC](01-SPEC.md) · [11-COMPONENTS](11-COMPONENTS.md) · [12-SCREENS](12-SCREENS.md) · [13-HAPTICS_AND_MOTION](13-HAPTICS_AND_MOTION.md) · [14-ACCESSIBILITY](14-ACCESSIBILITY.md) · [전체 인덱스](README.md)

> **작성일**: 2026-05-11
> **버전**: v4 기반
> **출처 명세서**: [기능 명세서 v4](01-SPEC.md) §5 (01-SPEC.md:385-483)

---

## 1. 디자인 원칙

라운드온의 시각 언어는 다음 4가지 지침을 동시에 따른다. (01-SPEC.md:387-394)

- **컨셉**: simple, 4계절의 그린(잔디) 느낌, 세련, 컴포넌트 절제 (01-SPEC.md:390)
- **Apple HIG**: clarity(명확성), deference(존중), depth(깊이) 세 원칙 준수 (01-SPEC.md:392)
- **Material Design 3**: Material You 기조의 표현적(expressive) 구성 참조 (01-SPEC.md:393)
- **Anthropic Frontend Design Skill**: intentional aesthetic, distinctive choices — 의도된 심미와 차별화된 선택 (01-SPEC.md:394)

> 목업: Google Stitch로 생성 예정 (01-SPEC.md:389). 본 문서 범위 외.

---

## 2. 컬러 팔레트 — 사계절 그린

앱 테마는 4계절 이름을 딴 4개 팔레트로 구성된다. 시스템 외관 설정에 따른 디폴트 매핑: 시스템 라이트 → Spring, 시스템 다크 → Winter. 설정 화면에서 4계절 수동 선택 가능. (01-SPEC.md:440)

### Spring — 봄 (라이트 디폴트)

시스템 라이트 모드의 기본 팔레트. (01-SPEC.md:398-408)

| 토큰 | Hex |
|------|-----|
| `--green-primary` | `#7FB069` |
| `--green-secondary` | `#B8D8B0` |
| `--green-accent` | `#C5E1A5` |
| `--surface` | `#FAFCF7` |
| `--surface-elevated` | `#FFFFFF` |
| `--text-primary` | `#1F2A1B` |
| `--text-secondary` | `#5A6850` |
| `--border` | `#E8EFE0` |

### Summer — 여름 (비비드)

선명한 색감의 선택 팔레트. (01-SPEC.md:410-417)

> 미정의 토큰 3종(`--surface-elevated`, `--text-secondary`, `--border`) — 부록 후속 보완 TODO 참조.

| 토큰 | Hex |
|------|-----|
| `--green-primary` | `#2D7A3E` |
| `--green-secondary` | `#4CAF50` |
| `--green-accent` | `#66BB6A` |
| `--surface` | `#F0F7F1` |
| `--surface-elevated` | — (spec 미정의) |
| `--text-primary` | `#0E2913` |
| `--text-secondary` | — (spec 미정의) |
| `--border` | — (spec 미정의) |

### Autumn — 가을 (따뜻한 톤)

따뜻한 황록 계열의 선택 팔레트. (01-SPEC.md:419-426)

> 미정의 토큰 3종(`--surface-elevated`, `--text-secondary`, `--border`) — 부록 후속 보완 TODO 참조.

| 토큰 | Hex |
|------|-----|
| `--green-primary` | `#6B7F3E` |
| `--green-secondary` | `#C4A04A` |
| `--green-accent` | `#D4B574` |
| `--surface` | `#FAF7F0` |
| `--surface-elevated` | — (spec 미정의) |
| `--text-primary` | `#2A2515` |
| `--text-secondary` | — (spec 미정의) |
| `--border` | — (spec 미정의) |

### Winter — 겨울 (다크 디폴트)

시스템 다크 모드의 기본 팔레트. (01-SPEC.md:428-438)

| 토큰 | Hex |
|------|-----|
| `--green-primary` | `#5A8A6B` |
| `--green-secondary` | `#2A3F35` |
| `--green-accent` | `#8FB5A0` |
| `--surface` | `#0F1612` |
| `--surface-elevated` | `#1A241E` |
| `--text-primary` | `#E8F0EA` |
| `--text-secondary` | `#9AAA9F` |
| `--border` | `#2A3530` |

---

## 3. 타이포그래피

### 폰트 패밀리

| 용도 | iOS | Web viewer |
|------|-----|------------|
| 제목·디스플레이 | SF Pro Display | Pretendard 또는 시스템 sans-serif |
| 본문 | SF Pro Text | Pretendard 또는 시스템 sans-serif |
| 고정폭 | SF Mono | — |

(01-SPEC.md:444-447, 465)

### iOS HIG 사이즈 스케일

(01-SPEC.md:449-458)

| 토큰 | 크기 | 굵기 |
|------|------|------|
| `--text-largeTitle` | 34pt | 700 |
| `--text-title1` | 28pt | 700 |
| `--text-title2` | 22pt | 600 |
| `--text-headline` | 17pt | 600 |
| `--text-body` | 17pt | 400 |
| `--text-callout` | 16pt | 400 |
| `--text-subhead` | 15pt | 500 |
| `--text-footnote` | 13pt | 400 |
| `--text-caption` | 12pt | 400 |

### 점수 디스플레이 토큰

라운드온의 핵심 기능인 F4 "0에서 시작" 카운터(CLAUDE.md §PROJECT)에서 점수 숫자를 크게 표시하기 위한 전용 토큰. (01-SPEC.md:460-462)

| 토큰 | 크기 | 굵기 | 사용 위치 |
|------|------|------|---------|
| `--score-watch` | 56pt | 600 | Apple Watch 메인 카운터 화면 |
| `--score-iphone` | 44pt | 600 | iPhone 점수 입력 화면 |

Apple Watch에서는 SF Compact 서체가 자동 적용된다 (Apple HIG Watch 타이포그래피 정책). Watch별 컴포넌트 세부 레이아웃은 `11-COMPONENTS.md`(작성 예정)에 위임한다.

---

## 4. 간격 / 8pt 그리드

라운드온은 8pt 그리드를 기준 단위로 사용한다. (01-SPEC.md:474, CLAUDE.md §PROJECT)

### 간격 토큰

아래 xs–xl 레이블 매핑은 구현 제안이며, 01-SPEC.md에는 수치만 명시되어 있다.

| 토큰 (구현 제안) | 수치 | 레이블 |
|----------------|------|--------|
| `--space-xs` | 8pt | xs |
| `--space-sm` | 16pt | sm |
| `--space-md` | 24pt | md |
| `--space-lg` | 32pt | lg |
| `--space-xl` | 48pt | xl |

화면 좌우 패딩, 카드 내부 패딩 등 컴포넌트별 간격 규약은 `11-COMPONENTS.md`(작성 예정)에 위임한다.

---

## 5. 라운드 모서리 / 그림자 / 테두리

(01-SPEC.md:469-472)

### 라운드 모서리

| 토큰 | 수치 |
|------|------|
| `--radius-sm` | 8pt |
| `--radius-md` | 12pt |
| `--radius-lg` | 16pt |

### 그림자

최소 원칙을 따르며 1–2단계만 사용한다. (01-SPEC.md:469) 그림자 offset / blur / opacity 정확한 수치는 `11-COMPONENTS.md`(작성 예정)에 위임한다.

### 테두리

- 두께: 1pt (01-SPEC.md:470)
- 색상: `--border` 토큰 (팔레트별 정의 §2 참조)

### 아이콘 / 버튼

- 아이콘: SF Symbols `.regular` 두께 사용 (01-SPEC.md:472)
- 버튼 변형: filled / tinted / plain 3종류만 허용 (01-SPEC.md:473)

#### 버튼 라벨 색상 (14-ACCESSIBILITY §6 AA 해소)

| 변형 | 배경 | 라벨 색상 | 대비비 (Spring) | 비고 |
|------|------|----------|---------------|------|
| filled (Primary CTA) | `--green-primary` `#7FB069` | **`--text-primary` `#1F2A1B`** | 10.4:1 ✓ AAA | 흰색 라벨은 AA 미충족(2.9:1)으로 미채택 |
| tinted (Secondary) | `--green-accent` `#C5E1A5` 또는 surface-elevated | `--text-primary` | 13:1 이상 | — |
| plain (Tertiary) | transparent | `--green-primary` `#7FB069` (큰 텍스트 ≥18pt) 또는 `--text-primary` | 큰 텍스트만 3:1 충족 | — |

**규칙**: filled Primary 버튼은 검은색-그린 톤(`#1F2A1B`)을 라벨로 사용한다. 흰색 라벨 금지.

---

## 6. 야외 가독성

골프장 야외 환경에서의 가독성 확보를 위한 필수 요건이다. (01-SPEC.md:478-483)

- 모든 화면에서 **최소 4.5:1 명도 대비** 확보 (WCAG AA 기준) (01-SPEC.md:480)
- 라운드 시작 시 "밝기 최대 권장" 안내를 한 번 표시한다 (01-SPEC.md:481)
- 점수 숫자는 항상 `weight: .semibold` 이상으로 표시한다 (01-SPEC.md:482)

Dynamic Type 지원 및 VoiceOver 명도 대비 상세 규정은 `14-ACCESSIBILITY.md`(작성 예정)에 위임한다.

---

## 7. 책임 경계

본 문서(10-DESIGN_SYSTEM)가 정의하는 범위와 후속 문서 위임 범위를 명확히 구분한다.

| 문서 | 범위 |
|------|------|
| **본 문서 (10)** | 정적 토큰 전체 — 4계절 컬러 팔레트, 타이포그래피 스케일, 간격 그리드, radius/그림자/테두리 기준 |
| `11-COMPONENTS.md` (작성 예정) | 컴포넌트 변형/상태/props, 그림자 단계 수치(offset/blur/opacity), 패딩 규약, CourseCard·ShotButton 등 핵심 컴포넌트 |
| `12-SCREENS.md` (작성 예정) | 화면 단위 토큰 적용 예시, 실제 레이아웃 모형 |
| `13-HAPTICS_AND_MOTION.md` (작성 예정) | 모션/트랜지션/햅틱 패턴 — 본 문서는 정적 토큰만 다루며 애니메이션 정의 없음 |
| `14-ACCESSIBILITY.md` (작성 예정) | VoiceOver 레이블, Dynamic Type 대응, 명도 대비 심화 |

---

## 8. 구현 제안 (spec 외) — SwiftUI Asset Catalog 매핑

본 섹션은 `01-SPEC.md`에 없는 구현 권장안이며, 실제 Asset 이름은 구현 시점 결정. 본 문서가 명세화하지 않는다.

### CSS 변수 → SwiftUI Asset Catalog 매핑 제안

| CSS 변수명 | SwiftUI 확장 | Asset Catalog 이름 |
|-----------|------------|-------------------|
| `--green-primary` | `Color.accent` | `AccentPrimary` |
| `--surface` | `Color.surface` | `Surface` |
| `--surface-elevated` | `Color.surfaceElevated` | `SurfaceElevated` |
| `--text-primary` | `Color.textPrimary` | `TextPrimary` |
| `--text-secondary` | `Color.textSecondary` | `TextSecondary` |
| `--border` | `Color.border` | `Border` |

### Color Set 라이트/다크 매핑

- Asset Catalog Appearances: Light → Spring 팔레트, Dark → Winter 팔레트
- Summer / Autumn 팔레트는 `@AppStorage("themeSeason")` 등의 사용자 선택 값으로 런타임 교체하는 방식을 권장한다 (구현 제안)

---

### 부록: 후속 보완 TODO / 본 문서 범위 외

다음 항목은 본 문서 작성 시점에 `01-SPEC.md`에 정의되지 않았거나 후속 문서에 위임된 내용이다.

**spec 미정의 — 추후 정의 요청:**

- Summer 팔레트: `--surface-elevated`, `--text-secondary`, `--border` hex 값 미정의 (§2 Summer 표 참조)
- Autumn 팔레트: `--surface-elevated`, `--text-secondary`, `--border` hex 값 미정의 (§2 Autumn 표 참조)

**후속 문서 위임:**

- 그림자 정확한 수치 (offset / blur / opacity) — `11-COMPONENTS.md`
- 모션 / 트랜지션 / 햅틱 정의 — `13-HAPTICS_AND_MOTION.md`
- VoiceOver 레이블, Dynamic Type 대응 규정 — `14-ACCESSIBILITY.md`

---

*최종 업데이트: 2026-05-11*
