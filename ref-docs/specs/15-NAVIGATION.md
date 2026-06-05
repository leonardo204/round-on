# 15-NAVIGATION — 라운드온 화면 전환 정책

> 합의: 2026-05-26 (Session #20)
> 적용 범위: App-iOS 전체. Watch app 별도.

## 4계층 패턴

| 패턴 | 사용처 | 이유 |
|------|--------|------|
| `.fullScreenCover` + 내부 `NavigationStack` + 우상단 "닫기" | 루트(HomeView) → 메인 화면 진입<br>(NewRound, Stats, AllRounds, Settings, RoundDetail from Home) | 모드 전환 명시. 닫기 = 루트 복귀 |
| `NavigationLink` push | 모달 안에서 한 단계 더 깊은 상세<br>(Stats → RoundDetail, AllRounds → RoundDetail) | 자동 back arrow. 모달 누적 방지 |
| `.sheet` | in-context 가벼운 액션<br>(공유, 페널티 카운트, 코스 변경, 날짜 선택, 동반자 매칭) | swipe-down 으로 가볍게 닫힘 |
| `.alert` / `.confirmationDialog` | 위험 행동 확인 (삭제, 종료, 강제 종료 등) | iOS HIG 표준 |

## 일관성 규칙

- 닫기 라벨: "닫기" (텍스트)
- 닫기 위치: `.topBarTrailing`
- AllRoundsView 만 `.topBarLeading` 예외 — 라운드 추가/필터 액션이 우측에 있어서. 신규 화면은 trailing 표준 따른다.

## 금지 항목

1. **모달 위 모달 금지** — `fullScreenCover` 안에서 또 `fullScreenCover` 금지. 닫기 버튼이 두 개가 되어 사용자 멘탈모델이 깨진다.
2. **NavigationLink 안에서 같은 종류의 화면을 fullScreenCover로 띄우기 금지** — 깊은 상세는 push로 통일.
3. **닫기 텍스트 비표준화 금지** — "Done", "X", "취소", "← 뒤로" 혼용 금지.

## 적용 예시

### Stats → RoundDetail
HomeView 가 `.fullScreenCover` 로 띄운 `StatsView` 안에는 이미 `NavigationStack` 이 있다. Stats 안의 "최근 라운드" 항목 클릭 시 `NavigationLink` 로 push. back arrow 로 Stats 복귀.

### AllRounds → RoundDetail
같은 원리. 현재는 `.fullScreenCover(item: $selectedRound)` 로 모달 위 모달 패턴인데, 향후 push 로 마이그레이션 필요(별도 작업으로 추적).

### NewRound 진행 중 코스 변경
in-context 액션이므로 `.sheet` 사용 (현재 코드와 일치).

## 마이그레이션 부채

- `AllRoundsView` 의 `.fullScreenCover(item: $selectedRound)` (App-iOS/Views/AllRoundsView.swift:83) → `NavigationLink` 로 변경 (별도 PR)
- `HomeView` 의 `.fullScreenCover(item: $selectedRound)` (App-iOS/Views/HomeView.swift:67) 는 루트에서 직접 호출하므로 모달 유지 OK

## 변경 이력

- 2026-05-26: 신규 작성 (Session #20)
