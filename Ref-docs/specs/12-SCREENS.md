# 12 — 화면 카탈로그 (Screens)

| 항목 | 값 |
|------|----|
| 문서 번호 | 12 |
| 제목 | 화면 카탈로그 (Screens) |
| 상태 | 확정 (v1) |
| 작성일 | 2026-05-12 |
| 버전 기반 | v4 |
| 원본 출처 | spec_3.md §7 (566-624), §10.2 (704-762) |
| 관련 문서 | 00-OVERVIEW, 02-USER_FLOWS, 10-DESIGN_SYSTEM, 11-COMPONENTS, 13-HAPTICS_AND_MOTION, 21-DATA_MODEL, 30-API_SPEC, 31-VIEWER_HTML, 33-SECURITY |

---

## 1. 목적 / 범위

본 문서는 Stitch 시안 22화면을 specs/ 시리즈와 연결하는 화면 카탈로그다. 각 Stitch 화면에 대해 담당 기능 명세(spec_3.md §N), 컴포넌트(11-COMPONENTS §N), 플로우(02-USER_FLOWS F-?), 햅틱/모션(13-HAPTICS_AND_MOTION §N)의 매핑 좌표를 확정한다.

**본 문서가 정식 확정한 결정 4건**

> 아래 4건의 결정은 본 문서에서 최초 확정한다. 11-COMPONENTS §6이 ScoreCell 변형 선택을 12-SCREENS에 위임한다고 명시한 것을 포함, 모든 위임 사항이 본 문서에서 해소된다.

| # | 결정 | 상세 | 참조 |
|---|------|------|------|
| D-1 | ScoreCell 변형 = Variant B 정식 채택 | `.split9x2` — OUT/IN 2단 분리 레이아웃. `.horizontalScroll` 미채택 | §5 iPhone 화면 참조 |
| D-2 | 색상 교체 정책 | Stitch Material You 보라 → 라운드온 사계절 그린 토큰 교체 | §3 참조 |
| D-3 | 폰트 교체 정책 | Stitch frontmatter Hanken Grotesk / JetBrains Mono → SF Pro Display + Pretendard / SF Mono | §4 참조 |
| D-4 | par-diff 마커 색상 | Stitch 빨강 동그라미(언더파)/보라 사각형(오버파) → `--green-primary` 동그라미(언더파) / `--text-secondary` 사각형(오버파) | §3 참조 |

**범위 외**

- 실제 SwiftUI 구현 코드 — 구현 단계 (spec_3.md §10.2 Step 5 이후)
- 화면 시각 목업 자체 — Stitch 시안 (`Ref-docs/design-stitch/`) 원본 참조
- 컴포넌트 props / 상태 / 변형 정의 — `11-COMPONENTS.md`
- VoiceOver 레이블 상세 — `14-ACCESSIBILITY.md` (작성 예정)

### Stitch 시안 개요

Google Stitch가 생성한 22화면 시안은 `Ref-docs/design-stitch/screens/` 아래 세 디렉토리에 분류된다.

| 디렉토리 | 화면 수 | 플랫폼 | 공유 DESIGN.md |
|----------|--------|--------|---------------|
| `screens/iphone/` | 10화면 | iOS 17+ / iPhone | 동일 파일 (`screens/DESIGN.md`) |
| `screens/watch/` | 7화면 | watchOS 10+ / Apple Watch | 동일 파일 |
| `screens/mobile-web/` | 5화면 | 모바일 브라우저 (Viewer) | 동일 파일 |

각 화면 폴더 내에는 두 파일이 존재한다.
- `screen.png`: 렌더링된 목업 이미지. 구현 기준 시각 참조.
- `code.html`: Tailwind CSS 기반 HTML. CSS 변수 교체 후 Viewer 구현 참조 가능.

공유 `DESIGN.md`에는 frontmatter(색상/폰트 정의)와 본문(브랜드/레이아웃/컴포넌트 가이드)이 포함된다. frontmatter와 본문 간 자체 모순 사항은 §4 및 §10에서 정리한다.

---

## 2. 시안 산출물 일람

Stitch 시안 22화면 전체 목록. 각 폴더에 `screen.png` + `code.html` 존재. (stitch:screens/)

ID 체계: `{플랫폼}-{그룹}.{순번}` 형식. iPhone = `iphone-2.N`, Watch = `watch-3.N`, Mobile-Web = `web-4.N`.

| ID | 화면 명 | Stitch 경로 | 분류 | spec_3.md 매핑 | specs/ 매핑 |
|----|--------|------------|------|---------------|-------------|
| iphone-2.1 | 홈 (라운드 리스트) | screens/iphone/round_on_home_screen/ | iPhone | §7.1 항목 1 (spec_3.md:568) | 02-USER_FLOWS F-A 진입 |
| iphone-2.2 | 새 라운드 시작 | screens/iphone/new_round_setup/ | iPhone | §7.1 항목 2 (spec_3.md:569) | 02-USER_FLOWS F-A → F-B |
| iphone-2.3a | 라운드 진행 Variant A | screens/iphone/round_in_progress_variant_a/ | iPhone | §7.1 항목 3 (spec_3.md:570) | 11-COMPONENTS §6 ScoreCell.horizontalScroll |
| iphone-2.3b | 라운드 진행 Variant B ★ | screens/iphone/round_in_progress_variant_b/ | iPhone | §7.1 항목 3 (spec_3.md:570) | 11-COMPONENTS §6 ScoreCell.split9x2 — **D-1 채택** |
| iphone-2.4 | 페널티 입력 모달 | screens/iphone/penalty_input_modal/ | iPhone | spec_3.md:83-85 | 11-COMPONENTS §7 PenaltyButton |
| iphone-2.5 | 사진 첨부 | screens/iphone/photo_attach_screen/ | iPhone | §7.1 항목 4 (spec_3.md:571) | 11-COMPONENTS §8 PhotoGalleryGrid |
| iphone-2.6 | 라운드 종료 요약 | screens/iphone/round_end_summary/ | iPhone | §7.1 항목 5 (spec_3.md:572) | 02-USER_FLOWS F-D |
| iphone-2.7 | 공유 옵션 모달 | screens/iphone/share_options_modal/ | iPhone | §7.1 항목 6 (spec_3.md:573-581) | 02-USER_FLOWS F-E, 11-COMPONENTS §9 ShareSheet |
| iphone-2.8 | 라운드 상세 (사후 보기) | screens/iphone/round_detail_completed/ | iPhone | §7.1 항목 7 (spec_3.md:582) | 02-USER_FLOWS F-E 업데이트 분기 |
| iphone-2.9 | 설정 | screens/iphone/settings_screen/ | iPhone | §7.1 항목 8 (spec_3.md:583) | 10-DESIGN_SYSTEM §2 팔레트 선택 |
| watch-3.1 | 메인 점수 입력 (Winter) | screens/watch/apple_watch_score_input_winter/ | Watch | §7.2 (spec_3.md:587-606) | 02-USER_FLOWS F-C |
| watch-3.2 | 홀 전환 시작 프레임 | screens/watch/hole_change_start_h7_fading/ | Watch | spec_3.md:97 | 13-HAPTICS_AND_MOTION §5 |
| watch-3.3 | 홀 전환 중간 프레임 | screens/watch/hole_change_mid_h8_sliding/ | Watch | spec_3.md:97 | 13-HAPTICS_AND_MOTION §5 |
| watch-3.4 | 홀 전환 종료 프레임 | screens/watch/hole_change_end_h8_active/ | Watch | spec_3.md:97 | 13-HAPTICS_AND_MOTION §5 |
| watch-3.5 | 동반자 전환 오버레이 | screens/watch/apple_watch_player_switch_overlay/ | Watch | spec_3.md:98 | 02-USER_FLOWS F-C, 11-COMPONENTS §6 PlayerChip |
| watch-3.6 | 라운드 종료 메뉴 | screens/watch/apple_watch_round_end_menu/ | Watch | spec_3.md:109 | 02-USER_FLOWS F-D |
| watch-3.7 | 라운드 종료 확인 | screens/watch/apple_watch_round_end_confirmation/ | Watch | spec_3.md:109 | 02-USER_FLOWS F-D |
| web-4.1 | 모바일 웹 뷰어 메인 | screens/mobile-web/round_on_mobile_web_viewer/ | Mobile-Web | spec_3.md:147-151 | 02-USER_FLOWS F-F, 31-VIEWER_HTML §2 |
| web-4.2 | PIN 잠금 화면 | screens/mobile-web/round_on_web_viewer_pin_lock/ | Mobile-Web | spec_3.md:148 | 02-USER_FLOWS F-F PIN 분기, 33-SECURITY §5 |
| web-4.3 | 사진 라이트박스 | screens/mobile-web/round_on_web_lightbox/ | Mobile-Web | spec_3.md:205-213 | 02-USER_FLOWS F-G, 31-VIEWER_HTML §7 |
| web-4.4 | 사진 저장 플로우 문서화 | screens/mobile-web/round_on_photo_save_flow_documentation/ | Mobile-Web | spec_3.md:205-213 | 31-VIEWER_HTML §6 동작 매트릭스 |
| web-4.5 | 만료/오류 페이지 | screens/mobile-web/round_on_web_viewer_error_states/ | Mobile-Web | spec_3.md:148 | 30-API_SPEC §7 에러 코드 |

---

## 3. 색상 교체 정책

Stitch는 Material You 기본 보라 색조(primary: #4f378a)를 frontmatter에 고집했다. 시안의 레이아웃, 타이포 비율, 컴포넌트 구조는 그대로 채택하되, 모든 색상 토큰은 라운드온 사계절 그린 팔레트로 교체한다. 1인 개발 환경에서 Stitch HTML 내 CSS 변수 교체는 grep/replace 스크립트 1회 실행으로 처리 가능하다. (10-DESIGN_SYSTEM §2)

### 색상 교체 대응표

| Stitch 시안 토큰 | Stitch 값 | 라운드온 토큰 | 라운드온 값 | 출처 |
|-----------------|----------|--------------|------------|------|
| `primary` | `#4f378a` (보라) | `--green-primary` | `#7FB069` | 10-DESIGN_SYSTEM §2 Spring |
| `primary-container` | `#6750a4` | `--green-secondary` | `#B8D8B0` | 10-DESIGN_SYSTEM §2 Spring |
| `surface` | `#fdf7ff` (라일락) | `--surface` | `#FAFCF7` | 10-DESIGN_SYSTEM §2 Spring |
| `secondary-container` | `#e1d4fd` | `--green-accent` | `#C5E1A5` | 10-DESIGN_SYSTEM §2 Spring |
| `on-surface` | `#1d1b20` | `--text-primary` | `#1F2A1B` | 10-DESIGN_SYSTEM §2 Spring |
| `outline` | `#7a7582` | `--text-secondary` | `#5A6850` | 10-DESIGN_SYSTEM §2 Spring |
| `outline-variant` | `#cbc4d2` | `--border` | `#E8EFE0` | 10-DESIGN_SYSTEM §2 Spring |
| `error` | `#ba1a1a` | (시스템 빨강 유지) | — | — |
| `tertiary` | `#765b00` (호박) | (미사용) | — | — |

Watch 화면(watch-3.1 ~ watch-3.7)은 Winter 팔레트(다크 디폴트)를 사용한다. Stitch 시안이 Winter 다크로 렌더링되어 있으므로 구조적 교체만 적용하면 된다.

### par-diff 마커 색상 (D-4 확정)

스코어카드 셀의 par 대비 표시기에 대해 Stitch 시안과 라운드온 구현 간 색상을 다음과 같이 교체한다.

| 상태 | Stitch 시안 | 라운드온 구현 | 근거 |
|------|-----------|-------------|------|
| 언더파 (버디 이하) | 빨강 동그라미 | `--green-primary` (#7FB069) 동그라미 | 골프 전통: 그린 계열이 좋은 성적 의미 |
| 이븐파 | 표시 없음 | 표시 없음 | — |
| 오버파 (보기 이상) | 보라 사각형 | `--text-secondary` (#5A6850) 사각형 | 튀지 않는 중성 색조 |
| +3 이상 (더블 보기~) | Stitch 별도 처리 없음 | `--text-secondary` 사각형 유지 | 단순화 정책 |

---

## 4. 폰트 교체 정책

Stitch DESIGN.md frontmatter에는 Hanken Grotesk와 JetBrains Mono가 명시되어 있으나, 같은 파일 본문 Typography 섹션에는 "SF Pro Display / Pretendard"가 명시되어 있다. 이는 Stitch가 자동 생성한 frontmatter와 수동 작성된 본문 사이의 자체 모순이다. (stitch:screens/DESIGN.md §Typography)

**결론**: frontmatter는 무시한다. 본문 텍스트의 SF Pro Display / Pretendard 선언을 10-DESIGN_SYSTEM §3과 일치하는 것으로 판단하여 본 문서가 D-3으로 정식 확정한다.

### 폰트 교체 대응표

| 용도 | Stitch frontmatter | 라운드온 정식 | 출처 |
|------|--------------------|-------------|------|
| 디스플레이 / 헤드라인 / 바디 | Hanken Grotesk | SF Pro Display (영문) + Pretendard (한국어) | 10-DESIGN_SYSTEM §3, stitch DESIGN.md 본문 |
| 수치 / 스코어카드 데이터 | JetBrains Mono | SF Mono | 10-DESIGN_SYSTEM §3 |

Stitch HTML `code.html`에 삽입된 Google Fonts `@import url('..Hanken+Grotesk..')` 구문은 구현 단계에서 제거하고 시스템 폰트 스택으로 교체한다.

---

## 5. iPhone 화면 카탈로그 (10화면)

### iphone-2.1 — 홈 (라운드 리스트)

- **파일**: `screens/iphone/round_on_home_screen/screen.png` (stitch:screens/iphone/round_on_home_screen/)
- **요약**: 최근 라운드 카드 리스트 + "새 라운드 시작" FAB. (spec_3.md:568)
- **컴포넌트**: `CourseCard` (라운드 카드 표시) (11-COMPONENTS §4)
- **플로우**: F-A 진입점 — 앱 첫 실행 또는 복귀 시 표시 (02-USER_FLOWS F-A)
- **인터랙션**: 카드 탭 → iphone-2.8 라운드 상세 이동 / FAB 탭 → iphone-2.2 이동
- **Stitch 특이점**: 라운드 카드에 골프장 이름, 날짜, 총 타수, 썸네일 사진 1장이 잘 배치됨. 카드 배경색이 Stitch 보라(`surface-container-low: #f8f2fa`) → `--surface-elevated` (#FFFFFF)로 교체.

### iphone-2.2 — 새 라운드 시작

- **파일**: `screens/iphone/new_round_setup/screen.png` (stitch:screens/iphone/new_round_setup/)
- **요약**: GPS 자동 매칭 결과 표시 + 동반자 별명 입력 최대 3명. (spec_3.md:569)
- **컴포넌트**: `CourseCard` (자동 매칭 결과), `PlayerChip` (동반자 입력) (11-COMPONENTS §4, §5)
- **플로우**: F-A 종료 → F-B 시작 (02-USER_FLOWS F-A, F-B)
- **인터랙션**: "변경" 탭 → 수동 골프장 검색 / 동반자 칩 탭 → 이름 수정 / "라운드 시작" 탭 → iphone-2.3b 진입
- **Stitch 특이점**: `DataQualityBadge` 4종 분포 — complete 3곳(0.26%) / partial 12곳 / minimal 9곳 / low 1139곳. 시안에서 `low` 1종만 렌더링됨. 나머지 4종(`complete`/`partial`/`minimal`/`unknown`)은 11-COMPONENTS §10 명세만 사용. (CLAUDE.md §PROJECT)

### iphone-2.3a — 라운드 진행 Variant A (미채택)

- **파일**: `screens/iphone/round_in_progress_variant_a/screen.png` (stitch:screens/iphone/round_in_progress_variant_a/)
- **요약**: 4인 × 18홀 가로 스크롤 스코어카드. 한 화면에 4-5홀 표시. (spec_3.md:570)
- **컴포넌트**: `ScoreCell.horizontalScroll`, `HoleProgress` (11-COMPONENTS §6)
- **플로우**: F-B → F-C (02-USER_FLOWS F-C)
- **결정**: **D-1에 의해 미채택.** 레퍼런스 목적으로만 보존. 모바일 세로 화면에서 전체 홀을 보려면 가로 스크롤이 필요하여 인지 부하 증가.
- **Stitch 특이점**: 상단 sticky 합계 행 처리 방식이 가로 스크롤 내에서 복잡해지는 구조적 한계를 시안이 명확히 드러냄.

### iphone-2.3b — 라운드 진행 Variant B (채택)

- **파일**: `screens/iphone/round_in_progress_variant_b/screen.png` (stitch:screens/iphone/round_in_progress_variant_b/)
- **요약**: OUT(1-9홀) / IN(10-18홀) 2단 분리 스코어카드. 세로 화면 한 번에 전체 표시. (spec_3.md:570, spec_3.md:206)
- **컴포넌트**: `ScoreCell.split9x2`, `HoleProgress` (11-COMPONENTS §6)
- **플로우**: F-B → F-C, Watch 동기화 병행 (02-USER_FLOWS F-C)
- **인터랙션**: 셀 탭 +1 / 길게 누르기 -1 / 현재 홀 자동 하이라이트 / sticky 합계 행 OUT·IN·TOTAL 표시
- **Stitch 특이점**: 9홀 블록 상하 배치로 sticky 합계 행 처리가 단순해짐. 가독성 압도적 우수. **D-1: 본 화면 구조를 정식 채택.**

### iphone-2.4 — 페널티 입력 모달

- **파일**: `screens/iphone/penalty_input_modal/screen.png` (stitch:screens/iphone/penalty_input_modal/)
- **요약**: OB +2 / 해저드 +1 / OK +1 인라인 모달. (spec_3.md:83-85)
- **컴포넌트**: `PenaltyButton` 3종 (11-COMPONENTS §7)
- **플로우**: F-C 점수 입력 중 분기 (02-USER_FLOWS F-C)
- **인터랙션**: OB 탭 → `.directionUp` 햅틱 (Watch) / 해저드 탭 → `.click × 2` / OK 탭 → `.success` (13-HAPTICS_AND_MOTION §3)
- **Stitch 특이점**: 하단 시트 형태로 현재 홀 정보를 배경으로 유지하면서 올라오는 구조가 잘 잡힘. 버튼 배경색 `secondary-container: #e1d4fd` → `--green-accent` (#C5E1A5)로 교체.

### iphone-2.5 — 사진 첨부

- **파일**: `screens/iphone/photo_attach_screen/screen.png` (stitch:screens/iphone/photo_attach_screen/)
- **요약**: 라운드 중/후 사진 첨부. 최대 30장, 1장 최대 10MB. (spec_3.md:134-138)
- **컴포넌트**: `PhotoGalleryGrid` (3열 정방형 썸네일) (11-COMPONENTS §8)
- **플로우**: F-D 라운드 종료 전후 사진 첨부 (02-USER_FLOWS F-D)
- **인터랙션**: 사진 선택 완료 → `.light` 햅틱 (13-HAPTICS_AND_MOTION §3) / 사진 탭 → 라이트박스 전환
- **Stitch 특이점**: 카메라/갤러리 2원 진입 버튼이 상단 명확히 분리됨. 선택된 사진 수 배지 카운터 처리 우수.

### iphone-2.6 — 라운드 종료 요약

- **파일**: `screens/iphone/round_end_summary/screen.png` (stitch:screens/iphone/round_end_summary/)
- **요약**: 총 스코어, 홀별 par 대비, 사진 미리보기, 공유 진입. (spec_3.md:572)
- **컴포넌트**: `ScoreCell.split9x2` (요약용 읽기 전용), `PhotoGalleryGrid` (11-COMPONENTS §6, §8)
- **플로우**: F-D 명시적 종료 Step 2 (02-USER_FLOWS F-D)
- **인터랙션**: "공유하기" 탭 → iphone-2.7 모달 / "홈으로" 탭 → iphone-2.1 / 라운드 종료 시 `.stop` (Watch) + `.success` (iPhone) 동시 발화 (13-HAPTICS_AND_MOTION §3)
- **Stitch 특이점**: 총 타수 hero 텍스트가 48px 대형으로 상단 1/3에 배치 — "Gallery of the Green" 컨셉의 에디토리얼 레이아웃 잘 구현됨. (stitch:screens/DESIGN.md §Brand & Style)

### iphone-2.7 — 공유 옵션 모달

- **파일**: `screens/iphone/share_options_modal/screen.png` (stitch:screens/iphone/share_options_modal/)
- **요약**: 이름 공개(실명/익명), 접근 권한(공개/PIN 4자리), 사진 첨부 여부, 7일 만료 안내, "공유 링크 생성" CTA. (spec_3.md:573-581)
- **컴포넌트**: `ShareSheet` (PIN 입력 박스 4개 + 토글 + 라디오) (11-COMPONENTS §9)
- **플로우**: F-E Viewer 공유 생성 (02-USER_FLOWS F-E)
- **인터랙션**: PIN 입력 4자리 완성 → 자동 bcrypt 해시 처리 후 전송 / "공유 링크 생성" → `POST /api/share` → iOS 공유 시트 (30-API_SPEC §3)
- **Stitch 특이점**: "사진 12장 포함" 동적 카운트 표시, PIN 4자리 입력 박스 4개 독립 배치, 7일 만료 안내 텍스트까지 Stitch가 매우 정확하게 구현함. 보라 primary 버튼 → `--green-primary` (#7FB069) 교체만 하면 됨.

### iphone-2.8 — 라운드 상세 (사후 보기)

- **파일**: `screens/iphone/round_detail_completed/screen.png` (stitch:screens/iphone/round_detail_completed/)
- **요약**: 완료된 라운드의 전체 스코어카드 + 사진 관리 + viewer 재공유. (spec_3.md:582)
- **컴포넌트**: `ScoreCell.split9x2` (읽기 전용), `PhotoGalleryGrid`, `ShareSheet` (11-COMPONENTS §6, §8, §9)
- **플로우**: F-E 업데이트 분기 — `PUT /api/share/{shortId}` + editToken (02-USER_FLOWS F-E)
- **인터랙션**: "사진 추가/삭제" → iphone-2.5 / "다시 공유" → iphone-2.7 (업데이트 모드)
- **Stitch 특이점**: 상단에 viewer URL + "복사" 버튼 배치가 재공유 진입을 직관적으로 처리함.

### iphone-2.9 — 설정

- **파일**: `screens/iphone/settings_screen/screen.png` (stitch:screens/iphone/settings_screen/)
- **요약**: iCloud 동기화, HealthKit 권한, 4계절 테마 선택, OSM ODbL 표기. (spec_3.md:583)
- **컴포넌트**: (공용 List 셀 — 별도 커스텀 컴포넌트 없음)
- **플로우**: 설정은 별도 플로우 없음 — 탭바 또는 홈에서 진입
- **인터랙션**: 팔레트 선택 → 즉시 앱 전체 색상 전환 (10-DESIGN_SYSTEM §2)
- **Stitch 특이점**: Spring/Summer/Autumn/Winter 4계절 팔레트 프리뷰 스와치가 설정 셀 안에 수평 배치됨. OSM ODbL 라이선스 고지 항목이 "정보" 섹션 마지막에 배치됨 — 필수 표기 요구사항 충족 확인. (CLAUDE.md §PROJECT)

---

## 6. Apple Watch 화면 카탈로그 (7화면)

Watch 화면 전체는 Winter 팔레트(다크 디폴트)를 기반으로 렌더링된다. Stitch 시안과 라운드온 방침이 일치한다. (10-DESIGN_SYSTEM §2 Winter)

### watch-3.1 — 메인 점수 입력 (Winter palette)

- **파일**: `screens/watch/apple_watch_score_input_winter/screen.png` (stitch:screens/watch/apple_watch_score_input_winter/)
- **요약**: 홀 번호, par, 카운터(0에서 시작), par 대비 수치, 하단 OB/해저드/OK 버튼 행. (spec_3.md:587-606)
- **컴포넌트**: `ShotButton`, `PenaltyButton` (11-COMPONENTS §6, §7)
- **플로우**: F-C 점수 입력 핵심 화면 (02-USER_FLOWS F-C)
- **인터랙션**: 큰 탭 영역 → +1 / Digital Crown 시계 방향 → +1 / 반시계 → -1 / OB → `.directionUp` / 해저드 → `.click × 2` / OK → `.success` (13-HAPTICS_AND_MOTION §3)
- **Stitch 특이점**: SF Mono 48px 대형 카운터가 화면 60%를 차지하는 레이아웃이 야외 가독성 극대화 원칙과 일치. Winter 다크 배경으로 눈부심 최소화. (stitch:screens/DESIGN.md §Brand & Style)

### watch-3.2 — 홀 전환 시작 프레임 (7번 홀 페이드 아웃)

- **파일**: `screens/watch/hole_change_start_h7_fading/screen.png` (stitch:screens/watch/hole_change_start_h7_fading/)
- **요약**: 7번 홀 카운터가 페이드 아웃 시작하는 트랜지션 첫 프레임.
- **컴포넌트**: `ShotButton` (페이드 상태) (11-COMPONENTS §6)
- **플로우**: F-C 수동 홀 이동 스와이프 → watch-3.3 → watch-3.4 (02-USER_FLOWS F-C)
- **인터랙션**: 좌/우 스와이프 시작 → `.directionUp`/`.directionDown` 햅틱 발화 (13-HAPTICS_AND_MOTION §3)
- **Stitch 특이점**: 3프레임 시퀀스(watch-3.2 → watch-3.3 → watch-3.4)는 모션 스토리보드 역할. 구현은 `TabView(.page)` slide 트랜지션 + `--motion-short` (0.2s). (13-HAPTICS_AND_MOTION §5)

### watch-3.3 — 홀 전환 중간 프레임 (8번 홀 슬라이딩)

- **파일**: `screens/watch/hole_change_mid_h8_sliding/screen.png` (stitch:screens/watch/hole_change_mid_h8_sliding/)
- **요약**: 8번 홀 콘텐츠가 우측에서 슬라이드 인 중인 중간 상태.
- **컴포넌트**: `ShotButton` (11-COMPONENTS §6)
- **플로우**: watch-3.2 → watch-3.3 → watch-3.4 모션 시퀀스 (13-HAPTICS_AND_MOTION §5)
- **인터랙션**: 슬라이드 중 — 햅틱 이미 발화 완료. 시각만 이동 중.
- **Stitch 특이점**: 두 홀 콘텐츠가 동시에 보이는 반투명 중간 상태로 모션 의도를 명확히 표현.

### watch-3.4 — 홀 전환 종료 프레임 (8번 홀 활성)

- **파일**: `screens/watch/hole_change_end_h8_active/screen.png` (stitch:screens/watch/hole_change_end_h8_active/)
- **요약**: 8번 홀 점수 입력 화면이 완전히 안착된 최종 상태. 카운터 0 리셋.
- **컴포넌트**: `ShotButton`, `PenaltyButton` (11-COMPONENTS §6, §7)
- **플로우**: 모션 시퀀스 종료 → F-C 재개 (02-USER_FLOWS F-C)
- **인터랙션**: 안착 시 HoleProgress 점 인디케이터 8번 위치 하이라이트 전환
- **Stitch 특이점**: watch-3.1과 동일한 레이아웃이나 홀 번호·par·카운터만 교체되어 일관성 확인됨.

### watch-3.5 — 동반자 전환 오버레이

- **파일**: `screens/watch/apple_watch_player_switch_overlay/screen.png` (stitch:screens/watch/apple_watch_player_switch_overlay/)
- **요약**: 상/하 스와이프 시 본인 ↔ 동반자 전환. 동반자 별명 오버레이 표시. (spec_3.md:98)
- **컴포넌트**: `PlayerChip` (readonly 변형) (11-COMPONENTS §5)
- **플로우**: F-C 동반자 전환 분기 (02-USER_FLOWS F-C)
- **인터랙션**: 상/하 스와이프 → `.click × 2` 햅틱 + 동반자 칩 하이라이트 (13-HAPTICS_AND_MOTION §3)
- **Stitch 특이점**: 현재 플레이어 이름이 화면 중앙 대형 텍스트로 잠깐 나타났다 사라지는 toast 방식 처리가 Watch 화면 크기 제약에 최적화됨.

### watch-3.6 — 라운드 종료 메뉴

- **파일**: `screens/watch/apple_watch_round_end_menu/screen.png` (stitch:screens/watch/apple_watch_round_end_menu/)
- **요약**: "라운드 종료" 선택 메뉴. 종료 / 취소 2가지 옵션. (spec_3.md:109)
- **컴포넌트**: (Watch 시스템 메뉴)
- **플로우**: F-D 라운드 종료 시작 (02-USER_FLOWS F-D)
- **인터랙션**: "종료" 탭 → watch-3.7 확인 화면 / "취소" 탭 → watch-3.1 복귀
- **Stitch 특이점**: 2화면 분리(watch-3.6 메뉴 + watch-3.7 확인)로 오터치 방지가 잘 구현됨. Stitch 보라 버튼 → `--green-primary` 교체 필요.

### watch-3.7 — 라운드 종료 확인

- **파일**: `screens/watch/apple_watch_round_end_confirmation/screen.png` (stitch:screens/watch/apple_watch_round_end_confirmation/)
- **요약**: 최종 종료 확인 다이얼로그. 홀별 요약 요약 정보 1줄 표시. (spec_3.md:109)
- **컴포넌트**: (Watch 시스템 얼럿)
- **플로우**: F-D 명시적 종료 Step 1 완료 → iPhone 요약 화면 전환 (02-USER_FLOWS F-D)
- **인터랙션**: 확인 탭 → `.stop` 햅틱 (Watch) + `.success` (iPhone) 동시 발화 → iphone-2.6 라운드 종료 요약으로 전환 (13-HAPTICS_AND_MOTION §4)
- **Stitch 특이점**: Watch 화면에서 종료 확인 후 iPhone이 자동으로 요약 화면으로 전환되는 양방향 동기화 흐름을 시안이 정확히 묘사함.

---

## 7. Viewer 웹 화면 카탈로그 (5화면)

### web-4.1 — 모바일 웹 뷰어 메인

- **파일**: `screens/mobile-web/round_on_mobile_web_viewer/screen.png` (stitch:screens/mobile-web/round_on_mobile_web_viewer/)
- **요약**: full-bleed 대표 사진 hero + 총 타수 대형 표시 + 스코어 표 + 사진 그리드 + ZIP 다운로드 버튼. (spec_3.md:147-151)
- **컴포넌트**: (Viewer HTML 전용 DOM 컴포넌트 — 31-VIEWER_HTML §2)
- **플로우**: F-F 공개 viewer 2단계 진입 — `GET /{shortId}` → HTML 즉시 응답 (02-USER_FLOWS F-F)
- **인터랙션**: 사진 그리드 탭 → web-4.3 라이트박스 / ZIP 다운로드 탭 → R2 signed URL
- **Stitch 특이점**: full-bleed 사진 hero + 큰 스코어 텍스트 에디토리얼 배치가 31-VIEWER_HTML §2 정상 라우트 마크업 계약과 정합. 보라 accent 버튼 → `--green-primary` 교체.

### web-4.2 — PIN 잠금 화면

- **파일**: `screens/mobile-web/round_on_web_viewer_pin_lock/screen.png` (stitch:screens/mobile-web/round_on_web_viewer_pin_lock/)
- **요약**: 자물쇠 아이콘 + PIN 4자리 입력 박스 4개 독립 배치 + "확인" 버튼. (spec_3.md:148)
- **컴포넌트**: (Viewer HTML PIN 입력 DOM)
- **플로우**: F-F PIN 보호 viewer 분기 — `GET /{shortId}` → PIN flag → PIN 입력 화면 → `POST /{shortId}/verify-pin` (02-USER_FLOWS F-F, 33-SECURITY §5)
- **인터랙션**: 4자리 완성 → 자동 `POST` 전송 / 오류 시 429 → "5회 오류, 잠시 후 재시도" 안내 (30-API_SPEC §7)
- **Stitch 특이점**: 숫자 패드와 4개 독립 박스 배치가 33-SECURITY §5 `POST /{shortId}/verify-pin` 엔드포인트와 정합. 보라 버튼 교체만 필요.

### web-4.3 — 사진 라이트박스

- **파일**: `screens/mobile-web/round_on_web_lightbox/screen.png` (stitch:screens/mobile-web/round_on_web_lightbox/)
- **요약**: 사진 전체 화면 + 인덱스 표시 + 좌/우 이동 + 닫기. (spec_3.md:205-213)
- **컴포넌트**: (Viewer HTML 라이트박스 DOM — 31-VIEWER_HTML §7)
- **플로우**: F-G 사진 다운로드 진입점 (02-USER_FLOWS F-G)
- **인터랙션**: 사진 길게 누르기 → iOS 네이티브 컨텍스트 메뉴 "사진 저장" / Android는 "이미지 저장" 시스템 메뉴 (31-VIEWER_HTML §6)
- **Stitch 특이점**: `<img>` 직접 제공 방식으로 OS 네이티브 저장 메뉴 활성화 — 별도 다운로드 버튼 없이도 사용자 직관으로 저장 가능. (31-VIEWER_HTML §6)

### web-4.4 — 사진 저장 플로우 문서화

- **파일**: `screens/mobile-web/round_on_photo_save_flow_documentation/screen.png` (stitch:screens/mobile-web/round_on_photo_save_flow_documentation/)
- **요약**: OS별(iOS/Android/데스크톱) 사진 저장 동작 매트릭스 시각화. 구현 사양서 성격의 화면. (spec_3.md:205-213)
- **컴포넌트**: (내부 문서화 화면 — 런타임 미노출)
- **플로우**: F-G 분기 매트릭스 (02-USER_FLOWS F-G, 31-VIEWER_HTML §6)
- **인터랙션**: 해당 없음 (사양서)
- **Stitch 특이점**: 31-VIEWER_HTML §6 동작 매트릭스(iOS/Android/데스크톱 × 사진/ZIP 저장 조합)를 시각 표로 정리한 개발자 참조 화면. 사용자에게는 노출되지 않음.

### web-4.5 — 만료/오류 페이지

- **파일**: `screens/mobile-web/round_on_web_viewer_error_states/screen.png` (stitch:screens/mobile-web/round_on_web_viewer_error_states/)
- **요약**: 410 만료 / 404 없음 / 429 PIN 잠금 3개 오류 상태 프레임. (spec_3.md:148)
- **컴포넌트**: (Viewer HTML 에러 페이지 DOM — 31-VIEWER_HTML §8)
- **플로우**: F-F 비정상 분기 처리 (02-USER_FLOWS F-F)
- **인터랙션**: 각 오류별 안내 메시지 + "앱으로 돌아가기" 딥링크 옵션
- **Stitch 특이점**: 3개 상태를 한 화면에 병렬 배치하여 비교 검토가 쉬운 구성. 410 (7일 만료), 404 (존재하지 않는 shortId), 429 (PIN 5회 오류)가 30-API_SPEC §7 에러 코드와 정합.

---

## 8. 화면-플로우 매핑

02-USER_FLOWS F-A~F-G 7개 플로우와 Stitch 화면 22종의 대응 관계. (02-USER_FLOWS §플로우 목차)

| 플로우 ID | 플로우 이름 | 주요 화면 | 분기 화면 |
|---------|-----------|---------|---------|
| F-A | 앱 첫 실행 / 골프장 자동 매칭 | iphone-2.1 → iphone-2.2 | 위치 권한: iOS 시스템 다이얼로그 (Stitch 미제공) |
| F-B | 라운드 시작 | iphone-2.2 → iphone-2.3b | holesCount > 18: SubCourseSelector 표시 (Stitch 미제공) / holesCount nil: 홀 수 입력 프롬프트 / Watch 미연결 → iPhone 단독 |
| F-C | 점수 입력 (핵심) | watch-3.1 + iphone-2.3b 동시 | 홀 이동: watch-3.2 → 3.3 → 3.4 / 동반자 전환: watch-3.5 / 페널티: iphone-2.4 |
| F-D | 라운드 종료 / 자동 재개 | watch-3.6 → watch-3.7 → iphone-2.6 | 자동 재개: iphone-2.1 재실행 다이얼로그 (Stitch 미제공) |
| F-E | Viewer 공유 생성/업데이트 | iphone-2.6 → iphone-2.7 → iOS 공유 시트 | 재공유: iphone-2.8 → iphone-2.7 (업데이트 모드) |
| F-F | Viewer 방문 (PIN 분기) | web-4.1 (공개) 또는 web-4.2 → web-4.1 (PIN) | 오류: web-4.5 (410/404/429) |
| F-G | 사진 다운로드 | web-4.1 → web-4.3 → OS 네이티브 저장 | 사진 저장 동작 매트릭스: web-4.4 참조 |

### Stitch 미제공 화면 목록

일부 화면은 사용자 플로우에서 반드시 거쳐야 하나 Stitch 시안에 포함되어 있지 않다. 구현 단계에서 직접 설계가 필요하다.

| 미제공 화면 | 플로우 | 처리 방침 |
|-----------|--------|---------|
| 위치 권한 요청 다이얼로그 | F-A | iOS 시스템 표준 얼럿 — 커스텀 UI 없음 (spec_3.md:657-659) |
| 강제 종료 후 자동 재개 다이얼로그 | F-D | `.alert(isPresented:)` 시스템 기본 사용 (spec_3.md:107-108) |
| HealthKit 권한 요청 | F-B | iOS 시스템 표준 권한 시트 (spec_3.md:116-119) |
| Watch 미연결 안내 배너 | F-B | `BannerNotice` 컴포넌트 재사용 (11-COMPONENTS §10) |
| 수동 골프장 검색/선택 | F-A 분기 | 검색 시트 — 별도 설계 필요 (spec_3.md:634-635) |
| 서브코스 라벨 선택 | F-B | SubCourseSelector — 27/36홀 골프장에서 표시 (Stitch 미제공, 11-COMPONENTS §10) |

### 화면 전환 타입 요약

각 화면 진입 방식(SwiftUI 트랜지션 패턴). 상세 스펙은 13-HAPTICS_AND_MOTION §5 참조.

| 전환 | 화면 쌍 | SwiftUI 패턴 | 타이밍 |
|------|--------|------------|--------|
| 탭바/홈 진입 | → iphone-2.1 | `NavigationStack` root | — |
| 새 라운드 시작 | iphone-2.1 → iphone-2.2 | push (trailing) | `--motion-default` |
| 라운드 진행 | iphone-2.2 → iphone-2.3b | push (trailing) | `--motion-default` |
| 공유 모달 | iphone-2.6 → iphone-2.7 | `.sheet` bottom-up | `--motion-default` |
| 페널티 모달 | iphone-2.3b → iphone-2.4 | `.sheet` bottom-up | `--motion-default` |
| Watch 홀 이동 | watch-3.1 → watch-3.2~4 | `TabView(.page)` slide | `--motion-short` |
| Watch 동반자 전환 | watch-3.1 (overlay) | ZStack overlay | `--motion-instant` |
| 라이트박스 | web-4.1 → web-4.3 | `.fullScreenCover` scale+fade | `--motion-default` |

---

## 9. 책임 경계

본 specs/ 시리즈 내 문서 간 역할 분담.

| 문서 | 담당 범위 |
|------|---------|
| **본 문서 (12-SCREENS)** | Stitch 시안 22화면 ↔ specs/ 매핑, 색상/폰트 교체 정책 (D-2, D-3), ScoreCell Variant B 정식 확정 (D-1), par-diff 마커 색상 (D-4) |
| `00-OVERVIEW.md` | 제품 정체성, 배경, 타겟 사용자 — 화면별 상세 없음 |
| `02-USER_FLOWS.md` | F-A~F-G 7개 플로우 시퀀스 다이어그램 — 화면 간 이동 논리 |
| `10-DESIGN_SYSTEM.md` | 컬러 토큰 정의 (Spring/Summer/Autumn/Winter), 타이포 토큰, 간격 토큰 — 본 문서 교체 대상 원천 |
| `11-COMPONENTS.md` | 컴포넌트 props / 상태 / 변형 명세 — ScoreCell 변형 선택을 12-SCREENS에 위임 |
| `13-HAPTICS_AND_MOTION.md` | 햅틱 이벤트 매핑, 트랜지션 패턴, 타이밍 토큰 — Watch 홀 전환 3프레임(watch-3.2/3.3/3.4)과 매핑 |
| `21-DATA_MODEL.md` | SwiftData 엔티티 스키마 — 화면이 표시하는 데이터 모델 원천 |
| `30-API_SPEC.md` | Cloudflare Worker API 엔드포인트 — iphone-2.7 공유 생성/web-4.5 오류 코드 매핑 |
| `31-VIEWER_HTML.md` | Viewer HTML 마크업 / DOM 컴포넌트 — web-4.1~4.5 구현 계약 |
| `33-SECURITY.md` | PIN 검증 엔드포인트 `POST /{shortId}/verify-pin` — web-4.2 PIN 잠금 화면과 정합 |
| **Stitch 시안 (`Ref-docs/design-stitch/`)** | 시각 목업 PNG + DESIGN.md (브랜드/스타일 텍스트) — 본 문서가 참조하는 입력 원천 |
| **구현 단계** | 실제 SwiftUI 코드, 색상/폰트 토큰 적용, Stitch HTML CSS 변수 교체 스크립트 |
| `14-ACCESSIBILITY.md` (작성 예정) | VoiceOver 레이블, Dynamic Type — 화면별 접근성 상세 |

---

## 10. 부록: 후속 보완 TODO + DESIGN.md 자체 모순 정리

### Stitch DESIGN.md 자체 모순 (iphone/watch/mobile-web 3개 동일 파일)

Stitch가 자동 생성한 frontmatter와 수동 작성된 본문 사이에 3종의 모순이 확인된다. (stitch:screens/DESIGN.md)

| 항목 | frontmatter 값 | 본문 텍스트 값 | 채택 |
|------|--------------|-------------|------|
| 색상 primary | `#4f378a` (Material You 보라) | "Spring Palette: primary #7FB069" 언급 | **본문 채택 → D-2로 그린 교체** |
| display/body 폰트 | Hanken Grotesk | "SF Pro Display / Pretendard" 명시 | **본문 채택 → D-3으로 확정** |
| 수치 폰트 | JetBrains Mono | "SF Mono for all numerical scoring data" 명시 | **본문 채택 → D-3으로 확정** |

결론: DESIGN.md frontmatter는 Stitch가 Material You 기본 테마를 덮어쓰지 못한 결과다. 본문 텍스트(특히 Brand & Style, Typography, Colors 섹션)만 신뢰한다. "The Gallery of the Green" 컨셉 및 에디토리얼 레이아웃 철학은 우수하여 그대로 채택.

### 후속 보완 TODO

| # | 항목 | 담당 시점 |
|---|------|---------|
| 1 | Stitch `code.html` CSS 변수를 라운드온 토큰으로 일괄 교체하는 grep/replace 스크립트 작성 | 구현 단계 시작 시 |
| 2 | `14-ACCESSIBILITY.md` 작성 시 본 문서 화면별 VoiceOver 레이블 보강 (22화면 × 주요 요소) | 14번 문서 작성 시 |
| 3 | `DataQualityBadge` medium/high/unknown 3종 시안 미제공 — 11-COMPONENTS §10 명세만 존재, 구현 단계에서 직접 렌더링 테스트 필요 | 구현 단계 |
| 4 | Stitch `round_on` 폴더 (iphone/watch/mobile-web 각각 내 `round_on` 하위 폴더) 내 추가 자산 확인 — 본 카탈로그에 반영된 22화면 외 보조 자산 여부 검토 | 구현 착수 전 |
| 5 | web-4.4 사진 저장 플로우 문서화 화면은 런타임 미노출 사양서 — 31-VIEWER_HTML §6 동작 매트릭스와 최종 정합 검증 | 31-VIEWER_HTML 업데이트 시 |

---

*최종 업데이트: 2026-05-12*
