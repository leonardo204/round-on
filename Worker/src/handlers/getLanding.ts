/**
 * GET / — 라운드온 앱 소개 페이지
 *
 * Spring green 팔레트 (앱 메인 테마 그대로):
 *   --green: #7EAF69 / --green-light: #B8D7AF / --green-accent: #C5E0A4
 *   --surface: #F9FBF7 / --dark: #1F2A1B / --mid: #5A6850 / --border: #E8EEDF
 */

const HTML = `<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>라운드온 — 골프 라운드를 가장 단순하게</title>
<meta name="description" content="iPhone과 Apple Watch로 함께 사용하는 골프 스코어 카운터. 0에서 시작해 샷마다 +1, 라운드는 한 장의 카드로 공유.">
<meta property="og:title" content="라운드온 — 골프 라운드를 가장 단순하게">
<meta property="og:description" content="iPhone과 Apple Watch로 함께 사용하는 골프 스코어 카운터. 0에서 시작해 샷마다 +1.">
<meta property="og:url" content="https://golf.zerolive.co.kr/">
<meta property="og:type" content="website">
<link rel="preconnect" href="https://cdn.jsdelivr.net">
<link href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/variable/pretendardvariable-dynamic-subset.min.css" rel="stylesheet">
<style>
:root{
  --green:#7EAF69;--green-light:#B8D7AF;--green-accent:#C5E0A4;--green-bg:#EEF6E6;
  --dark:#1F2A1B;--mid:#5A6850;--light:#8A9685;
  --surface:#F9FBF7;--border:#E8EEDF;--white:#fff;
  --radius:14px;--radius-lg:22px;--radius-xl:30px;
  --shadow:0 2px 16px rgba(31,42,27,.04);
  --shadow-lg:0 8px 32px rgba(126,175,105,.16);
  --font:'Pretendard Variable',Pretendard,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
}
*{margin:0;padding:0;box-sizing:border-box}
html{scroll-behavior:smooth}
body{font-family:var(--font);color:var(--dark);background:var(--white);line-height:1.6;-webkit-font-smoothing:antialiased}
img{max-width:100%;display:block}

.nav{position:fixed;top:0;left:0;right:0;z-index:100;background:rgba(255,255,255,.85);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);border-bottom:1px solid rgba(232,238,223,.6)}
.nav-inner{max-width:1080px;margin:0 auto;padding:0 24px;height:64px;display:flex;align-items:center;justify-content:space-between}
.nav-logo{display:flex;align-items:center;gap:10px;text-decoration:none;color:var(--dark)}
.nav-logo .mark{width:36px;height:36px;border-radius:10px;background:linear-gradient(135deg,var(--green),var(--green-light));display:grid;place-items:center;color:#fff;font-weight:800;font-size:18px;letter-spacing:-1px}
.nav-logo span{font-size:18px;font-weight:700;letter-spacing:-.3px}
.nav-links{display:flex;align-items:center;gap:28px}
.nav-links a{font-size:14px;color:var(--mid);text-decoration:none;font-weight:500;transition:color .2s}
.nav-links a:hover{color:var(--dark)}

section{padding:96px 24px}
.container{max-width:1080px;margin:0 auto}
.section-badge{display:inline-block;padding:6px 14px;border-radius:20px;font-size:12px;font-weight:700;margin-bottom:18px;letter-spacing:.2px}
.section-title{font-size:34px;font-weight:800;letter-spacing:-.6px;line-height:1.25;margin-bottom:14px}
.section-sub{font-size:16px;color:var(--mid);line-height:1.7;max-width:520px}
.text-center{text-align:center}
.mx-auto{margin-left:auto;margin-right:auto}

/* Hero */
.hero{padding:140px 24px 96px;background:linear-gradient(180deg,var(--green-bg) 0%,var(--white) 100%);text-align:center;overflow:hidden;position:relative}
.hero::before{content:"";position:absolute;width:520px;height:520px;border-radius:50%;background:radial-gradient(circle,rgba(197,224,164,.35) 0%,transparent 70%);top:-200px;left:50%;transform:translateX(-50%);z-index:0}
.hero .container{position:relative;z-index:1}
.hero .section-badge{background:rgba(126,175,105,.14);color:#3D6B2C}
.hero .section-title{font-size:46px;margin-bottom:16px;line-height:1.2}
.hero .accent{background:linear-gradient(135deg,var(--green),#5C8F4A);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}
.hero .section-sub{margin:0 auto 36px;max-width:480px;font-size:17px}
.hero-cta{display:inline-flex;align-items:center;gap:10px;padding:15px 32px;border-radius:14px;background:linear-gradient(135deg,var(--green),#5C8F4A);color:#fff;text-decoration:none;font-weight:700;font-size:15px;transition:transform .2s,box-shadow .2s;box-shadow:var(--shadow-lg)}
.hero-cta:hover{transform:translateY(-2px);box-shadow:0 12px 36px rgba(126,175,105,.28)}
.hero-meta{margin-top:18px;color:var(--light);font-size:13px}

/* Visual mockup row */
.devices{display:flex;justify-content:center;gap:18px;margin-top:56px;flex-wrap:wrap}
.device-card{background:var(--white);border:1px solid var(--border);border-radius:var(--radius-lg);padding:18px 20px;box-shadow:var(--shadow);min-width:220px;max-width:240px;text-align:left}
.device-card .dev-label{font-size:11px;font-weight:700;color:var(--green);letter-spacing:.6px;text-transform:uppercase}
.device-card .dev-num{font-size:40px;font-weight:800;color:var(--dark);margin:8px 0 2px;font-variant-numeric:tabular-nums;letter-spacing:-1px;display:flex;align-items:baseline;gap:6px}
.device-card .dev-diff{font-size:18px;font-weight:700;color:var(--green);letter-spacing:-.3px}
.device-card.b .dev-diff{color:var(--green-accent)}
.appstore-badge{display:inline-block;line-height:0;transition:transform .2s,opacity .2s;cursor:default;opacity:.85}
.appstore-badge:hover{transform:translateY(-1px);opacity:1}
.appstore-badge svg{display:block;border-radius:9px;box-shadow:var(--shadow-lg)}
.device-card .dev-sub{font-size:12px;color:var(--mid)}
.device-card.b{background:var(--dark);color:#fff;border-color:var(--dark)}
.device-card.b .dev-label{color:var(--green-accent)}
.device-card.b .dev-num{color:#fff}
.device-card.b .dev-sub{color:#A9B6A1}

/* Features */
.section.features{background:var(--surface)}
.features .section-badge{background:rgba(126,175,105,.14);color:#3D6B2C}
.features-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:20px;margin-top:44px}
.feature{background:var(--white);border:1px solid var(--border);border-radius:var(--radius-lg);padding:28px;transition:transform .2s,box-shadow .2s}
.feature:hover{transform:translateY(-3px);box-shadow:var(--shadow-lg)}
.feature .ic{width:44px;height:44px;border-radius:12px;background:linear-gradient(135deg,var(--green-accent),var(--green-light));display:grid;place-items:center;color:var(--dark);font-size:22px;margin-bottom:16px}
.feature h3{font-size:18px;font-weight:700;letter-spacing:-.3px;margin-bottom:8px}
.feature p{font-size:14px;color:var(--mid);line-height:1.7}

/* How it works */
.flow{margin-top:44px;display:grid;grid-template-columns:repeat(4,1fr);gap:14px}
.flow-step{position:relative;padding:22px;background:var(--white);border:1px solid var(--border);border-radius:var(--radius)}
.flow-step .step-n{position:absolute;top:-14px;left:18px;background:var(--green);color:#fff;width:28px;height:28px;border-radius:50%;display:grid;place-items:center;font-size:13px;font-weight:700;box-shadow:var(--shadow)}
.flow-step h4{font-size:15px;font-weight:700;margin:6px 0 6px}
.flow-step p{font-size:13px;color:var(--mid);line-height:1.6}

/* Pillars (privacy / sync / coverage) */
.section.pillars{background:var(--white)}
.pillars-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:18px;margin-top:44px}
.pillar{padding:24px;border-radius:var(--radius-lg);border:1px solid var(--border);background:var(--surface)}
.pillar .ic{width:38px;height:38px;border-radius:10px;background:var(--white);border:1px solid var(--border);display:grid;place-items:center;font-size:18px;margin-bottom:12px}
.pillar h4{font-size:16px;font-weight:700;margin-bottom:8px}
.pillar p{font-size:13.5px;color:var(--mid);line-height:1.65}

/* Viewer demo */
.section.viewer{background:var(--surface);text-align:center}
.viewer-mock{margin:44px auto 0;max-width:560px;background:var(--white);border:1px solid var(--border);border-radius:var(--radius-xl);padding:28px;box-shadow:var(--shadow-lg);text-align:left}
.viewer-mock .url{display:inline-flex;align-items:center;gap:8px;padding:6px 12px;background:var(--green-bg);color:#3D6B2C;border-radius:8px;font-size:12px;font-weight:600;font-family:ui-monospace,Menlo,monospace}
.viewer-mock .vm-title{margin-top:18px;font-size:22px;font-weight:800;letter-spacing:-.5px}
.viewer-mock .vm-sub{margin-top:4px;color:var(--mid);font-size:14px}
.viewer-mock .vm-grid{margin-top:20px;display:grid;grid-template-columns:repeat(3,1fr);gap:10px}
.viewer-mock .vm-cell{background:var(--surface);border-radius:10px;padding:14px;border:1px solid var(--border)}
.viewer-mock .vm-cell .k{font-size:11px;color:var(--mid);text-transform:uppercase;font-weight:700;letter-spacing:.4px}
.viewer-mock .vm-cell .v{font-size:24px;font-weight:800;color:var(--dark);margin-top:2px;font-variant-numeric:tabular-nums;display:flex;align-items:baseline;gap:5px}
.viewer-mock .vm-cell .v-diff{font-size:13px;font-weight:700;color:var(--green)}
.viewer-mock .vm-foot{margin-top:18px;font-size:12px;color:var(--light);display:flex;justify-content:space-between}

/* CTA */
.section.cta{background:linear-gradient(135deg,#3D6B2C 0%,var(--green) 100%);color:#fff;text-align:center}
.cta .section-title{color:#fff;font-size:38px}
.cta .section-sub{color:rgba(255,255,255,.85);margin:0 auto 28px}
.cta a{display:inline-flex;align-items:center;gap:10px;padding:14px 30px;border-radius:14px;background:#fff;color:#3D6B2C;text-decoration:none;font-weight:700;font-size:15px;transition:transform .2s,box-shadow .2s}
.cta a:hover{transform:translateY(-2px);box-shadow:0 12px 36px rgba(0,0,0,.18)}
.cta-note{margin-top:14px;font-size:13px;color:rgba(255,255,255,.75)}

/* Footer */
footer{padding:48px 24px 60px;background:var(--surface);color:var(--mid);font-size:13px;border-top:1px solid var(--border)}
.footer-inner{max-width:1080px;margin:0 auto;display:flex;justify-content:space-between;flex-wrap:wrap;gap:24px}
.footer-brand{display:flex;align-items:center;gap:10px;color:var(--dark);font-weight:700}
.footer-brand .mark{width:30px;height:30px;border-radius:8px;background:linear-gradient(135deg,var(--green),var(--green-light));display:grid;place-items:center;color:#fff;font-weight:800;font-size:14px}
.footer-meta{text-align:right;line-height:1.8}
.footer-meta a{color:var(--mid);text-decoration:none}
.footer-meta a:hover{color:var(--dark)}

@media (max-width: 720px){
  .hero{padding:120px 20px 72px}
  .hero .section-title{font-size:34px}
  section{padding:64px 20px}
  .section-title{font-size:28px}
  .features-grid{grid-template-columns:1fr}
  .flow{grid-template-columns:repeat(2,1fr)}
  .pillars-grid{grid-template-columns:1fr}
  .nav-links a:not(.nav-cta){display:none}
  .footer-inner{flex-direction:column}
  .footer-meta{text-align:left}
  .viewer-mock .vm-grid{grid-template-columns:repeat(2,1fr)}
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
    <div class="nav-links">
      <a href="#features">기능</a>
      <a href="#flow">사용법</a>
      <a href="#viewer">공유</a>
      <a href="#privacy">개인정보</a>
    </div>
  </div>
</nav>

<header class="hero">
  <div class="container">
    <div class="section-badge">iPhone · Apple Watch</div>
    <h1 class="section-title">
      샷마다 <span class="accent">+1</span>, 그게 전부.
    </h1>
    <p class="section-sub">
      복잡한 계산 없이 손목에서 한 번 탭하면 됩니다.
      OB·해저드·OK까지 한 번에 정리되어, 18홀 후 정확한 타수가 카드 한 장으로 남습니다.
    </p>
    <a href="#" class="appstore-badge" aria-label="App Store에서 다운로드 (곧 출시)">
      <svg width="160" height="48" viewBox="0 0 160 48" fill="none" xmlns="http://www.w3.org/2000/svg" role="img">
        <rect width="160" height="48" rx="9" fill="#000"/>
        <path d="M27.9 24.6c0-3.1 2.5-4.6 2.7-4.7-1.5-2.1-3.7-2.4-4.5-2.5-1.9-.2-3.8 1.1-4.7 1.1-1 0-2.5-1.1-4.1-1.1-2.1 0-4.1 1.2-5.1 3.1-2.2 3.8-.6 9.4 1.5 12.5 1.1 1.5 2.3 3.2 4 3.1 1.6-.1 2.2-1 4.2-1s2.5 1 4.2 1c1.7 0 2.9-1.5 4-3 1.3-1.7 1.8-3.4 1.8-3.5-.1 0-3.5-1.3-3.5-5.3zm-3.1-9.7c.9-1.1 1.5-2.6 1.3-4.2-1.3.1-2.9.9-3.8 2-.8 1-1.5 2.5-1.3 4 1.4.1 2.9-.7 3.8-1.8z" fill="#fff"/>
        <text x="49" y="20" font-family="-apple-system,BlinkMacSystemFont,sans-serif" font-size="9" fill="#fff" letter-spacing=".3">Download on the</text>
        <text x="49" y="36" font-family="-apple-system,BlinkMacSystemFont,sans-serif" font-size="17" font-weight="600" fill="#fff" letter-spacing="-.3">App Store</text>
      </svg>
    </a>
    <div class="hero-meta">곧 만나요</div>

    <div class="devices">
      <div class="device-card">
        <div class="dev-label">현재 홀</div>
        <div class="dev-num">7</div>
        <div class="dev-sub">par 4 · 18홀 진행</div>
      </div>
      <div class="device-card b">
        <div class="dev-label">손목 카운터</div>
        <div class="dev-num">5</div>
        <div class="dev-sub">+1 / −1 / OB +2</div>
      </div>
      <div class="device-card">
        <div class="dev-label">오늘 합계</div>
        <div class="dev-num">75 <span class="dev-diff">+3</span></div>
        <div class="dev-sub">par 72 기준 · 4인 라운드</div>
      </div>
    </div>
  </div>
</header>

<section id="features" class="features">
  <div class="container">
    <div class="text-center">
      <div class="section-badge">core features</div>
      <h2 class="section-title">필요한 것만, 단단하게</h2>
      <p class="section-sub mx-auto">스코어카드에 적던 그 흐름 그대로. 다만 펜과 종이가 손목과 폰이 되었을 뿐.</p>
    </div>
    <div class="features-grid">
      <div class="feature">
        <div class="ic">📍</div>
        <h3>골프장 자동 인식</h3>
        <p>도착하면 GPS가 현재 골프장과 전반/후반 코스를 자동으로 잡아줍니다.
        매칭이 애매하면 후보를 보여주거나 직접 검색할 수 있어요.</p>
      </div>
      <div class="feature">
        <div class="ic">🏌️</div>
        <h3>코스 정보 자동 제공</h3>
        <p>전국 골프장의 par와 서브코스 정보가 미리 채워져 있습니다.
        첫 홀부터 신경 쓸 일 없이 시작하면 됩니다.</p>
      </div>
      <div class="feature">
        <div class="ic">⌚️</div>
        <h3>Apple Watch 연동</h3>
        <p>손목에서 한 번 탭하면 폰의 스코어카드가 즉시 갱신됩니다.
        OB·해저드·OK도 손목에서 바로. 폰을 꺼낼 일이 없어요.</p>
      </div>
      <div class="feature">
        <div class="ic">📊</div>
        <h3>라운드 카드 공유</h3>
        <p>라운드가 끝나면 한 장의 카드가 됩니다.
        링크 하나로 동반자에게 공유, PIN으로 보호할 수도 있어요.</p>
      </div>
    </div>
  </div>
</section>

<section id="flow">
  <div class="container">
    <div class="text-center">
      <div class="section-badge" style="background:rgba(126,175,105,.14);color:#3D6B2C">how it works</div>
      <h2 class="section-title">시작 → 카운트 → 공유</h2>
      <p class="section-sub mx-auto">앱을 켜고 라운드가 끝날 때까지, 별도의 설정은 없습니다.</p>
    </div>
    <div class="flow">
      <div class="flow-step">
        <div class="step-n">1</div>
        <h4>골프장 자동 인식</h4>
        <p>도착하면 위치로 골프장과 전반/후반 코스를 찾습니다.</p>
      </div>
      <div class="flow-step">
        <div class="step-n">2</div>
        <h4>par는 미리 채워짐</h4>
        <p>익숙한 골프장이면 첫 홀부터 par가 맞춰져 있습니다.</p>
      </div>
      <div class="flow-step">
        <div class="step-n">3</div>
        <h4>샷마다 손목 탭</h4>
        <p>Apple Watch에서 +1 / −1. iPhone과 즉시 동기화.</p>
      </div>
      <div class="flow-step">
        <div class="step-n">4</div>
        <h4>카드로 공유</h4>
        <p>한 장의 라운드 카드로 동반자에게 링크 전송.</p>
      </div>
    </div>
  </div>
</section>

<section id="viewer" class="viewer">
  <div class="container">
    <div class="text-center">
      <div class="section-badge" style="background:rgba(126,175,105,.14);color:#3D6B2C">share</div>
      <h2 class="section-title">라운드 한 장, 링크 하나</h2>
      <p class="section-sub mx-auto">앱이 없어도 누구나 볼 수 있는 카드. 7일 후 자동으로 사라집니다.</p>
    </div>
    <div class="viewer-mock">
      <span class="url">🔗 golf.zerolive.co.kr/9k3xa8mr</span>
      <div class="vm-title">아리지CC · 햇님 / 달님</div>
      <div class="vm-sub">2026-05-19 화 · 18홀 · 4인 라운드</div>
      <div class="vm-grid">
        <div class="vm-cell"><div class="k">나</div><div class="v">75 <span class="v-diff">+3</span></div></div>
        <div class="vm-cell"><div class="k">동반자1</div><div class="v">79 <span class="v-diff">+7</span></div></div>
        <div class="vm-cell"><div class="k">동반자2</div><div class="v">84 <span class="v-diff">+12</span></div></div>
      </div>
      <div class="vm-foot">
        <span>KST · 7일 후 자동 삭제</span>
        <span>PIN 보호 가능</span>
      </div>
    </div>
  </div>
</section>

<section id="privacy" class="pillars">
  <div class="container">
    <div class="text-center">
      <div class="section-badge" style="background:rgba(126,175,105,.14);color:#3D6B2C">privacy & care</div>
      <h2 class="section-title">조용히, 안전하게</h2>
      <p class="section-sub mx-auto">기록은 사용자의 것입니다. 앱은 필요한 만큼만 다룹니다.</p>
    </div>
    <div class="pillars-grid">
      <div class="pillar">
        <div class="ic">🔒</div>
        <h4>위치는 외부로 전송하지 않습니다</h4>
        <p>GPS 좌표는 기기 안에서 골프장 매칭에만 사용됩니다.
        외부 서버로 보내지 않습니다.</p>
      </div>
      <div class="pillar">
        <div class="ic">⏳</div>
        <h4>공유 카드는 7일 후 사라집니다</h4>
        <p>viewer 링크는 보관 기간이 끝나면 자동 삭제됩니다.
        본인은 언제든 직접 삭제할 수 있습니다.</p>
      </div>
      <div class="pillar">
        <div class="ic">🏷️</div>
        <h4>동반자는 별명만</h4>
        <p>동반자는 별명으로만 기록됩니다.
        실명·연락처는 받지 않습니다.</p>
      </div>
    </div>
  </div>
</section>

<section id="cta" class="cta">
  <div class="container">
    <h2 class="section-title">곧 만나요</h2>
    <p class="section-sub mx-auto">App Store에서 만나뵐 준비를 하고 있습니다.</p>
    <a href="#" class="appstore-badge appstore-badge-cta" aria-label="App Store에서 다운로드 (곧 출시)">
      <svg width="180" height="54" viewBox="0 0 160 48" fill="none" xmlns="http://www.w3.org/2000/svg" role="img">
        <rect width="160" height="48" rx="9" fill="#000"/>
        <path d="M27.9 24.6c0-3.1 2.5-4.6 2.7-4.7-1.5-2.1-3.7-2.4-4.5-2.5-1.9-.2-3.8 1.1-4.7 1.1-1 0-2.5-1.1-4.1-1.1-2.1 0-4.1 1.2-5.1 3.1-2.2 3.8-.6 9.4 1.5 12.5 1.1 1.5 2.3 3.2 4 3.1 1.6-.1 2.2-1 4.2-1s2.5 1 4.2 1c1.7 0 2.9-1.5 4-3 1.3-1.7 1.8-3.4 1.8-3.5-.1 0-3.5-1.3-3.5-5.3zm-3.1-9.7c.9-1.1 1.5-2.6 1.3-4.2-1.3.1-2.9.9-3.8 2-.8 1-1.5 2.5-1.3 4 1.4.1 2.9-.7 3.8-1.8z" fill="#fff"/>
        <text x="49" y="20" font-family="-apple-system,BlinkMacSystemFont,sans-serif" font-size="9" fill="#fff" letter-spacing=".3">Download on the</text>
        <text x="49" y="36" font-family="-apple-system,BlinkMacSystemFont,sans-serif" font-size="17" font-weight="600" fill="#fff" letter-spacing="-.3">App Store</text>
      </svg>
    </a>
    <div class="cta-note">출시 알림은 추후 이 자리에서 안내드립니다</div>
  </div>
</section>

<footer>
  <div class="footer-inner">
    <div>
      <div class="footer-brand">
        <span class="mark">R</span>
        <span>라운드온 (Round-On)</span>
      </div>
      <p style="margin-top:10px;max-width:420px;font-size:12.5px;line-height:1.7">
        iPhone과 Apple Watch로 함께 사용하는 골프 스코어 카운터.
        라운드를 기록하고, 한 장의 카드로 공유합니다.
      </p>
    </div>
    <div class="footer-meta">
      © 2026 zerolive.co.kr<br>
      <a href="mailto:zerolive@altimedia.com">zerolive@altimedia.com</a><br>
      <span style="font-size:11px;color:var(--light)">© OpenStreetMap contributors, ODbL 1.0</span>
    </div>
  </div>
</footer>

</body>
</html>
`;

/**
 * GET / 핸들러 — 정적 HTML 응답
 */
export function handleGetLanding(): Response {
  return new Response(HTML, {
    headers: {
      "Content-Type": "text/html; charset=UTF-8",
      "Cache-Control": "public, max-age=3600, stale-while-revalidate=86400",
      "X-Content-Type-Options": "nosniff",
    },
  });
}
