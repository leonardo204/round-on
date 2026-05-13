# 라운드온 (Round-On) — Google Stitch 작업 프롬프트 모음

> **작성일**: 2026-05-12
> **버전**: v2 (디자인 강도 보강)
> **출처**: [기능 명세서 v4](../specs/01-SPEC.md) §10.2 (704-762), specs/ 시리즈 15종
> **Stitch URL**: https://stitch.withgoogle.com/
> **참고**: getdesign.md (모던 앱 디자인 트렌드 분석) — 2026-05-12 추가 반영

## 변경 이력

- **v2 (2026-05-12)** — 첫 작업 결과(스크린샷)에서 발견된 문제 대응:
  - Stitch가 지정 hex(#7FB069)를 무시하고 Material You 디폴트 보라색 사용
  - 평범한 둥근 카드 + 가운데 일러스트 = 10년 전 Material 1.0 톤
  - **대응**: 색상 강제 명시, 안티패턴 일람 추가, 현대 레퍼런스 강화
    (Linear / Vercel / Stripe / NYT Athletic / Apple Fitness)
  - **§0 공통 베이스 프롬프트 전면 재작성**: COLOR STRICT 섹션,
    ANTI-PATTERNS 섹션, PREMIUM CUES 섹션 추가
  - **§1 디자인 시스템 페이지 재작성**: editorial documentation 톤
  - **§2.1 홈 / §2.2 새 라운드 / §2.3 라운드 진행 재작성**: editorial
    magazine 레이아웃, asymmetric, 가운데 정렬 일러스트 제거
  - **§3.1 Watch 메인 재작성**: sports broadcast 톤, 다크 모드 디폴트
  - **§4.1 Viewer 메인 재작성**: editorial sharing, full-bleed photo
- **v1 (2026-05-12)** — 초안 작성. 01-SPEC.md §10.2 기반 18화면 프롬프트.

---

## 사용법

1. 아래 프롬프트를 복사해 Stitch에 붙여넣기
2. Stitch는 **App / Web** 2개 분류만 지원:
   - **App 프로젝트** → iPhone 9화면 + Apple Watch 4화면 (Watch는 작은 frame으로 같은 프로젝트에 추가)
   - **Web 프로젝트** → Viewer 5화면
3. Export: **"AI Studio" 옵션 선택** → HTML + 이미지 파일이 자동 다운로드됨
4. 다운로드된 산출물을 본 폴더에 저장:
   - PNG 이미지 → `Ref-docs/design-stitch/screens/`
   - HTML 파일 → `Ref-docs/design-stitch/html/`
5. 완료 후 Claude Code에게 "12-SCREENS.md 작성해줘" 요청 — PNG + HTML + specs/ 조합으로 자동 처리

> **도구 정책 (디자이너 없는 1인 개발 환경)**
>
> - **메인 도구**: Google Stitch (App + Web)
> - **Export 형식**: AI Studio (HTML + PNG 동시 다운로드). Figma/MCP/zip 미사용
> - **인계 노트는 선택 사항**: 사용자가 작성할 필요 없음. Claude Code가 PNG/HTML/specs/를 직접 읽고 컴포넌트·토큰·인터랙션을 추정. 수정이 필요한 사항만 채팅으로 알려주시면 됨
> - **Figma 미사용**: 1인 개발이라 불필요
> - **보조 도구 (선택)**: Stitch가 만든 Viewer HTML을 Claude.ai Artifacts에 붙여넣어 즉시 렌더링·디버깅 가능
> - **Apple Watch 처리**: Stitch App 카테고리에서 작은 frame(198pt 폭)으로 추가 작업. 너무 작아 디테일이 부족하면 Claude Code가 specs/ 기반 보완

---

## 산출물 일람 (총 18화면 + 디자인 시스템 페이지)

| 카테고리 | 화면 수 |
|---------|------|
| 디자인 시스템 페이지 | 1 (팔레트/타이포/컴포넌트 카탈로그 통합) |
| iPhone | 9화면 |
| Apple Watch | 4화면 |
| Viewer 웹 | 5화면 |

---

## 0. 공통 베이스 프롬프트 (모든 작업 첫머리에 포함) — v2 (2026-05-12 강화)

> **v1 문제점 (2026-05-12 첫 작업 후 발견)**:
> Stitch가 우리가 지정한 Spring 그린(#7FB069)을 무시하고 Material You 디폴트 보라색을 사용. 평범한 둥근 카드 + 가운데 정렬 일러스트 + 회색 배경 = 10년 전 Material 1.0 톤. **v2는 색상 강제 + 안티패턴 명시 + 현대 레퍼런스 강화**로 재작성.

```
Premium Korean golf score-tracking app called "라운드온 (Round-On)".
Reference quality: think Linear, Vercel, Apple Fitness, Strava editorial,
Notion serif moments, Day One Journal warmth.
Visual mood: editorial magazine, cinematic, content-first, premium minimalist
Korean gallery aesthetic. Whitespace as luxury. Photography over illustration.

==========================================================
COLOR — STRICT, DO NOT USE DEFAULTS
==========================================================
Reject any Material You default purple, Tailwind indigo, or generic
"Stitch primary purple". This app uses a "four-seasons-grass" green system.

Spring (light default) — use EXACTLY these hex codes:
  primary           #7FB069   (fresh grass green — main brand)
  secondary         #B8D8B0
  accent            #C5E1A5
  surface           #FAFCF7   (off-white with green undertone, NOT pure white)
  surface-elevated  #FFFFFF
  text-primary      #1F2A1B   (deep forest, near-black with green hint)
  text-secondary    #5A6850
  border            #E8EFE0

Winter (dark default) — use EXACTLY these:
  primary           #5A8A6B
  secondary         #2A3F35
  accent            #8FB5A0
  surface           #0F1612
  surface-elevated  #1A241E
  text-primary      #E8F0EA
  text-secondary    #9AAA9F
  border            #2A3530

Color usage rules:
- Primary green is for CTAs, current-state highlights, and brand moments ONLY.
- Most surfaces are surface or surface-elevated. Green should feel earned,
  not splashed everywhere.
- Score numbers use text-primary (near-black), not green. Reserve green for
  par-relative chips (eagle/birdie) and active states.
- NEVER use pastel purple, pastel pink, or "Material You wallpaper" tones.

==========================================================
TYPOGRAPHY — EDITORIAL HIERARCHY
==========================================================
- Headings (course names, screen titles): SF Pro Display, weight 600-700,
  tight tracking. Korean: Pretendard equivalent weight.
- Big score numbers: SF Mono or SF Pro Display, weight 600. Tabular figures.
  Watch score 56pt, iPhone score 44pt, summary hero 96pt+.
- Body: SF Pro Text 17pt regular.
- Captions: 13pt with text-secondary color.
- Korean must look intentional, not afterthought — Pretendard is the
  preferred Korean face for web viewer.
- NO playful rounded display fonts. NO comic-style emoji. NO decorative
  scripts.

==========================================================
LAYOUT — ASYMMETRIC, EDITORIAL, CONFIDENT
==========================================================
- 8pt base grid. Screen padding 16pt minimum, 24pt for hero sections.
- Radii: 12pt for cards, 16pt for modals/sheets, 8pt for chips and small
  buttons. NEVER full-pill rounded everywhere.
- Shadows: extremely minimal.
  elevation-1: 0 1px 2px rgba(15, 22, 18, 0.06)
  elevation-2: 0 4px 12px rgba(15, 22, 18, 0.10)
- Asymmetric > centered. Hero data left-aligned. Numbers prominent.
  Photos full-bleed when present.
- Inspired by editorial magazine spreads, not iOS settings page.

==========================================================
ANTI-PATTERNS — DO NOT DO ANY OF THESE
==========================================================
- Default Material You purple (#6750A4 family) anywhere
- Centered cartoon mascots or hero illustrations as empty-state
- Generic "+ button" floating in the middle of a screen
- Rounded-corner cards stacked vertically with no visual hierarchy
- Gradient backgrounds (NO purple-to-pink, no aurora)
- Glassmorphism, frosted blur surfaces
- Emoji in UI labels (no 🏌️, no ⛳, no 🌱)
- Skeuomorphic textures (no grass texture, no leather, no green felt)
- Apple Watch faces that look like classic Material cards (Watch uses
  full-bleed type, edge-to-edge layout)
- Pastel highlight stickers as decoration

==========================================================
PREMIUM CUES — DO INCLUDE
==========================================================
- Generous whitespace, especially top and bottom of screens
- A single accent action per screen (one filled CTA max)
- Large, confident numbers with tabular-figure spacing
- Subtle border (1px, color = --border) instead of shadow where possible
- Real photo thumbnails (mock golf-course aerial shots, not illustrations)
- Editorial typography hierarchy — display weight differences should
  be visible at a glance
- Korean text feels native, not translated — line-heights are roomy
- Dark mode (Winter palette) used confidently for night-mode mockups,
  not just inverted light mode

WCAG AA contrast (4.5:1) for outdoor sunlight readability.
This is not a toy app. It is the kind of app you would screenshot and
post on Twitter saying "this is so well designed."
```

---

## 1. 디자인 시스템 페이지 (1화면) — v2 editorial

```
[공통 베이스 프롬프트 붙여넣기]

Design system reference page in the style of Linear's brand guide,
Vercel's design system docs, or Stripe's brand assets page. Editorial
documentation, NOT a Material You "color preview" page.

LAYOUT: 4-column grid, one column per season. Use a tall portrait
canvas (e.g., 1600×2400px) so each column has breathing room.

COLUMN HEADER (per season):
- Top: huge season number "01 / 02 / 03 / 04" 96pt/700 ultra-light gray
  --text-secondary (background label).
- Below in display weight: "Spring / Summer / Autumn / Winter" 32pt/600
  --text-primary.
- Korean translation below: "봄 / 여름 / 가을 / 겨울" 17pt/500
  text-secondary.
- Brief one-line poetic descriptor: "fresh grass after morning rain"
  (Spring), "high noon, vivid greens" (Summer), "warm fairway, late
  October" (Autumn), "frost on the green, dawn round" (Winter).
  15pt italic Pretendard or SF Pro Display italic.

COLOR TOKEN GRID (per column):
- Each color token displayed as a horizontal row, NOT a stack of square
  swatches. Row contains:
  - Left: color rectangle 64×40pt with 1px border for off-whites.
  - Middle: token name in SF Mono 13pt --text-primary
    "--green-primary"
  - Right: hex value monospaced 13pt text-secondary "#7FB069"
- Total 8 rows per column. Magazine spec sheet style.

TYPOGRAPHY SAMPLE (mid-column):
- Big "라운드온" 56pt/700 in column's --text-primary on column's --surface
  background swatch (full column width, 160pt tall block).
- Below: "스카이힐 골프클럽" 22pt body.
- Big score sample: "82 (+10)" in tabular figures 44pt/700.

COMPONENT SAMPLES (bottom of column):
- Filled primary button "라운드 시작" (full width)
- Tinted secondary button "변경"
- Plain text link "+ 추가"
- Card with elevation-1: course mock card with photo strip
- Penalty row: "OB +2" / "해저드 +1" / "OK +1" chips inline
- Par-diff chips row: eagle (○○4), birdie (○4), par (4), bogey (□5),
  double-plus (□□6) — show the circle/square treatment.

OVERALL CANVAS:
- Background --surface for the page.
- Faint vertical 1px --border lines between columns.
- Top of page: page title "라운드온 디자인 시스템" 28pt + sub
  "Four-seasons-grass design system · v1 · 2026-05-12" 13pt text-secondary.

NO Material You wallpaper-extracted purple comparison. NO emoji icons
on column headers. NO drop-shadow color cards. Just editorial typography
and disciplined hex specifications.
```

---

## 2. iPhone 화면 (9화면)

각 iPhone 화면은 **iPhone 15/16 size frame (390×844 pt)** 기준.

### 2.1 홈 화면 (최근 라운드 리스트) — v2 editorial

```
[공통 베이스 프롬프트 붙여넣기]

iPhone home screen for Round-On. Editorial, magazine-style layout.

TOP — Editorial header (NOT a generic nav bar):
- Massive headline "라운드온" in display weight 700, 40pt, left-aligned,
  with generous 32pt top padding (under safe area).
- Right side aligned: subtle text-link "+ 새 라운드" (NOT a filled button,
  NOT a floating action button). Tap-target preserved with 44pt height.

SECONDARY HEADER:
- One line below: count summary "라운드 12회 · 이번 시즌 평균 +8"
  in text-secondary, 15pt. This is editorial chrome, not a stat card.

LIST — Hero round card (most recent, full-bleed):
- Edge-to-edge photo banner of golf course (16:9, real aerial shot mock),
  rounded radius-md only at top, full width.
- Below photo on same card surface: course name "스카이힐 골프클럽" big
  (22pt/600), sub "동코스 · 2026-05-08" 14pt text-secondary.
- Score row at bottom of card: "82" massive (44pt/700 tabular figures),
  "(+10)" 17pt text-secondary right next to it.
- Card has 1px border (--border), NO shadow. Premium magazine card feel.

LIST — Compact rounds (rest of list):
- Each row: small square thumbnail 56×56 radius-sm on left, text middle
  (course name 17pt, date 13pt text-secondary), score right-aligned
  "79 (+7)" with score in tabular figure 20pt, par-diff small.
- 1px bottom divider (--border), NO card boxes, NO shadows. Reads like
  an editorial list, not a Material Design list.

EMPTY STATE (when no rounds):
- NO centered mascot. Use editorial style:
  - Big quoted headline left-aligned: "첫 번째 라운드를 기록하세요"
    (24pt/600).
  - Sub: "한 번 탭할 때마다 한 타. 라운드 끝나면 사진과 함께 친구들에게
    공유." (15pt text-secondary, line-height generous).
  - One filled primary CTA button "라운드 시작" 56pt tall, aligned to
    left content. NOT centered on screen.

TAB BAR (bottom):
- Two tabs only: 라운드 / 설정. Use SF Symbols line icons (no filled
  shapes). Selected uses primary green for icon+label, deselected
  text-secondary. NO pill background on selected tab. NO purple.

Use Spring palette. Background = --surface. Cards on --surface-elevated.
```

### 2.2 새 라운드 시작 화면 — v2 editorial

```
[공통 베이스 프롬프트 붙여넣기]

iPhone "New Round" screen. NO Material chrome. Editorial form layout.

TOP:
- Back chevron (line, --text-primary, NO circle background) top-left.
- Display title "새 라운드" 28pt/700 left-aligned, 24pt top padding.
- NO centered nav title.

SECTION 1 — Course (hero card):
- Section caption "코스" 13pt/500 text-secondary, uppercase tracking +0.5.
- Below: full-width course hero block. Top half: course aerial photo
  thumbnail (16:9), bottom half on same card: course name
  "스카이힐 골프클럽" 22pt/600 + sub "동코스" 15pt text-secondary.
- Meta row inline (single line, separated by ·): "1.2km · 자동 선택됨".
- "변경" plain text link bottom-right of card (NOT a filled button).
- Border 1px (--border), NO shadow.
- DataQualityBadge — show as inline warning ROW below card (NOT pill):
  small caution line icon + "GPS 홀 자동 감지 미지원 코스 · 수동으로
  홀을 넘겨주세요" 13pt --text-secondary, with subtle left border accent
  in --text-secondary (dashed 1px). Magazine sidebar feeling.

SECTION 2 — Players:
- Section caption "동반자" 13pt/500 text-secondary uppercase.
- Player chips row, but bigger and more deliberate:
  - "나" chip — solid --primary bg with white text 15pt/500, radius-sm
    8pt, h=36, leading dot indicator.
  - "동반자1" / "동반자2" — outlined chips (1px --border), --text-primary
    text, trailing tiny pencil icon. Same height.
  - "+ 추가" — text link only, NO button bg, --text-secondary.
- NOT pill-rounded full-circle. Use 8pt radius for that "intentional
  chip" feel, not "decoration".

SECTION 3 — Workout toggle:
- Section caption "건강 데이터" 13pt/500 text-secondary uppercase.
- Full-width row: left = "Apple 건강 워크아웃" 17pt + sub
  "걸음·심박·칼로리·시간" 13pt text-secondary. Right = iOS standard toggle
  (when on, uses --primary green).
- 1px bottom divider, NO card box.

BOTTOM CTA (sticky):
- Filled primary "라운드 시작" 56pt tall, full width minus 16pt padding,
  radius 12pt. Text 17pt/600 white. Safe-area-aware.
- ABOVE the button: small reassurance caption centered 12pt text-secondary
  "위치 권한이 필요합니다" (when permission not yet granted) — editorial
  pre-flight note.

Background = --surface. Sections separated by 24pt vertical space, not
visual dividers. Use Spring palette.
```

### 2.3 라운드 진행 화면 (스코어카드) — v2 editorial

```
[공통 베이스 프롬프트 붙여넣기]

iPhone round-in-progress screen. MOST IMPORTANT screen of app — should
feel premium, confident, glanceable in sunlight. Editorial sports/data
publication feel (think NYT Athletic, Strava workout summary, Apple
Fitness summary).

CRITICAL: design BOTH variants A and B as separate frames so we can
compare and decide later.

COMMON TOP HEADER (both variants share):
- Compact bar with course name (left, 15pt/500 text-secondary)
  "스카이힐 · 동코스" — small uppercase tracking, NOT a big nav title.
- "라운드 종료" plain link top-right 15pt --text-secondary, NO button bg.

HERO STATE (between header and grid):
- Massive current-hole display, left-aligned, full bleed (24pt side padding):
  - "H7" 13pt/500 text-secondary uppercase tracking
  - "Par 4" 13pt next to it, same row
  - Below: massive number "4" or "5" current score 96pt/700 tabular
    figures, --text-primary
  - Inline next to number: subtle par-diff "(+1)" 28pt/500 text-secondary
- HoleProgress bar BELOW number, NOT 18 dots — use thin horizontal
  progress strip (4pt tall) with 18 segments, completed = --primary,
  current = --accent with subtle glow, upcoming = --border. Cleaner
  than 18 separate dots.

PLAYER ROW (under hero):
- Horizontal scrollable chips, 4 player tabs. Active = filled --primary
  background + white text. Inactive = transparent + --text-primary text
  with subtle 1px --border. 36pt tall, radius-sm. Tap switches active.
- NOT centered, NOT pill-shaped full-rounded.

================ VARIANT A — horizontalScroll grid ================
- 4 player rows × 18 hole columns, horizontally scrollable.
- Player name column FIXED on left (sticky), 64pt wide, surface-elevated.
- Hole columns each ~48pt wide.
- Each cell: par tiny 11pt/500 text-secondary at top, score big
  24pt/600 tabular at center.
- Par-relative color treatment (NOT solid bg fills — use subtle markers):
  .eagle    → 2 concentric circles around number (border, --primary)
  .birdie   → 1 circle around number (border, --primary)
  .par      → no decoration, default --text-primary
  .bogey    → 1 square outline around number (border, --text-secondary)
  .double-plus → 2 square outlines, slightly dimmed --text-secondary
  This is a golf-scorecard tradition — circles for under par, squares
  for over par. Looks editorial, not Material chip.
- Current hole column highlighted with --accent at 12% opacity (subtle).
- Sticky bottom totals row: OUT (1-9 sum), IN (10-18 sum), TOT — 17pt/700
  with thin top border.

================ VARIANT B — split9x2 stacked ================
- Two stacked compact tables: OUT (홀 1-9) above, IN (홀 10-18) below.
- Each table 4 player rows × 9 hole columns, fits in 390pt width.
- Same circle/square par-diff treatment.
- Mini total column at far-right of each table (OUT sum / IN sum).
- Grand total chip below both tables, right-aligned, larger
  (e.g., "82 (+10)" tabular 28pt/700, --text-primary).

==================================================================

BOTTOM ACTION BAR (shared, sticky, safe-area aware):
- Single hero "+1" filled primary button — large rectangle, NOT circle,
  takes 100% width minus padding minus penalty buttons, h=72pt,
  radius-md 12pt, label "+1 타" 22pt/700 white. Subtle haptic feeling
  via 1px inner highlight (very subtle).
- Below or beside, smaller penalty row: three pill-shaped tinted chips
  "OB +2" / "해저드 +1" / "OK +1", each h=44pt radius-sm, --secondary bg,
  --text-primary text 13pt/600. ONE ROW horizontal.
- Long-press on "+1" = decrement (annotate as tooltip in design notes).

CRITICAL: do NOT use Material elevation cards stacked vertically.
Score grid should feel like a sports broadcast scorecard graphic,
not a settings list.

Background = --surface. Use Spring palette by default. Show both variants
A and B as separate frames in same Stitch project.
```

### 2.4 페널티 입력 모달

```
[공통 베이스 프롬프트 붙여넣기]

iPhone penalty input modal. Bottom sheet (elevation-2, radius-lg top corners
only) over dimmed round-in-progress background.

Header: "Hole 7 페널티 입력" + close X top-right.

Three large buttons in a row (each 88×88pt with radius-md, tinted variant):
- "OB" with subtitle "+2"
- "해저드" with subtitle "+1"
- "OK" with subtitle "+1"

Below: history list of penalties already added in current hole, each row
deletable with trailing trash icon.

Cancel button at bottom (plain).
Use Spring palette.
```

### 2.5 사진 추가 화면

```
[공통 베이스 프롬프트 붙여넣기]

iPhone photo attach screen. Top: "사진 추가" title with X close.

Two large tappable cards (full width minus 16pt padding, side by side):
- "사진 라이브러리" card with photo grid preview icon
- "촬영" card with camera icon

Below: existing photos grid (PhotoGalleryGrid component, 3 columns, square
thumbnails, gap 8pt, radius-sm). Each thumbnail has trailing "X" overlay
to remove. Counter top-right "12 / 30".

If empty: "이 라운드에 첨부된 사진이 없습니다" centered placeholder.

Bottom: "완료" primary button.
Use Spring palette.
```

### 2.6 라운드 종료 / 요약 화면

```
[공통 베이스 프롬프트 붙여넣기]

iPhone round-end summary screen. Title "라운드 완료" with subtle confetti
or grass-leaf accent (subtle, not festive).

Section 1 — Big number:
- "82" massive (96pt+) with "(+10)" small below.
- "Par 72" caption.

Section 2 — Stats row (3 columns of cards):
- "걸음 수 9,234" (HealthKit)
- "이동 거리 7.1km"
- "라운드 시간 4h 23m"

Section 3 — Hole-by-hole mini grid (read-only, smaller cells)

Section 4 — Photos preview strip (horizontal scroll, 5 thumbs visible)

Bottom actions:
- Primary filled "공유하기" (opens 2.7 share modal)
- Tinted "라운드 상세 보기"

Use Spring palette.
```

### 2.7 공유 옵션 모달

```
[공통 베이스 프롬프트 붙여넣기]

iPhone share-options bottom sheet (elevation-2, radius-lg top corners).
Header "공유 옵션" + X.

Settings rows:
- Toggle "동반자 이름 공개" — when off, shows "별명: A, B, C, D".
- Radio group "접근 권한":
  · 공개 (누구나 링크로 접근)
  · PIN 보호 (4자리)
- If PIN selected: 4-digit input field with numeric keyboard hint
- Photo count display: "사진 12장 포함"
- Caption: "공유 링크는 7일 후 자동 만료됩니다"

Bottom: large filled "공유 링크 생성" button.
After tap: loading state (button shows spinner), then iOS system share sheet
preview (Stitch can mock this as a simple bottom sheet with kakao/messages
icons).

Use Spring palette.
```

### 2.8 라운드 상세 (사후 보기, 사진 관리)

```
[공통 베이스 프롬프트 붙여넣기]

iPhone round-detail screen for completed rounds. Top bar with course name
+ back. Right side: "..." menu with "공유 회수" / "라운드 삭제" / "재공유".

Hero header: course thumbnail + date + final score "82 (+10)".

Tabs:
- 스코어카드 (default) — read-only 9홀×2단 grid same as 2.3 Variant B
- 사진 — PhotoGalleryGrid same as 2.5 (read-only, no add/remove)
- 통계 — Stats from 2.6 + per-hole bar chart

If round currently shared:
- Top banner card "공유 중 · 5일 남음" + "링크 복사" tinted button
  + "회수" plain destructive text button.

Use Spring palette.
```

### 2.9 설정 화면 (4계절 테마 포함)

```
[공통 베이스 프롬프트 붙여넣기]

iPhone settings screen. Title "설정" centered.

Banner notice at top (only if applicable):
- "iCloud 미연결 — 다른 기기와 동기화되지 않습니다" (warning level,
  tinted yellow accent).

Sections (grouped lists):

1. 테마
   - "테마 선택" with 4 color swatch chips: 봄 / 여름 / 가을 / 겨울
     (currently selected has checkmark + ring).
   - Caption: "시스템 라이트 모드 → 봄 / 다크 모드 → 겨울 자동 적용"

2. 알림
   - Toggle "라운드 알림"

3. 권한 (read-only summary, links to iOS settings)
   - 위치 (사용 중 허용)
   - 사진 (선택한 사진)
   - HealthKit (워크아웃)
   - 카메라

4. 정보
   - 앱 버전 1.0.0
   - 개인정보 처리방침 (links to 50-PRIVACY_POLICY)
   - 이용약관
   - 오픈소스 라이선스 — "© OpenStreetMap contributors, ODbL 1.0"

Use Spring palette.
```

---

## 3. Apple Watch 화면 (4화면)

각 Watch 화면은 **Apple Watch Series 10 (45mm: 198×242 pt)** 기준.

### 3.1 메인 점수 입력 화면 — v2 sport broadcast

```
[공통 베이스 프롬프트 붙여넣기]

Apple Watch main score-input screen. This is THE primary screen — 90% of
the round happens here. Should feel like a sports broadcast scoreboard
graphic, not a Material card. Glanceable from arm distance in sunlight.

Frame size: 45mm Watch (198pt × 242pt).

LAYOUT (edge-to-edge, NO card boxes):
- TOP STRIP (16pt tall, --text-secondary): "H7 · Par 4" left-aligned
  small caps, 13pt/500. NO background.
- BIG NUMBER (dominates center): score "4" rendered at 88pt/700 SF Compact,
  --text-primary, tabular figures, perfectly centered both axes.
  - Subtle par-diff "+0" directly below number, 17pt/500 text-secondary,
    NO parentheses, just sign + number. Eagle/birdie auto-applies primary
    green; bogey+ uses text-secondary muted.
- PLAYER CHIP (above number, very small): tiny pill 22pt tall, 1px border,
  current player initial "나" 11pt centered. NOT touchable directly
  (swipe to switch is the gesture).
- PENALTY ROW (bottom, 1pt above safe area):
  three text-only "tap targets" inline with vertical dividers, NOT
  rounded buttons. Each: "OB" / "해" / "OK" 13pt/600 --text-primary,
  44pt tall tap zone, separator = 1px --border vertical line.
  Tapping fires the +2 / +1 / +1 delta with subtle haptic.

CRITICAL: tap anywhere on the upper 70% of screen = +1 (giant invisible
tap zone, 198pt × ~140pt). Crown rotation also = ±1. No visible "tap
here" button needed.

DARK MODE (Winter) is the default for Watch — Apple Watch faces look
better in dark. Use surface #0F1612 as background. Show this variant
as the main mockup.

NO Material You purple ANYWHERE. NO floating action button. NO chip pills
that look like Material chips. Sports broadcast aesthetic.
```

### 3.2 홀 전환 애니메이션 (전환 중 화면)

```
[공통 베이스 프롬프트 붙여넣기]

Apple Watch hole-change transient screen (shown briefly during auto or
manual hole change).

Layout: large arrow "→" or "←" in --green-accent, with new hole indicator
"H8 · Par 5" centered. Subtle confetti dot pattern (optional, very minimal).

Show three frames as separate Stitch artboards to suggest motion:
1. Start: previous hole H7 fading out (opacity 0.4)
2. Middle: H8 number sliding in from right (split offset)
3. End: H8 fully displayed, ready for input

Total transition duration target: --motion-short 0.2s.
Haptic: WKHapticType.start fires on auto-change (note as annotation).

Use Spring palette.
```

### 3.3 동반자 전환 화면

```
[공통 베이스 프롬프트 붙여넣기]

Apple Watch player-switch overlay screen (shown when user swipes up/down).

Top: current hole reminder "H7 · Par 4" small.

Center column: vertical list of 4 player chips (large, with checkmark on
current). Each chip 36pt tall:
- 나 (current, green background, checkmark)
- 동반자1
- 동반자2
- 동반자3

Hint at bottom: "위/아래 스와이프로 전환" small caption with up/down arrow
icons.

Tap on any chip immediately switches (no confirmation).

Use Spring palette.
```

### 3.4 라운드 종료 메뉴

```
[공통 베이스 프롬프트 붙여넣기]

Apple Watch round-end menu (force-touch or long-press from main 3.1).

List of large tap rows (each row ~50pt tall, full width, tinted variant):
1. "라운드 종료" (destructive — red-tinted but using --warning subtle
   border, not bright red, to match calm aesthetic)
2. "사진 추가는 iPhone에서" — info text only (not tappable)
3. "다음 홀로 이동" — manual nav fallback
4. "이전 홀로 이동"
5. "취소" (plain, top-right X also dismisses)

When tapping "라운드 종료": confirmation screen "확실히 끝낼까요?"
with yes/no.

Use Spring palette.
```

---

## 4. Viewer 웹 화면 (5화면)

각 Viewer 화면은 **모바일 우선 (iPhone Safari 390pt width)** 기준. 데스크탑은 단일 column 중앙 정렬.

### 4.1 모바일 메인 (스코어카드 + 사진 갤러리 진입) — v2 editorial sharing

```
[공통 베이스 프롬프트 붙여넣기]

Mobile web viewer for shared rounds at golf.zerolive.co.kr/{shortId}.
This is the screen that friends will receive via KakaoTalk — the
"share moment." Should feel like a beautifully designed editorial
scorecard, not a Material Design dashboard.

Reference quality: think Apple Fitness shared workout pages, Strava
activity share pages, Spotify Wrapped year-in-review pages,
Pitchfork album review layouts.

Frame: 390pt width mobile-first, single column, Pretendard for Korean.
Spring palette by default. Light mode primary.

HERO BANNER (top, full-bleed, edge-to-edge):
- Background: large golf course aerial photo, full width × 360pt tall.
  Subtle gradient overlay at bottom (--surface 0% → 80%) so text below
  reads on photo edge.
- Overlay text positioned at bottom of photo, padded 24pt:
  - Course "스카이힐 골프클럽" 24pt/700 white drop-shadow subtle
  - Sub "동코스 · 2026-05-08" 13pt rgba(255,255,255,0.85)

META ROW (below hero, 16pt padding):
- "홍길동" big author chip 17pt/600 (or "익명" if anonymized),
  with small player initials chip stack right after: "+ 김민수, 박지영,
  이수현" 13pt text-secondary.
- DataQualityBadge inline subtle: small caution-line icon + "GPS 미지원
  코스" 12pt text-secondary (only if low).

FINAL SCORE STATEMENT (editorial pull-quote style):
- Big editorial headline 56pt/700 left-aligned tabular figures
  "82 (+10)" — score and par-diff together, par-diff smaller (28pt/500
  text-secondary inline).
- Sub line 13pt text-secondary "Par 72 · 18홀 완주" with thin dot dividers.

SCORECARD (split9x2 — fits mobile best):
- Section caption "스코어카드" 13pt/500 uppercase text-secondary,
  with hairline divider above.
- Two stacked compact tables OUT (1-9) and IN (10-18) — same
  par-diff circle/square treatment as 2.3 Variant B.
- Players column on left fixed 56pt wide, sticky.
- Mini total at right edge per table.
- NO heavy borders. Use 1px --border between rows only.

PHOTO GALLERY:
- Section caption "사진 12" 13pt/500 uppercase text-secondary.
- 3-column thumbnail grid, gap 4pt (TIGHT gap, magazine-style), square
  aspect. Each tap opens 4.3 lightbox.
- BELOW grid: plain text link "전체 사진 ZIP 다운로드 →" 15pt --primary
  green, NOT a filled button. Editorial restraint.

FOOTER (very minimal):
- Hairline divider top.
- Single line 11pt text-secondary: "2026-05-15에 만료됩니다 · © OpenStreetMap
  contributors, ODbL 1.0"
- NO app-install banner. NO download-our-app CTA. NO social share buttons
  (the share happens in iOS/KakaoTalk, not in viewer).

This page should look like the BEST golf round of someone's year —
worth screenshotting and remembering. Editorial confidence.
```

### 4.2 PIN 입력 화면

```
[공통 베이스 프롬프트 붙여넣기]

Mobile web viewer PIN lock screen (shown when accessControl == "pin").

Centered content, single column, very minimal:
- Top: small course name + date (greyed out, less prominent than 4.1).
- Middle: lock icon (line style, --text-secondary)
- Headline: "이 라운드는 PIN으로 보호되어 있습니다"
- Subheadline: "공유 받은 사람에게 PIN을 문의하세요"
- 4-digit numeric input field (large, monospaced, --score-iphone size).
  inputmode="numeric", pattern="[0-9]{4}", maxlength=4, autocomplete="off".
- Submit button "확인" (full width filled, below input)
- Error state placeholder: "PIN이 일치하지 않습니다. (3/5)" red caption.
- Locked state: "5회 오답으로 1시간 잠금되었습니다" + "Retry-After" countdown.

Use Pretendard font. Spring palette with --warning accent for error states.
```

### 4.3 사진 갤러리 라이트박스

```
[공통 베이스 프롬프트 붙여넣기]

Mobile web viewer photo lightbox (fullscreen overlay over 4.1).

Background: --surface 92% opacity (rgba(0,0,0,.92) approximation).

Layout:
- Top bar:
  · Left: photo counter "3 / 12"
  · Right: close X (44×44pt tap target, no background)
- Center: large <img> displayed directly (NOT background-image). Object-fit
  contain, max 100% width and 80vh height. touch-action: pinch-zoom enabled.
- Below image: caption text (if any) center-aligned, small.
- Bottom bar (sticky, 60pt high):
  · Plain "사진 저장" link with download icon (calls ?download=1)

Swipe left/right gestures change photo (annotate motion: short 0.2s slide).
Tap background or X to close. ESC key closes on desktop.

NOTE: NO background-image CSS. Pure <img> tag for iOS Safari long-press
"사진에 저장" to work.

Use Pretendard font.
```

### 4.4 사진 풀스크린 (다운로드/저장 버튼)

```
[공통 베이스 프롬프트 붙여넣기]

This is the SAME as 4.3 but emphasize the long-press / save flow.

Show three frame states side by side as a comparison:

Frame A — Default lightbox view (as 4.3).

Frame B — iOS Safari long-press context menu mock:
- System sheet appears from bottom with options:
  · "사진에 저장" (highlighted)
  · "이미지 복사"
  · "공유..."
  · "취소"

Frame C — Android Chrome long-press context menu mock:
- System sheet with options:
  · "이미지 다운로드"
  · "이미지 보기"
  · "이미지 검색"
  · "취소"

This is for documentation reference — actual implementation uses OS-native
menus, not custom UI. Caption: "long-press 시 OS가 자동으로 보여주는 메뉴.
viewer는 <img> 태그만 제공하면 됩니다."
```

### 4.5 만료 / 오류 페이지

```
[공통 베이스 프롬프트 붙여넣기]

Mobile web viewer error states. Three frames side by side:

Frame A — 410 Expired (manfest for 01-SPEC.md:126 7-day TTL):
- Centered card with grass-leaf-faded illustration
- Headline: "이 라운드는 만료되었습니다"
- Sub: "공유 링크는 생성 후 7일 동안 유효합니다."
- No action button (page-end).

Frame B — 404 Not Found:
- Same layout but headline: "라운드를 찾을 수 없습니다"
- Sub: "잘못된 링크이거나 이미 회수된 라운드입니다."

Frame C — PIN Locked (429):
- Same layout but headline: "5회 오답으로 잠금되었습니다"
- Sub: "1시간 후 다시 시도해 주세요." + live countdown timer placeholder.

Common footer: "© OpenStreetMap contributors, ODbL 1.0"
Use Pretendard font, --text-secondary for warm-grey error tone.
NO red shock colors — calm "그래도 괜찮아요" 톤.
```

---

## 5. 인계 절차 (선택 사항)

> **기본은 PNG + HTML만 저장**. 사용자가 인계 노트를 별도로 만들지 않아도 Claude Code가 다음을 자동 처리:
>
> - PNG 이미지 분석 → 컴포넌트 식별 (11-COMPONENTS와 매핑)
> - HTML 코드 파싱 → CSS 토큰 추출 (10-DESIGN_SYSTEM과 매핑)
> - 화면 번호(파일명) → 02-USER_FLOWS 플로우 단계 매핑
> - 인터랙션은 13-HAPTICS / 22-STATE / 23-OFFLINE 결정 사항으로 자동 적용

**파일명 규약** (이것만 지키면 Claude Code가 알아서 분류):

```
{카테고리}-{화면번호}-{이름}.png
{카테고리}-{화면번호}-{이름}.html

예시:
iphone-2.3-round-progress-variantA.png
iphone-2.3-round-progress-variantA.html
watch-3.1-score-input.png
viewer-4.1-main.html
```

**(선택) 사용자가 직접 메모 남기고 싶을 때**: `notes/{화면번호}-{이름}.md`에 자유 형식으로 작성. Stitch가 의도와 다르게 그린 부분 / 수정 지시 / 특정 화면만의 보강 사항 등.

---

## 6. 우선순위 권장 작업 순서

1. **디자인 시스템 페이지** (§1) — 토큰 정합성 확인용 기준점
2. **iPhone 2.3 라운드 진행 화면** — 가장 복잡하고 자주 사용되는 핵심 화면. Variant A/B 둘 다 만들어 12-SCREENS.md에서 선택
3. **Watch 3.1 메인 점수 입력** — 라운드 시간 90% 차지
4. **iPhone 2.2 새 라운드 시작** + **2.6 라운드 종료** — F-B/F-D 플로우 핵심
5. **Viewer 4.1 모바일 메인** + **4.3 라이트박스** — 공유 받은 사람의 첫인상
6. **나머지 11화면**

---

## 7. 작업 완료 후 Claude Code 인계 체크리스트

**필수**:
- [ ] 모든 화면 PNG 저장 (`Ref-docs/design-stitch/screens/`)
- [ ] AI Studio export HTML 저장 (`Ref-docs/design-stitch/html/`)
- [ ] 파일명 규약 준수 (`{카테고리}-{화면번호}-{이름}.{png,html}`)

**선택**:
- [ ] 화면별 노트 (수정 지시 등 자유 형식) — 필요한 화면에 한해 `notes/`
- [ ] **ScoreCell 변형 선택** (2.3 Variant A vs B) — Stitch에서 둘 다 만든 후 사용자가 결정
- [ ] **DataQualityBadge low/high/medium/unknown** 모두 시안에 노출되었는지 확인
- [ ] PIN 입력 화면 (4.2)이 33-SECURITY §5.3 `POST /:shortId/verify-pin`과 정합

**Claude Code 호출 시점**:
- 전체 18화면 완료 후 → "12-SCREENS.md 작성해줘" 한 번에 요청
- 또는 부분 완료 후 → "iPhone만 먼저 작성해줘" 단계별 요청도 가능

---

## 8. 작업 산출물 보관 디렉토리 구조 (권장)

```
Ref-docs/design-stitch/
├── stitch-prompt.md        # 본 파일 (Stitch 프롬프트 모음)
├── screens/                # Stitch AI Studio export PNG
│   ├── design-system-1.png
│   ├── iphone-2.1-home.png
│   ├── iphone-2.2-new-round.png
│   ├── iphone-2.3-round-progress-variantA.png
│   ├── iphone-2.3-round-progress-variantB.png
│   ├── iphone-2.4-penalty-modal.png
│   ├── ...
│   ├── watch-3.1-score-input.png
│   ├── ...
│   ├── viewer-4.1-main.png
│   └── ...
├── html/                   # Stitch AI Studio export HTML (PNG와 동시 다운로드됨)
│   ├── iphone-2.1-home.html
│   ├── iphone-2.3-round-progress-variantA.html
│   ├── ...
│   ├── viewer-4.1-main.html
│   └── ...
└── notes/                  # (선택) 사용자 자유 메모 — 수정 지시·보강·예외사항
    └── iphone-2.3-round-progress-variantA.md  # 예: "이 화면에서 Variant B를 채택"
```

> **Figma 디렉토리 없음**: 1인 개발 — Stitch가 단일 진실 원본.
> **notes/ 폴더는 비어있어도 OK**: 노트 없으면 Claude Code가 PNG + HTML + specs/만으로 추정.

---

*최종 업데이트: 2026-05-12 (v2)*
