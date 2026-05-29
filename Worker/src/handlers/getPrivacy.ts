/**
 * GET /privacy — 라운드온 개인정보 처리방침 페이지
 *
 * getLanding.ts 팔레트와 동일:
 *   --green: #7EAF69 / --surface: #F9FBF7 / --dark: #1F2A1B / --mid: #5A6850
 */

const HTML = `<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>개인정보 처리방침 — 라운드온</title>
<meta name="description" content="라운드온 앱의 개인정보 처리방침. 위치·스코어카드 AI 분석·공유 데이터 처리 방식을 안내합니다.">
<link rel="preconnect" href="https://cdn.jsdelivr.net">
<link href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/variable/pretendardvariable-dynamic-subset.min.css" rel="stylesheet">
<style>
:root{
  --green:#7EAF69;--green-light:#B8D7AF;--green-bg:#EEF6E6;
  --dark:#1F2A1B;--mid:#5A6850;--light:#8A9685;
  --surface:#F9FBF7;--border:#E8EEDF;--white:#fff;
  --radius:12px;
  --font:'Pretendard Variable',Pretendard,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
}
*{margin:0;padding:0;box-sizing:border-box}
html{scroll-behavior:smooth}
body{font-family:var(--font);color:var(--dark);background:var(--white);line-height:1.7;-webkit-font-smoothing:antialiased}

/* Nav */
.nav{position:fixed;top:0;left:0;right:0;z-index:100;background:rgba(255,255,255,.9);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);border-bottom:1px solid rgba(232,238,223,.6)}
.nav-inner{max-width:760px;margin:0 auto;padding:0 24px;height:56px;display:flex;align-items:center;justify-content:space-between}
.nav-logo{display:flex;align-items:center;gap:10px;text-decoration:none;color:var(--dark)}
.nav-logo .mark{width:32px;height:32px;border-radius:9px;background:linear-gradient(135deg,var(--green),var(--green-light));display:grid;place-items:center;color:#fff;font-weight:800;font-size:16px;letter-spacing:-1px}
.nav-logo span{font-size:16px;font-weight:700;letter-spacing:-.3px}
.nav-back{font-size:13px;color:var(--mid);text-decoration:none;font-weight:500}
.nav-back:hover{color:var(--dark)}

/* Page layout */
.page{max-width:760px;margin:0 auto;padding:88px 24px 80px}

/* Header */
.page-header{padding-bottom:28px;border-bottom:2px solid var(--border);margin-bottom:40px}
.page-header h1{font-size:28px;font-weight:800;letter-spacing:-.5px;margin-bottom:8px}
.page-header .meta{font-size:13px;color:var(--mid)}
.page-header .meta strong{color:var(--dark)}

/* Section */
.section{margin-bottom:40px}
.section h2{font-size:17px;font-weight:700;letter-spacing:-.3px;margin-bottom:14px;padding-bottom:8px;border-bottom:1px solid var(--border);color:var(--dark)}
.section p{font-size:15px;color:#2D3A28;line-height:1.75;margin-bottom:10px}
.section p:last-child{margin-bottom:0}

/* List */
.section ul{margin:8px 0 12px 0;padding-left:0;list-style:none}
.section ul li{font-size:15px;color:#2D3A28;line-height:1.7;padding:6px 0 6px 20px;position:relative;border-bottom:1px solid var(--border)}
.section ul li:last-child{border-bottom:none}
.section ul li::before{content:"·";position:absolute;left:6px;color:var(--green);font-weight:700}

/* Highlight box */
.highlight{background:var(--green-bg);border-left:3px solid var(--green);border-radius:0 var(--radius) var(--radius) 0;padding:14px 18px;margin:14px 0;font-size:14px;color:#2A4020;line-height:1.7}

/* Table */
.table-wrap{overflow-x:auto;margin:14px 0}
table{width:100%;border-collapse:collapse;font-size:14px}
th{background:var(--surface);color:var(--mid);font-weight:700;text-align:left;padding:10px 14px;border:1px solid var(--border)}
td{padding:10px 14px;border:1px solid var(--border);color:#2D3A28;line-height:1.6;vertical-align:top}
tr:nth-child(even) td{background:var(--surface)}

/* Footer */
footer{margin-top:60px;padding-top:28px;border-top:1px solid var(--border);font-size:12.5px;color:var(--light);line-height:1.8}
footer a{color:var(--mid);text-decoration:none}
footer a:hover{color:var(--dark)}

@media(max-width:600px){
  .page{padding:80px 18px 60px}
  .page-header h1{font-size:22px}
  .section h2{font-size:15px}
  .section p,.section ul li{font-size:14px}
  table{font-size:13px}
}
</style>
</head>
<body>

<nav class="nav">
  <div class="nav-inner">
    <a href="/" class="nav-logo">
      <span class="mark">R</span>
      <span>라운드온</span>
    </a>
    <a href="/" class="nav-back">← 홈으로</a>
  </div>
</nav>

<main class="page">

  <div class="page-header">
    <h1>개인정보 처리방침</h1>
    <p class="meta">앱: <strong>라운드온 (Round-On)</strong> &nbsp;|&nbsp; 시행일: <strong>2026-05-29 (광고 도입 반영)</strong></p>
  </div>

  <div class="section">
    <p>
      라운드온(이하 "앱")은 사용자의 개인정보를 소중히 여기며, 필요한 최소한의 정보만 처리합니다.
      이 처리방침은 앱이 어떤 정보를 어떻게 다루는지 명확하게 안내합니다.
    </p>
  </div>

  <div class="section">
    <h2>1. 수집·처리하는 정보</h2>

    <p><strong>1-1. 스코어카드 AI 분석 (선택 · 동의 기반)</strong></p>
    <div class="highlight">
      사용자가 이 기능에 명시적으로 동의한 경우에만 작동합니다.
      동의 전까지는 모든 처리가 기기 내(on-device)에서만 이루어집니다.
    </div>
    <ul>
      <li>사용자가 선택한 스코어카드 사진 1장과 촬영일(EXIF 날짜)을 외부 AI 서버(Google LLC, Gemini API)로 전송하여 스코어·코스명·날짜를 인식합니다.</li>
      <li>전송된 사진은 분석 목적에만 사용되며, Google 서버에 별도 저장되지 않습니다.</li>
      <li>동의를 철회하면 이후 전송은 즉시 중단되고 기기 내 처리 방식으로 전환됩니다.</li>
    </ul>

    <p style="margin-top:16px"><strong>1-2. 위치 정보</strong></p>
    <ul>
      <li>골프장 자동 감지(GPS 매칭)에만 사용합니다.</li>
      <li>좌표는 기기 내에서만 처리하며, 외부 서버로 전송하지 않습니다.</li>
    </ul>
  </div>

  <div class="section">
    <h2>2. 수집하지 않는 정보</h2>
    <ul>
      <li>회원가입 없음 — 별도 계정이나 인증 정보를 수집하지 않습니다.</li>
      <li>자체 서버에 개인정보 및 행동 분석(analytics) 데이터를 수집하지 않습니다.</li>
      <li>라운드 공유(viewer) 시에도 동반자 별명과 스코어만 사용합니다. 실명·연락처는 받지 않습니다.</li>
      <li>공유 데이터는 7일 후 자동으로 삭제됩니다.</li>
    </ul>
  </div>

  <div class="section">
    <h2>3. 데이터 저장·보관</h2>
    <ul>
      <li>라운드 데이터는 기기 내(SwiftData) 및 사용자의 iCloud(공유 시)에 저장됩니다.</li>
      <li>AI 분석을 위해 Google에 전송되는 사진은 일시 처리 후 저장되지 않습니다.</li>
      <li>공유 viewer 데이터(동반자 별명·스코어)는 7일 후 자동으로 삭제됩니다. 사용자가 직접 삭제하는 것도 가능합니다.</li>
    </ul>
  </div>

  <div class="section">
    <h2>4. 제3자 제공</h2>
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>수령자</th>
            <th>제공 목적</th>
            <th>제공 항목</th>
            <th>조건</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Google LLC<br>(Gemini API)</td>
            <td>스코어카드 사진 AI 분석</td>
            <td>스코어카드 사진 1장, 촬영일(EXIF)</td>
            <td>사용자 명시 동의 시에만</td>
          </tr>
          <tr>
            <td>Google LLC<br>(AdMob)</td>
            <td>광고 제공</td>
            <td>광고 식별자(IDFA)·기기 정보·광고 상호작용</td>
            <td>ATT 동의 기반</td>
          </tr>
        </tbody>
      </table>
    </div>
    <p>위 경우를 제외하고 개인정보를 제3자에게 제공하거나 판매하지 않습니다.</p>
  </div>

  <div class="section">
    <h2>5. 광고(AdMob)</h2>
    <p>
      앱은 무료 제공을 위해 Google AdMob 광고를 표시합니다.
      광고 제공 과정에서 <strong>광고 식별자(IDFA)·기기 정보·광고 상호작용</strong> 정보가 사용될 수 있으며,
      iOS의 <strong>추적 투명성(ATT) 동의</strong>에 따라 맞춤/비맞춤 광고로 제공됩니다.
    </p>
    <p>사용자는 기기 설정 또는 ATT 권한에서 추적을 거부할 수 있습니다.</p>
  </div>

  <div class="section">
    <h2>6. 이용자 권리</h2>
    <ul>
      <li>앱 설정에서 스코어카드 AI 분석 동의를 언제든 철회할 수 있습니다. 철회 즉시 이후 전송이 중단되고 기기 내 처리 방식으로 전환됩니다.</li>
      <li>기기 내 라운드 데이터는 앱에서 직접 삭제할 수 있습니다.</li>
      <li>공유한 viewer 링크는 공유 목록에서 직접 삭제할 수 있습니다.</li>
    </ul>
  </div>

  <div class="section">
    <h2>7. 보안</h2>
    <ul>
      <li>외부 서버와의 모든 통신은 HTTPS(TLS)로 암호화됩니다.</li>
      <li>최소 수집 원칙에 따라 서비스 제공에 꼭 필요한 정보만 처리합니다.</li>
      <li>공유 링크는 선택적으로 PIN 보호를 설정할 수 있습니다.</li>
    </ul>
  </div>

  <div class="section">
    <h2>8. 문의</h2>
    <p>개인정보 처리방침에 관한 문의는 아래 이메일로 연락해 주세요.</p>
    <p>
      이메일: <a href="mailto:support@zerolive.co.kr">support@zerolive.co.kr</a>
    </p>
  </div>

  <footer>
    <p>© 2026 zerolive.co.kr &nbsp;·&nbsp; <a href="/">라운드온 홈</a></p>
    <p style="margin-top:4px">지도 데이터: © OpenStreetMap contributors, ODbL 1.0</p>
    <p style="margin-top:8px;font-size:11.5px">이 처리방침은 필요 시 갱신될 수 있습니다. 변경 시 앱 업데이트 또는 이 페이지를 통해 안내합니다.</p>
  </footer>

</main>

</body>
</html>
`;

/**
 * GET /privacy 핸들러 — 개인정보 처리방침 HTML 응답
 */
export function handleGetPrivacy(): Response {
  return new Response(HTML, {
    headers: {
      "Content-Type": "text/html; charset=UTF-8",
      "Cache-Control": "public, max-age=3600, stale-while-revalidate=86400",
      "X-Content-Type-Options": "nosniff",
    },
  });
}
