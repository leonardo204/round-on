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

### Home → Import (스코어카드 불러오기)
루트(HomeView)에서 `.fullScreenCover` 로 직접 진입 (App-iOS/Views/HomeView.swift:104). `ImportLandingView` 는 자체 `NavigationStack` 과 우상단 "닫기" 를 가지므로 호출부에서 다시 감싸지 않는다 (감싸면 스택 중첩 + 네비바 이중). 검토 화면(`ImportReviewView`)은 `navigationDestination` push.

## 마이그레이션 부채

- `AllRoundsView` 의 `.fullScreenCover(item: $selectedRound)` (App-iOS/Views/AllRoundsView.swift:83) → `NavigationLink` 로 변경 (별도 PR)
- `HomeView` 의 `.fullScreenCover(item: $selectedRound)` (App-iOS/Views/HomeView.swift:72) 는 루트에서 직접 호출하므로 모달 유지 OK
- ~~`SettingsView` → `ImportLandingView` 를 `.fullScreenCover` 로 진입 (모달 위 모달, 금지 항목 1 위반)~~ → **2026-07-17 해소**. 설정에서 진입점을 제거하고 홈으로 승격했다. 부수적으로 `ImportLandingView` 의 닫기가 "취소"/`.cancellationAction`(leading) 이었던 것을 표준인 "닫기"/`.topBarTrailing` 으로 정렬했다 (금지 항목 3).
- **남은 부채**: `SettingsView` → `AIAnalysisView` 는 여전히 설정(fullScreenCover) 안에서 모달로 열린다 (App-iOS/Views/SettingsView.swift:125). 단 `.sheet` 이므로 금지 항목 1(`fullScreenCover` 중첩)에 문자 그대로 해당하지는 않고, 할당량·동의 철회를 다루는 성격상 설정에 있는 것이 맞아 유지한다. 닫기 버튼이 두 겹으로 보이는 문제는 남아 있어 별도 판단 필요.
  - 참고: `ImportLandingView` 도 할당량 소진 시 같은 `AIAnalysisView` 를 `.sheet` 로 띄운다 (App-iOS/Views/Import/ImportLandingView.swift:88). 이쪽은 in-context 액션이라 `.sheet` 가 정책상 적합.

## 변경 이력

- 2026-05-26: 신규 작성 (Session #20)
- 2026-07-17: Settings → Import 모달 위 모달 해소. 스코어카드 불러오기를 홈 진입점으로 승격(보조 CTA + 빈 상태 보조 액션), `ImportLandingView` 닫기 표준화. 적용 예시에 Home → Import 추가
