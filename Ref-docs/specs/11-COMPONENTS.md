# 11 — 컴포넌트 카탈로그 (Components)

> **작성일**: 2026-05-11
> **버전**: v4 기반
> **출처**: [기능 명세서 v4](../golf-scorecard-app-spec_3.md) §5.4, §7, §F4 / [디자인 시스템](10-DESIGN_SYSTEM.md) / [CLAUDE.md §PROJECT]

---

## 1. 개요

라운드온(Round-On) iOS/watchOS 앱 컴포넌트의 props, 상태(State), 변형(Variant), 토큰 사용을 명세한다. 화면 단위 조합은 `12-SCREENS.md`(작성 예정)에 위임한다.

### 본 문서 책임 vs 위임

| 항목 | 담당 문서 |
|------|----------|
| 컴포넌트 props / 상태 / 변형 / 토큰 사용 | **본 문서 (11-COMPONENTS)** |
| 화면 단위 조합, ScoreCell 변형 선택 | `12-SCREENS.md` (작성 예정) |
| 햅틱 패턴, 트랜지션 | `13-HAPTICS_AND_MOTION.md` (작성 예정) |
| VoiceOver 레이블, Dynamic Type 상세 | `14-ACCESSIBILITY.md` (작성 예정) |
| Web viewer 측 DOM 컴포넌트 | `31-VIEWER_HTML.md` (작성 완료) |

### 컴포넌트 일람 (총 10종)

| # | 컴포넌트 | 플랫폼 | 기능 / 출처 |
|---|----------|--------|------------|
| 1 | `CourseCard` | iOS | F1 자동 매칭 (spec_3.md:57-62) |
| 2 | `PlayerChip` | 공통 | F2 동반자 입력 (spec_3.md:63-67) |
| 3 | `ScoreCell` | iOS | F4 그리드 셀 (spec_3.md:103-105) |
| 4 | `HoleProgress` | iOS | F4 홀 진행 표시 (spec_3.md:570) |
| 5 | `ShotButton` | Watch | F4 타수 카운터 (spec_3.md:75-90) |
| 6 | `PenaltyButton` | Watch | F4 벌타 입력 (spec_3.md:83-85) |
| 7 | `PhotoGalleryGrid` | iOS | F9 사진 첨부 (spec_3.md:134-138) |
| 8 | `ShareSheet` | iOS | F9 공유 옵션 (spec_3.md:130-142) |
| 9 | `BannerNotice` | 공통 | 시스템 안내 (20-ARCHITECTURE §7) |
| 10 | `DataQualityBadge` | iOS | F1/F3 분기 (CLAUDE.md §PROJECT) |
| 11 | `SubCourseSelector` | iOS | F3 서브코스 라벨 선택 (spec_3.md §F3, 21-DATA_MODEL §5) |

---

## 2. 공통 규약

모든 컴포넌트는 아래 패딩 토큰과 6단 구조 규약을 따른다. (spec_3.md §5.4)

### 패딩 토큰

| 용도 | 수치 | 토큰 |
|------|------|------|
| 화면 좌우 여백 / 카드 내부 / 버튼 수평 | 16pt | `--space-sm` |
| 버튼 수직 | 12pt | — (최소 44pt 터치 영역 충족) |
| 그리드 셀 간격 | 8pt | `--space-xs` |

**버튼 변형** (spec_3.md:473): `filled` Primary CTA / `tinted` Secondary / `plain` Tertiary

**버튼 라벨 색상 (10-DESIGN_SYSTEM §5.4 위임 수신, 14-ACCESSIBILITY §6 AA 해소)**:
- `filled` Primary: 배경 `--green-primary` + 라벨 **`--text-primary` `#1F2A1B`** (대비 10.4:1 AAA). 흰색 라벨 금지.
- `tinted`: 배경 `--green-accent` 또는 surface-elevated + 라벨 `--text-primary`
- `plain`: 라벨 `--green-primary` (≥18pt 큰 텍스트) 또는 `--text-primary`

**둥근 모서리** (10-DESIGN_SYSTEM §5): `--radius-sm` 8pt 카드 / `--radius-md` 12pt 모달 / `--radius-lg` 16pt 시트

### 6단 구조 규약

모든 컴포넌트 명세는 다음 순서를 따른다.

1. **플랫폼**: iOS / Watch / 공통
2. **용도**: 기능·화면 맥락
3. **props**: Swift 타입과 레이블
4. **상태**: default / disabled / loading / error 등 — **표시 전용은 "해당 없음"**
5. **변형**: 시각·기능적 변형 목록 — **표시 전용은 "해당 없음"**
6. **토큰 / 접근성 메모**: 토큰 목록 + 접근성 위임 참조

---

## 3. 그림자 단계 (Elevation)

spec_3.md:469 "최소 1–2단계" 수신. Apple HIG / Material 3 Level 1·2 정합.

| 토큰 | 용도 | y-offset | blur | opacity | 출처 |
|------|------|----------|------|---------|------|
| `--elevation-1` | 카드, 정적 표면 | 1pt | 2pt | 0.06 | 본 문서 |
| `--elevation-2` | 모달, 시트, 플로팅 | 4pt | 12pt | 0.10 | 본 문서 |

색상: `rgba(0, 0, 0, opacity)`. Winter 팔레트에서는 opacity를 0.02씩 감소 적용.

---

## 4. CourseCard

**플랫폼**: iOS

**용도**: F1 자동 골프장 매칭 결과 표시. 수동 변경 진입점. (spec_3.md:57-62)

**props**:
```swift
struct CourseCard: View {
    let course: GolfCourse           // 21-DATA_MODEL §5
    let isAutoMatched: Bool          // true: GPS 자동, false: 수동 선택
    let onChangeRequested: () -> Void // "변경" 버튼 액션 (SwiftUI onChange modifier와 네이밍 충돌 회피)
}
```

**상태**:
- `default`: 매칭 결과 표시 중
- `loading`: GPS fetch + DB 매칭 진행 중 — ProgressView 표시
- `error`: 반경 3km 이내 매칭 실패 — "골프장을 찾지 못했어요. 직접 검색하세요" 안내 + 검색 버튼

**변형**:
- `matched`: 자동 매칭됨 — "○○골프장 자동 선택됨" 뱃지 + "변경" 버튼 (`plain`)
- `manual`: 수동 선택됨 — 변경 버튼 없음 (이미 사용자 의사로 선택)

**holesCount / courseType 표시 변형**:
- `holesCount != nil`: 코스명 하단에 "{holesCount}홀" 표시
- `holesCount == nil`: 홀 수 미표시 (라운드 시작 시 사용자 입력 프롬프트로 처리)
- `courseType != nil`: 골프장명 옆에 courseType 배지 표시 (예: "CC", "GC")

**토큰 / 접근성 메모**:
- `--surface`, `--elevation-1`, `--radius-sm`
- 코스명: `--text-primary` / 세부 정보: `--text-secondary`
- 자동 선택 강조: `--green-accent`
- VoiceOver 레이블: "○○골프장 자동 선택됨, 변경하려면 두 번 탭" — 상세 규정은 `14-ACCESSIBILITY.md` 위임

---

## 5. PlayerChip

**플랫폼**: 공통 (iPhone + Watch)

**용도**: F2 동반자 별명 칩 표시. 현재 입력 대상 플레이어 강조 + 이름 수정 진입점. (spec_3.md:63-67)

**props**:
```swift
struct PlayerChip: View {
    let player: Player           // 21-DATA_MODEL
    let isCurrent: Bool          // 현재 입력 대상 표시
    let onTap: () -> Void
    let onEdit: (() -> Void)?    // 이름 수정 모달 (옵션)
}
```

**상태**:
- `default`: 입력 대상 아님 — 기본 배경
- `current`: 현재 입력 대상 — `--green-secondary` 강조 배경
- `disabled`: 라운드 종료 후 — 탭 비활성

**변형**:
- `editable`: iPhone에서 사용 — 탭 시 이름 수정 모달 진입 (`onEdit` 주입)
- `readonly`: Watch에서 사용 — 이름 표시 전용, 수정 불가

**토큰 / 접근성 메모**:
- `current` 상태: `--green-secondary` 배경
- `--surface-elevated`, `--text-primary`, `--radius-sm`
- 칩 최소 높이: 36pt (Watch는 시스템 기본 준수)

---

## 6. ScoreCell + HoleProgress

**플랫폼**: iOS

### ScoreCell

**용도**: F4 4인 × 18홀 스코어카드 그리드 셀. 탭 +1, 길게 누르기 -1. (spec_3.md:103-105)

**ScoreCell 변형 2종** (spec_3.md:206 양자 허용):

- `.horizontalScroll`: 4명 × 18홀 가로 스크롤 — 한 화면에 4–5홀 표시
- `.split9x2`: OUT(1-9) / IN(10-18) 2단 분리 — 9홀 블록을 상하로 배치

**변형 선택은 `12-SCREENS.md`에 위임. 본 문서는 두 변형 명세만 한다.**

**props**:
```swift
struct ScoreCell: View {
    let player: Player
    let holeNumber: Int
    let par: Int
    let count: Int               // 0이면 미입력
    let isCurrentHole: Bool
    let style: ScoreCellStyle    // .horizontalScroll / .split9x2
    let onTap: () -> Void        // +1
    let onLongPress: () -> Void  // -1 (spec_3.md:103-105)
}

enum ScoreCellStyle {
    case horizontalScroll
    case split9x2
}
```

**상태**:
- `empty`: count == 0, 미입력 상태 — 빈 셀 표시
- `filled`: count > 0 입력 완료
- `current`: isCurrentHole == true — 현재 홀 하이라이트
- `disabled`: 라운드 종료 후 — 탭/길게 누르기 비활성

**par 대비 색상 클래스** (10-DESIGN_SYSTEM §2): eagle(≤par-2) 진한 그린 원형 / birdie(par-1) 연한 그린 원형 / par 기본 / bogey(par+1) 연한 적색 / double-plus(≥par+2) 진한 적색

**셀 최소 크기**: `minWidth: 56pt`, `minHeight: 44pt` (터치 영역 보장)

**토큰**: `--text-primary`, `--green-primary`(eagle/birdie), `--surface`, `--space-xs`(셀 간격)

---

### HoleProgress

**용도**: 현재 홀 번호 / par / 진행률 가로 진행 바. 라운드 진행 화면 상단. (spec_3.md:570)

**상태**: 해당 없음 (표시 전용) / **변형**: 해당 없음 (표시 전용)

**토큰**: 진행 바 `--green-primary` / par 숫자 `--text-primary` `--text-headline` / 홀 번호 `--text-title2` / 트랙 `--border`

---

## 7. ShotButton + PenaltyButton

**플랫폼**: Watch (메인). Watch는 시스템 기본 SF Compact 자동 적용 (Apple HIG), 본 문서 별도 지정 없음.

### ShotButton

**용도**: F4 핵심 — "0에서 시작, 샷마다 +1" 카운터 큰 버튼. Watch 화면 대부분, 장갑 착용 시도 조작 가능. (spec_3.md:75-90)

**props**:
```swift
struct ShotButton: View {
    let count: Int                  // 0에서 시작 — 단방향 데이터 흐름 (부모가 콜백으로만 갱신)
    let par: Int
    let onIncrement: () -> Void     // 탭 또는 Crown 시계방향
    let onDecrement: () -> Void     // Crown 반시계방향
}
```

**상태**:
- `default`: 라운드 진행 중 — 탭/Crown 입력 활성
- `disabled`: 라운드 종료 후 — 입력 비활성

**변형**: 단일 (`.primary`)

**토큰 / 접근성 메모**:
- 점수 숫자: `--score-watch` (56pt / 600) — (10-DESIGN_SYSTEM §3 점수 토큰)
- par 대비 표시 (예: "+1"): `--text-secondary`, `--text-callout`
- 배경: `--green-primary`
- **터치 영역**: 96pt × 96pt (Watch 화면 대부분)

---

### PenaltyButton

**용도**: F4 OB / 해저드 / OK(컨시드) 벌타 입력. Watch 화면 하단 3개 배치. (spec_3.md:83-85)

**props**:
```swift
struct PenaltyButton: View {
    let type: PenaltyType
    let onTap: () -> Void
}

enum PenaltyType {
    case ob       // 카운트 변화 +2 (1벌타 + 1샷 재타). spec_3.md:83의 "1벌타"는 페널티 의미이고, 카운트는 1벌타+1샷=+2
    case hazard   // +1: 벌타만 (spec_3.md:84)
    case ok       // +1: 컨시드 (spec_3.md:85)
}
```

**상태**:
- `default`: 탭 가능
- `disabled`: 라운드 종료 후

**변형**: 3종 (PenaltyType별 라벨 + 카운트 변화)

| 변형 | 라벨 | 카운트 변화 |
|------|------|------------|
| `.ob` | "OB" | +2 |
| `.hazard` | "해저드" | +1 |
| `.ok` | "OK" | +1 |

**토큰 / 접근성 메모**:
- 버튼 스타일: `tinted`
- 배경: `--green-secondary`
- 햅틱 패턴은 `13-HAPTICS_AND_MOTION.md` 위임

---

## 8. PhotoGalleryGrid + ShareSheet

### PhotoGalleryGrid

**플랫폼**: iOS

**용도**: F9 라운드 중/후 사진 첨부 + 그리드 미리보기. PHPicker 또는 카메라, 최대 30장. (spec_3.md:134-138)

**props**:
```swift
struct PhotoGalleryGrid: View {
    @Binding var photos: [RoundPhoto]   // 21-DATA_MODEL
    let maxCount: Int                   // 기본값 30 (spec_3.md:279)
    let onAdd: () -> Void               // PHPicker 또는 카메라 실행
    let onDelete: (RoundPhoto) -> Void
}
```

**상태**:
- `empty`: 사진 없음 — "+" 추가 버튼만 표시
- `partial`: 1장 이상, maxCount 미만
- `full`: 30장 도달 — 추가 버튼 비활성, "최대 30장" 안내

**변형**: 단일

**토큰 / 접근성 메모**: 3열 그리드 셀 간격 8pt (`--space-xs`, 10-DESIGN_SYSTEM §4) / `--radius-sm` / 삭제 `plain` SF Symbols `xmark.circle.fill` / 사진 권한 `53-PERMISSIONS.md` 위임

---

### ShareSheet

**플랫폼**: iOS / **용도**: F9 viewer 공유 옵션(이름 공개/접근 권한) 선택 + 공유 링크 생성 모달. (spec_3.md:130-142)

**props**:
```swift
struct ShareSheet: View {
    @Binding var options: ShareOptions  // 21-DATA_MODEL §3
    let onShare: () async throws -> URL
}
```

**상태**:
- `idle`: 공유 전 — 옵션 선택 가능
- `loading`: POST /api/share 요청 중 — ProgressView 표시, 버튼 비활성
- `success`: URL 수신 — 링크 복사 + 시스템 공유 시트 진입
- `error`: 네트워크 실패 — 에러 메시지 + 재시도 버튼

**변형**: 단일

**토큰 / 접근성 메모**:
- `--elevation-2`, `--surface-elevated`, `--radius-lg` (시트)
- 공유 버튼: `filled` 변형, `--green-primary` 배경
- API 연동: 30-API §3 POST /api/share

---

## 9. BannerNotice + DataQualityBadge

### BannerNotice

**플랫폼**: 공통 (iPhone 우선, 추후 watchOS 가능)

**용도**: iCloud 미연결 / 네트워크 오프라인 등 비방해적 시스템 안내. 앱 흐름 비차단. (20-ARCHITECTURE §7)

**props**:
```swift
struct BannerNotice: View {
    let message: String
    let level: BannerLevel       // .info / .warning
    let onDismiss: (() -> Void)? // nil이면 닫기 버튼 없음
}

enum BannerLevel {
    case info
    case warning
}
```

**상태**:
- `visible`: 배너 표시 중
- `dismissed`: 닫힘 (onDismiss 호출 후)

**변형**:
- `.info`: `--green-accent` 배경 — 안내성 메시지 (예: "iCloud 백업 중")
- `.warning`: `--surface-elevated` 배경 + `--border` 외곽선 — 주의 메시지 (예: "오프라인 상태")

**토큰 / 접근성 메모**:
- `--elevation-1`, 내부 패딩 16pt (`--space-sm`)
- 텍스트: `--text-primary`, `--text-footnote`
- 닫기 버튼: `plain` 변형 SF Symbols `xmark`

---

### DataQualityBadge

**플랫폼**: iOS (코스 카드 하위)

**용도**: F3 GPS 골프장+서브코스 자동 감지 가능 여부 표시. 한국 골프장 DB v3 (965곳) 기준: complete 3곳 (전체의 0.31%) / partial 12곳 / minimal 9곳 / low 941곳. (CLAUDE.md §PROJECT, spec_3.md F3)

**props**:
```swift
struct DataQualityBadge: View {
    let quality: DataQuality     // .complete / .partial / .minimal / .low / .unknown
}

enum DataQuality: String, Codable {
    case complete  // 3곳: 18홀 완전 매핑 — GPS 코스 감지 활성
    case partial   // 12곳: 9홀 이상 매핑 — 수동 홀 진행
    case minimal   // 9곳: 1~8홀 매핑 — 수동 홀 진행
    case low       // 941곳: 클럽하우스 좌표만 — 수동 홀 진행
    case unknown   // 분류 미정 — 안전 fallback
}
```

**상태**: 해당 없음 (표시 전용)

**변형** (dataQuality 분기):

| 변형 | 코스 수 | 표시 텍스트 | 색상 |
|------|--------|------------|------|
| `.complete` | 3곳 | "GPS 코스 감지 활성" | `--green-primary` |
| `.partial` | 12곳 | "수동 홀 진행" | `--text-secondary` |
| `.minimal` | 9곳 | "수동 홀 진행" | `--text-secondary` |
| `.low` | 941곳 | "수동 홀 진행" | `--text-secondary` |
| `.unknown` | — | "수동 홀 진행" | `--text-secondary` |

**토큰**: `--text-caption` / `.complete` `--green-primary` / 나머지 `--text-secondary`

---

### SubCourseSelector

**플랫폼**: iOS

**용도**: 27/36홀 골프장(holesCount > 18)에서 서브코스 라벨 (동/서/남/북 또는 전반/후반) 선택. 라운드 시작 화면에서 표시. (spec_3.md §F3, 21-DATA_MODEL §5)

**props**:
```swift
struct SubCourseSelector: View {
    let subCourses: [SubCourse]        // 선택 가능한 서브코스 목록
    @Binding var selectedIndex: Int    // 선택된 서브코스 인덱스
}
```

**상태**:
- `idle`: 선택 대기 중 — 서브코스 버튼 그룹 표시
- `disabled`: subCourses 비어있거나 nil — 컴포넌트 숨김 또는 비활성

**변형**:
- `2서브코스`: 동/서 또는 전반/후반 — 가로 2버튼
- `3서브코스`: 동/서/남 등 — 가로 3버튼 또는 세그먼트
- `4서브코스`: 동/서/남/북 — 가로 4버튼 또는 2×2 그리드

**토큰 / 접근성 메모**:
- `--surface-elevated`, `--green-accent` (선택된 버튼), `--radius-sm`
- 미선택: `--text-secondary` / 선택됨: `--text-primary` + `--green-primary` 테두리
- VoiceOver: "{서브코스명} 선택됨" / "두 번 탭하여 {서브코스명} 선택"

---

## 10. 책임 경계 + 본 문서 범위 외

| 문서 | 담당 영역 | 상태 |
|------|----------|------|
| **본 문서 (11-COMPONENTS)** | 컴포넌트 props / 상태 / 변형 / 토큰 사용 | 작성 완료 |
| `12-SCREENS.md` (작성 예정) | 화면 모형 + 컴포넌트 조합, ScoreCell 변형 선택 | Stitch 목업 단계 후 |
| `13-HAPTICS_AND_MOTION.md` (작성 예정) | 햅틱 패턴, 트랜지션, 모션 | 본 시리즈 #2 |
| `14-ACCESSIBILITY.md` (작성 예정) | VoiceOver 레이블, Dynamic Type 대응 | 작성 예정 |
| `10-DESIGN_SYSTEM.md` (작성 완료) | 토큰 정의 — 컬러 / 타이포 / 간격 | 참조만 |
| `31-VIEWER_HTML.md` (작성 완료) | viewer 측 DOM 컴포넌트 | 별도 |

---

### 부록: 후속 보완 TODO

- ScoreCell 변형 선택 (`.horizontalScroll` / `.split9x2`): `12-SCREENS.md`에서 확정
- DataQualityBadge: 품질 등급 추가 시 `DataQuality` enum 확장
- PenaltyButton Watch 배치: 하단 3개 버튼 세부 크기는 `12-SCREENS.md`에서 확정

---

*최종 업데이트: 2026-05-11*
