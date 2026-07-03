<!--
  Tina4 Coding Models + API tokens promo.
  Registered globally in theme/index.ts and dropped into a page as <TinaCoderPromo />.
  CSS lives here (not inline in markdown) because an inline <style> block in a
  VitePress .md breaks the Vue/markdown compiler. All rules are namespaced under
  .t4-mcp so this is safe as global CSS.
-->
<template>
  <section class="t4-mcp">
    <div class="wrap">
      <span class="eyebrow">New - Free for developers</span>
      <h2>An AI that actually knows Tina4</h2>
      <p class="lead">Our in-house fine-tuned coding models write <b>idiomatic Tina4</b> -
        routes, ORM field objects, queues, Tina4CSS, Swagger, MCP servers, and tina4js -
        right inside your editor. It runs on our infrastructure, so it's <b>free</b> and
        never spends your Claude tokens.</p>

      <div class="feats">
        <span>tina4-python</span><span>tina4-php</span><span>tina4js</span>
        <span>Tina4CSS</span><span>Queues &amp; ORM</span><span>MCP servers</span>
        <span>screenshot -&gt; code</span>
      </div>

      <div class="steps">
        <div class="step">
          <div class="n">1</div><h3>Login with GitHub</h3>
          <p>Sign in at <a href="https://profile.tina4.com">profile.tina4.com</a> - takes seconds.</p>
        </div>
        <div class="step">
          <div class="n">2</div><h3>Star a Tina4 repo</h3>
          <p>Star <a href="https://github.com/tina4stack/tina4-python">tina4-python</a>,
             <a href="https://github.com/tina4stack/tina4-php">php</a> or
             <a href="https://github.com/tina4stack/tina4-js">js</a> to activate.</p>
        </div>
        <div class="step">
          <div class="n">3</div><h3>Get your API token</h3>
          <p>Copy your token and connect the MCP - 250 requests/day, free.</p>
        </div>
      </div>

      <pre><code>claude mcp add --transport http tina4-coder https://mcp.tina4.com/mcp \
  --header "Authorization: Bearer &lt;your-token&gt;"</code></pre>

      <a class="cta" href="https://profile.tina4.com">Get your free token -&gt;</a>
      <p class="fine">Unlimited access via sponsorship - coming soon.</p>
    </div>
  </section>
</template>

<style>
.t4-mcp{--ink:#0e1116;--panel:#161b22;--line:#232a34;--mut:#8b98a5;--fg:#e6edf3;
  --accent:#7C5CFF;--accent2:#37E2D5;--gold:#FFB800;
  background:radial-gradient(900px 480px at 50% -20%,#1a2233,#0e1116);
  color:var(--fg);font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
  padding:72px 20px;line-height:1.55;border-radius:16px;margin:28px 0}
.t4-mcp *{box-sizing:border-box}
.t4-mcp .wrap{max-width:960px;margin:0 auto;text-align:center}
.t4-mcp .eyebrow{display:inline-block;font-size:.78rem;font-weight:700;letter-spacing:.08em;
  text-transform:uppercase;color:var(--accent2);border:1px solid var(--line);
  padding:5px 12px;border-radius:999px;margin-bottom:18px}
.t4-mcp h2{font-size:clamp(1.8rem,4vw,2.7rem);margin:.1em 0;letter-spacing:-.02em;
  border:0;padding:0;
  background:linear-gradient(120deg,#fff,#b9c4d0);
  -webkit-background-clip:text;background-clip:text;color:transparent}
.t4-mcp .lead{color:#aeb9c7;max-width:60ch;margin:14px auto 0;font-size:1.08rem}
.t4-mcp .feats{display:flex;flex-wrap:wrap;gap:10px;justify-content:center;margin:22px auto 0}
.t4-mcp .feats span{font-size:.85rem;color:#cdd6e2;background:rgba(255,255,255,.04);
  border:1px solid var(--line);border-radius:8px;padding:6px 11px}
.t4-mcp .steps{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin:40px 0 8px;text-align:left}
@media(max-width:680px){.t4-mcp .steps{grid-template-columns:1fr}}
.t4-mcp .step{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:20px}
.t4-mcp .step .n{width:30px;height:30px;border-radius:8px;display:grid;place-items:center;
  font-weight:800;color:#0e1116;background:linear-gradient(135deg,var(--gold),#FF8A00);margin-bottom:12px}
.t4-mcp .step h3{margin:0 0 4px;font-size:1.02rem;border:0;padding:0}
.t4-mcp .step p{margin:0;color:var(--mut);font-size:.92rem}
.t4-mcp .step a{color:var(--accent2);text-decoration:none}
.t4-mcp pre{text-align:left;background:#0b0e13;border:1px solid var(--line);border-radius:12px;
  padding:16px 18px;overflow-x:auto;margin:26px auto 0;max-width:720px}
.t4-mcp code{font-family:"SF Mono",Menlo,Consolas,monospace;font-size:.9rem;color:#cfe8e4;background:none}
.t4-mcp .cta{display:inline-flex;align-items:center;gap:10px;margin-top:30px;font-weight:700;
  text-decoration:none;color:#0e1116;background:linear-gradient(135deg,var(--gold),#FF8A00);
  padding:13px 24px;border-radius:12px;box-shadow:0 10px 28px rgba(255,138,0,.3)}
.t4-mcp .cta:hover{filter:brightness(1.05)}
.t4-mcp .fine{color:var(--mut);font-size:.85rem;margin-top:16px}
</style>
