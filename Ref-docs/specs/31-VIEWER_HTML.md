# 31 — Viewer HTML 구조 및 사진 저장 명세

> **작성일**: 2026-05-11
> **버전**: v4 기반
> **출처 명세서**: [기능 명세서 v4](../golf-scorecard-app-spec_3.md) §F9 (spec_3.md:121-143), §F10 (spec_3.md:144-220), §3.1 (spec_3.md:224-242)
> **관련 문서**: `30-API_SPEC.md`, `10-DESIGN_SYSTEM.md`, `32-CLOUDFLARE_SETUP.md` (작성 예정), `33-SECURITY.md` (작성 예정), `62-COMPAT_MATRIX.md` (작성 예정)

---

## 1. 목적 / 범위

본 문서는 `GET /:shortId` 응답으로 Cloudflare Worker가 생성하는 **viewer HTML 마크업**을 다룬다. 정의 대상은 HTML 구조, CSS 클래스 계약, 인라인 JS 스니펫이다. viewer HTML이 만드는 마크업까지만 책임진다.

**다루지 않는 영역** (위임):

| 영역 | 위임 문서 |
|------|----------|
| HTTP 응답 헤더, 엔드포인트 요청/응답 구조 | `30-API_SPEC.md` |
| 디자인 토큰, 색상 팔레트, 폰트 스케일 | `10-DESIGN_SYSTEM.md` |
| Worker 렌더링 코드, KV/R2 키 스킴, TTL 설정 | `32-CLOUDFLARE_SETUP.md` (작성 예정) |
| bcrypt cost factor, 잠금 카운터, PII 패턴 매칭 | `33-SECURITY.md` (작성 예정) |
| 브라우저 quirk 카탈로그 (카톡 인앱, Samsung Internet 등) | `62-COMPAT_MATRIX.md` (TODO, 작성 예정) |

---

## 2. 페이지 구성 및 라우트별 HTML

viewer 응답은 shortId 상태에 따라 4가지로 분기한다. 트리거 조건 및 HTTP 상태 코드는 `30-API_SPEC §6.1, §7`을 참조한다. 본 표는 HTML 카피와 레이아웃만 정의한다.

| 라우트 | HTML 카피 | 레이아웃 | 헤더/푸터 |
|--------|----------|----------|----------|
| 200 정상 (공개) | 스코어카드 + 사진 갤러리 | §3–§7 구조 전체 적용 | 헤더 + 푸터 포함 |
| 200 잠금 (PIN) | "이 라운드는 PIN으로 보호되어 있습니다" + 4자리 입력 폼 | §8 PIN 잠금 화면 | 헤더만 (만료 시각 표기 제외) |
| 410 만료 | "이 라운드는 만료되었습니다. (생성 후 7일 경과)" | 단순 카드 (중앙 정렬) | 헤더만 |
| 404 미존재 | "라운드를 찾을 수 없습니다." | 단순 카드 (중앙 정렬) | 헤더만 |

### HTML 골격

모든 라우트에 공통 적용되는 `<head>` 필수 요소:

```html
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <!-- viewport-fit=cover: safe-area-inset 요구 충족 (spec_3.md:149) -->
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
  <meta name="theme-color" content="#7FB069" />
  <style>
    body {
      margin: 0;
      font-family: 'Pretendard', -apple-system, BlinkMacSystemFont, sans-serif; /* 10-DESIGN_SYSTEM §3 */
      padding: env(safe-area-inset-top) env(safe-area-inset-right)
               env(safe-area-inset-bottom) env(safe-area-inset-left);
    }
  </style>
</head>
<body><!-- 헤더(§3) / 본문(§4-§8) / 푸터(§3) --></body>
</html>
```

`user-scalable` 제한을 두지 않으며 핀치 줌을 허용한다. (spec_3.md:161)

---

## 3. 헤더 / 푸터 / 정보 영역

**헤더** (200 정상 + PIN 잠금에 표시): 골프장명(`courseName`, 미매핑 시 "코스 정보 없음"), 라운드 날짜(`roundDate`), 플레이어 이름(`nameVisibility == "real"` → 실명 / `"anonymous"` → A/B/C/D). (spec_3.md:131)

```html
<header class="viewer-header">
  <h1 class="course-name">한양 컨트리클럽</h1>
  <p class="round-meta">2026-05-11 · 홍길동 외 3명</p>
</header>
```

**푸터** (200 정상만): 만료 시각(ISO 8601 UTC) + OSM ODbL 표기. OSM ODbL은 viewer에도 반드시 포함한다. (spec_3.md:126, CLAUDE.md §PROJECT, golf-db-pack/README.md:94-100)

```html
<footer class="viewer-footer">
  <p class="expires-at">이 링크는 2026-05-18T09:00:00Z에 만료됩니다.</p>
  <p class="osm-credit">&copy; OpenStreetMap contributors, ODbL 1.0</p>
</footer>
```

**데이터 품질 배지**: `dataQuality: "low"` 코스는 헤더 하단에 안내를 표시한다. 546개 중 524개가 low 품질(클럽하우스 위치만)이므로 분기 처리가 필수다. F3 GPS 홀 자동 감지는 14개 코스에서만 동작한다. (CLAUDE.md §PROJECT)

```html
<div class="data-quality-badge" data-quality="low">
  GPS 홀 자동 감지가 지원되지 않는 코스입니다.
</div>
```

---

## 4. 스코어카드 모바일 표시

(spec_3.md §10.4)

**디폴트: 9홀 2단 (OUT/IN)** — 단일 접근으로 헌신한다.

9홀 2단 디폴트를 선택한 근거: 모바일 세로 화면에서 18홀 가로 스크롤은 (1) 합계 행 sticky 처리가 복잡하고 scroll-end 이벤트 없이 행 고정이 깨질 수 있으며, (2) 9홀 단위로 분리하면 한 화면에 전체 홀이 들어와 좌우 스크롤 없이 읽을 수 있다. spec_3.md:206은 "가로 스크롤 허용 또는 9홀씩 2단"으로 양자를 허용하지만, 본 문서는 모바일 가독성과 sticky 합계 행 호환성을 근거로 9홀 2단을 디폴트로 결정한다. 18홀 가로 스크롤 옵션은 §9 구현 제안으로 강등한다.

### 점수 셀 색상 클래스 매트릭스

(spec_3.md:209-213)

| par 대비 | 클래스 | 시각 표현 |
|---------|--------|---------|
| -2 이하 | `.eagle` | 진한 그린 동그라미 |
| -1 | `.birdie` | 그린 동그라미 |
| 0 | `.par` | 기본 (색상 없음) |
| +1 | `.bogey` | 옅은 회색 사각형 |
| +2 이상 | `.double-plus` | 진한 회색 사각형 |

터치 타깃 최소 44×44pt (spec_3.md:150, 10-DESIGN_SYSTEM §4).

### HTML 예시

```html
<section class="scorecard">
  <div class="scorecard-half"><!-- OUT(홀 1-9), IN(홀 10-18) 각 1개씩 -->
    <table class="score-table">
      <thead><tr><th>홀</th><th>Par</th><th>홍길동</th><th>김철수</th></tr></thead>
      <tbody>
        <tr><td>1</td><td>4</td><td class="birdie">3</td><td class="bogey">5</td></tr>
        <!-- 홀 2-9 반복 -->
      </tbody>
      <!-- sticky-total: position:sticky; bottom:0 -->
      <tfoot class="sticky-total"><tr><td colspan="2">OUT</td><td>36</td><td>40</td></tr></tfoot>
    </table>
  </div>
</section>
```

---

## 5. 사진 갤러리 — 썸네일 그리드

(spec_3.md:197, §F9)

3열 그리드 썸네일, 탭하면 §7 라이트박스가 열린다. 빈 갤러리 fallback: "이 라운드에 첨부된 사진이 없습니다." 사진 URL은 R2 직접 URL이 아닌 Worker 경유(`/{shortId}/photo/{photoId}`)를 사용한다. (30-API_SPEC §6.2) ZIP 다운로드는 `GET /:shortId/photos.zip`. (30-API_SPEC §6.4)

```html
<section class="photo-gallery">
  <div class="photo-grid">
    <!-- photo-item: data-index 속성으로 라이트박스 인덱스 연결 -->
    <figure class="photo-item" data-photo-id="{photoId}" data-index="0">
      <img src="https://golf.zerolive.co.kr/{shortId}/photo/{photoId}"
           alt="라운드 사진" loading="lazy" style="touch-action: pinch-zoom;" />
    </figure>
    <!-- 반복 -->
  </div>
  <a class="btn-zip-download"
     href="https://golf.zerolive.co.kr/{shortId}/photos.zip"
     download="roundon-{shortId}.zip">사진 전체 다운로드 (ZIP)</a>
</section>
```

```css
.photo-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
/* gap 8px: 10-DESIGN_SYSTEM §4 간격 토큰 */
.photo-item img { width: 100%; aspect-ratio: 1; object-fit: cover; display: block; }
```

---

## 6. 사진 long-press 저장 — 핵심 명세

(spec_3.md §10.2)

> **Responsibility Boundary**
>
> 본 §6은 viewer HTML이 만들어야 하는 **마크업 계약**만 정의한다.
> HTTP 응답 헤더(`Content-Disposition: attachment`)는 `30-API_SPEC §6.2/§6.3`이 책임진다.
> 브라우저별 long-press 실제 동작(카톡 인앱, Samsung Internet, Firefox iOS 등)의 quirk 카탈로그는 `62-COMPAT_MATRIX.md` (작성 예정)로 위임한다.

### 규범적 MUST

1. **`<img>` 직접 표시 필수** — `background-image` CSS 사용 금지. iOS Safari "사진에 저장" 컨텍스트 메뉴는 `<img>` 태그에서만 동작한다. (spec_3.md:159)
2. **`touch-action: pinch-zoom` 인라인 설정** — 핀치 줌 활성화. (spec_3.md:161)
3. **명시적 다운로드 버튼 제공** — `download` 속성, 파일명 패턴 `golf-YYYY-MM-DD-h{N}.jpg`. (spec_3.md:168-170)
4. **사진 URL은 Worker 경유** — R2 직접 URL 노출 금지. (spec_3.md:182-185)

### HTML 코드 (spec_3.md:174-186 기반)

```html
<!-- 갤러리 사진: iOS long-press → "사진에 저장" 가능 -->
<img
  src="https://golf.zerolive.co.kr/{shortId}/photo/{photoId}"
  alt="홀 3 사진"
  loading="lazy"
  style="touch-action: pinch-zoom;"
/>

<!-- 명시적 다운로드 버튼 -->
<a
  href="https://golf.zerolive.co.kr/{shortId}/photo/{photoId}?download=1"
  download="golf-2026-05-11-h3.jpg"
>
  사진 저장
</a>
```

### 동작 매트릭스 (마크업 관점만, 브라우저 quirk는 62 위임)

| 환경 | long-press → 컨텍스트 메뉴 | "사진에 저장" 메뉴 | 다운로드 버튼 | 비고 |
|------|--------------------------|------------------|------------|------|
| iOS Safari | 표준 동작 | "사진에 저장" 표시 | `Content-Disposition` 헤더 동작 (30-API §6.3) | spec_3.md:157-160 |
| Android Chrome | 표준 동작 | "이미지 다운로드" 표시 | 다운로드 폴더 자동 저장 | spec_3.md:163-165 |
| 기타 (카톡 인앱, Samsung Internet, Firefox iOS 등) | [SPEC-UNDEFINED] | [SPEC-UNDEFINED] | 다운로드 버튼 fallback | spec §10.2 미명세 — `62-COMPAT_MATRIX.md` (작성 예정) |

**Fallback 안전 기준**: long-press 동작이 [SPEC-UNDEFINED]인 환경에서도 §5 갤러리·§7 라이트박스의 **명시적 다운로드 버튼이 항상 표시**되므로, 사용자는 모든 환경에서 사진을 저장할 수 있다. 62 카탈로그가 부재해도 본 마크업만으로 회복 가능한 동작이 보장된다.

---

## 7. 라이트박스 (풀스크린 뷰어)

(spec_3.md §10.3)

spec_3.md:203이 "순수 HTML + 최소 JS (10KB 미만)"를 명세 범위에 포함한다. 외부 라이브러리를 사용하지 않는다.

기능 요건: 썸네일 탭 → 풀스크린 오픈, 좌/우 스와이프 이동, 핀치 줌, 우상단 X 닫기, 하단 "사진 저장"/"다운로드" 버튼. 풀스크린에서도 `<img>` 직접 표시를 유지하여 long-press 저장을 보존한다. (spec_3.md:159, 198-202)

**상호작용 규약**:
- 왼쪽 스와이프 = 다음 사진, 오른쪽 스와이프 = 이전 사진 (한국어 가로쓰기 관습)
- 두 손가락 제스처(핀치 줌) 중에는 스와이프 페이지 이동이 트리거되지 않아야 한다 — 아래 스크립트의 `e.touches.length > 1` 가드 참조
- ESC 키 닫기 + 닫을 때 트리거 요소(썸네일)로 포커스 환원 (WAI-ARIA dialog 관행)

```html
<!-- 라이트박스 오버레이 -->
<div id="lightbox" hidden aria-modal="true" role="dialog"
     style="position:fixed; inset:0; background:rgba(0,0,0,.92);
            display:flex; flex-direction:column;
            align-items:center; justify-content:center; z-index:9999;
            padding:env(safe-area-inset-top) env(safe-area-inset-right)
                    env(safe-area-inset-bottom) env(safe-area-inset-left);">
  <button id="lb-close" aria-label="닫기"
          style="position:absolute;top:1rem;right:1rem;background:none;
                 border:none;color:#fff;font-size:1.5rem;
                 min-width:44px;min-height:44px;">&#x2715;</button>
  <!-- display:block 필수 — background-image 미사용 (spec_3.md:159) -->
  <!-- alt는 open()에서 동적 채움. aria-live로 SR 갱신 -->
  <img id="lb-img" alt="라운드 사진" aria-live="polite"
       style="max-width:100%;max-height:80vh;object-fit:contain;
              display:block;touch-action:pinch-zoom;" />
  <a id="lb-download" download
     style="color:#fff;min-height:44px;display:inline-flex;align-items:center;
            margin-top:.75rem;">사진 저장</a>
</div>
<script>
(function () {
  var photos = window.__PHOTOS__ || []; /* Worker가 인라인 JSON 주입: {src, downloadSrc, alt, filename} */
  var cur = 0, startX = null, lastTrigger = null;
  var lb  = document.getElementById('lightbox');
  var img = document.getElementById('lb-img');
  var dl  = document.getElementById('lb-download');

  function open(i, trigger) {
    cur = i; var p = photos[i];
    img.src = p.src; img.alt = p.alt || '라운드 사진';
    dl.href = p.downloadSrc; dl.download = p.filename || 'golf-photo.jpg';
    lb.hidden = false; document.body.style.overflow = 'hidden';
    lastTrigger = trigger || null;
    document.getElementById('lb-close').focus();
  }
  function close() {
    lb.hidden = true; document.body.style.overflow = '';
    if (lastTrigger) lastTrigger.focus(); /* 포커스 환원 */
  }
  function nav(d) { var n = cur + (d === 'next' ? 1 : -1); if (n >= 0 && n < photos.length) open(n, lastTrigger); }

  document.querySelectorAll('.photo-item').forEach(function (el) {
    el.addEventListener('click', function () { open(+el.dataset.index, el); });
  });

  /* touchstart/touchend 방향 판정 — 핀치 줌과 충돌 회피 */
  lb.addEventListener('touchstart', function (e) {
    if (e.touches.length > 1) { startX = null; return; } /* 핀치 시작 → 스와이프 비활성 */
    startX = e.touches[0].clientX;
  });
  lb.addEventListener('touchend', function (e) {
    if (startX === null || e.changedTouches.length > 1) return; /* 핀치 종료는 nav 트리거 안 함 */
    var dx = e.changedTouches[0].clientX - startX;
    if (Math.abs(dx) > 50) nav(dx < 0 ? 'next' : 'prev');
    startX = null;
  });

  document.getElementById('lb-close').addEventListener('click', close);
  lb.addEventListener('click', function (e) { if (e.target === lb) close(); });
  /* ESC 키 닫기 */
  document.addEventListener('keydown', function (e) {
    if (!lb.hidden && e.key === 'Escape') close();
  });
}());
</script>
```

---

## 8. PIN 잠금 화면

(spec_3.md:239-240, 30-API_SPEC §9.2)

`accessControl == "pin"` viewer 최초 접근 시 스코어카드 대신 이 화면을 렌더링한다.

```html
<section class="pin-lock">
  <h2>PIN 확인</h2>
  <p>이 라운드는 PIN으로 보호되어 있습니다.</p>
  <form id="pin-form" autocomplete="off">
    <!-- type="text"+inputmode="numeric": iOS/Android 숫자 키보드 + maxlength 동작 -->
    <input id="pin-input" type="text" inputmode="numeric" maxlength="4"
           placeholder="4자리 숫자 입력" autocomplete="off" pattern="[0-9]{4}"
           required style="min-height:44px;" />
    <button type="submit" style="min-height:44px;">확인</button>
  </form>
  <p id="pin-error"  hidden>PIN이 일치하지 않습니다. (1/5)</p>
  <p id="pin-locked" hidden>5회 오답으로 1시간 잠금되었습니다.</p>
</section>
<script>
document.getElementById('pin-form').addEventListener('submit', function (e) {
  e.preventDefault();
  /* PIN 검증: 30-API_SPEC §9.2 권장 엔드포인트 호출 */
  fetch('/{shortId}/verify-pin', {
    method:'POST', headers:{'Content-Type':'application/json'},
    body:JSON.stringify({ pin: document.getElementById('pin-input').value })
  }).then(function(r){return r.json();}).then(function(d){
    if (d.ok) { window.location.reload(); }
    else if (d.locked) {
      document.getElementById('pin-locked').hidden = false;
      document.getElementById('pin-error').hidden  = true;
    } else {
      var el = document.getElementById('pin-error');
      el.textContent = 'PIN이 일치하지 않습니다. (' + d.attempts + '/5)';
      el.hidden = false;
    }
  });
});
</script>
```

PIN 잠금 응답 처리(`429` 또는 별도 필드)는 `30-API_SPEC §8`을 따른다.

---

## 9. 구현 제안 (spec 외)

본 섹션은 `spec_3.md`에 없는 구현 권장안이며, 실제 결정은 구현 단계 또는 후속 문서에서 확정한다. 본 문서가 명세화하지 않는다.

### 18홀 가로 스크롤 옵션

§4 디폴트(9홀 2단)의 대안이다. (spec_3.md:206) URL 파라미터(`?layout=wide`) 또는 뷰어 내 토글로 18열 단일 테이블 + `overflow-x: auto` 가로 스크롤을 선택할 수 있도록 검토한다. 이 경우 sticky는 `position: sticky; left: 0`으로 홀 번호 열을 고정하는 방식을 사용한다.

### PWA `manifest.json` (Optional)

(spec_3.md:215-220) 안드로이드 "홈 화면에 추가" 지원. Service Worker 오프라인 캐싱은 만료성 콘텐츠이므로 구현하지 않는다. `<head>`에 `<link rel="manifest" href="/manifest.json" />`을 추가한다.

```json
{ "name":"라운드온 Viewer", "short_name":"라운드온", "start_url":"/{shortId}",
  "display":"standalone", "background_color":"#FAFCF7", "theme_color":"#7FB069",
  "icons":[{"src":"/icon-192.png","sizes":"192x192","type":"image/png"},
            {"src":"/icon-512.png","sizes":"512x512","type":"image/png"}] }
```

### Open Graph 메타 (카톡/iMessage 미리보기)

```html
<meta property="og:title"       content="홍길동의 라운드 — 한양 CC (2026-05-11)" />
<meta property="og:description" content="18홀 스코어: 78타 (+6)" />
<meta property="og:image"       content="{ogImageURL}" />
<meta property="og:url"         content="https://golf.zerolive.co.kr/{shortId}" />
<meta property="og:type"        content="website" />
```

`og:image` 생성 주체는 [SPEC-UNDEFINED]이다. **`30-API_SPEC §3` 응답에 `ogImageURL` 필드를 추가하는 방안을 검토할 것을 권장한다.**

### 다크 모드 자동 전환

`prefers-color-scheme: dark` 미디어 쿼리로 Winter 팔레트를 자동 적용한다. (10-DESIGN_SYSTEM §2 Winter 팔레트)

```css
@media (prefers-color-scheme: dark) {
  :root {
    --green-primary: #5A8A6B;  --green-secondary: #2A3F35;
    --green-accent:  #8FB5A0;  --surface:         #0F1612;
    --surface-elevated: #1A241E; --text-primary:  #E8F0EA;
    --text-secondary: #9AAA9F; --border:          #2A3530;
    /* 전체 토큰: 10-DESIGN_SYSTEM §2 Winter */
  }
}
```

---

## 부록. 후속 보완 TODO + 책임 경계

### spec 미정의 항목

| 항목 | 현황 | 위임/후속 |
|------|------|----------|
| 카톡 인앱 브라우저 long-press 동작 | [SPEC-UNDEFINED] | `62-COMPAT_MATRIX.md` (작성 예정) |
| Samsung Internet long-press 동작 | [SPEC-UNDEFINED] | `62-COMPAT_MATRIX.md` (작성 예정) |
| Firefox iOS long-press 동작 | [SPEC-UNDEFINED] | `62-COMPAT_MATRIX.md` (작성 예정) |
| `og:image` 동적 생성 방식 | [SPEC-UNDEFINED] | §9 역참조 — 30-API_SPEC §3 `ogImageURL` 검토 |
| PIN 검증 엔드포인트 URL/응답 구조 | [SPEC-UNDEFINED] | `30-API_SPEC §9.2` 권장안 |
| `window.__PHOTOS__` 직렬화 형식 | [SPEC-UNDEFINED] | `32-CLOUDFLARE_SETUP.md` (작성 예정) |

### 책임 경계

| 문서 | 책임 |
|------|------|
| **31-VIEWER_HTML.md** (본 문서) | 마크업 계약 — HTML 구조, CSS 클래스, 인라인 JS |
| **30-API_SPEC.md** | HTTP 계약 — 엔드포인트, 응답 헤더, 상태 코드 |
| **62-COMPAT_MATRIX.md** (작성 예정) | 브라우저 quirk 카탈로그 — 환경별 실제 동작 검증 |
| **32-CLOUDFLARE_SETUP.md** (작성 예정) | Worker 렌더링 코드, KV/R2 키 스킴, TTL |
| **33-SECURITY.md** (작성 예정) | bcrypt cost, 잠금 카운터, PII 패턴 매칭 |

---

*최종 업데이트: 2026-05-11*
