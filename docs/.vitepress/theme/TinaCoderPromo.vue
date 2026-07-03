<!--
  Tina4 Coding Models + API tokens promo.
  Registered globally in theme/index.ts and dropped into a page as <TinaCoderPromo />.
  Styling uses VitePress theme tokens (--vp-c-*, --vp-button-brand-*) so the block
  blends with the site and adapts to light / dark mode. CSS is namespaced under
  .t4-mcp; it lives here (not inline in markdown) because an inline <style> in a
  VitePress .md breaks the Vue/markdown compiler.
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
.t4-mcp{
  background:var(--vp-c-bg-soft);
  border:1px solid var(--vp-c-divider);
  border-radius:16px;
  padding:56px 24px;
  margin:32px 0;
  line-height:1.55;
}
.t4-mcp *{box-sizing:border-box}
.t4-mcp .wrap{max-width:820px;margin:0 auto;text-align:center}
.t4-mcp .eyebrow{display:inline-block;font-size:.75rem;font-weight:700;letter-spacing:.08em;
  text-transform:uppercase;color:var(--vp-c-brand-1);
  border:1px solid var(--vp-c-brand-soft);background:var(--vp-c-brand-soft);
  padding:5px 12px;border-radius:999px;margin-bottom:18px}
.t4-mcp h2{font-size:clamp(1.7rem,4vw,2.4rem);margin:.1em 0;letter-spacing:-.02em;
  border:0;padding:0;color:var(--vp-c-text-1)}
.t4-mcp .lead{color:var(--vp-c-text-2);max-width:60ch;margin:14px auto 0;font-size:1.05rem}
.t4-mcp .lead b{color:var(--vp-c-text-1)}
.t4-mcp .feats{display:flex;flex-wrap:wrap;gap:8px;justify-content:center;margin:22px auto 0}
.t4-mcp .feats span{font-size:.82rem;color:var(--vp-c-text-2);background:var(--vp-c-bg);
  border:1px solid var(--vp-c-divider);border-radius:8px;padding:5px 11px}
.t4-mcp .steps{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin:36px 0 8px;text-align:left}
@media(max-width:680px){.t4-mcp .steps{grid-template-columns:1fr}}
.t4-mcp .step{background:var(--vp-c-bg);border:1px solid var(--vp-c-divider);border-radius:12px;padding:20px}
.t4-mcp .step .n{width:28px;height:28px;border-radius:8px;display:grid;place-items:center;
  font-weight:700;color:var(--vp-c-white);background:var(--vp-c-brand-1);margin-bottom:12px}
.t4-mcp .step h3{margin:0 0 4px;font-size:1rem;border:0;padding:0;color:var(--vp-c-text-1)}
.t4-mcp .step p{margin:0;color:var(--vp-c-text-2);font-size:.9rem}
.t4-mcp .step a{color:var(--vp-c-brand-1);text-decoration:none;font-weight:500}
.t4-mcp .step a:hover{text-decoration:underline}
.t4-mcp pre{text-align:left;background:var(--vp-code-block-bg);border:1px solid var(--vp-c-divider);
  border-radius:12px;padding:16px 18px;overflow-x:auto;margin:26px auto 0;max-width:720px}
.t4-mcp code{font-family:var(--vp-font-family-mono);font-size:.85rem;color:var(--vp-c-text-1);background:transparent}
.t4-mcp .cta{display:inline-flex;align-items:center;gap:8px;margin-top:28px;font-weight:600;
  text-decoration:none;border-radius:20px;padding:0 22px;line-height:38px;
  border:1px solid var(--vp-button-brand-border);
  color:var(--vp-button-brand-text);background:var(--vp-button-brand-bg);
  transition:background-color .25s,border-color .25s,color .25s}
.t4-mcp .cta:hover{border-color:var(--vp-button-brand-hover-border);
  color:var(--vp-button-brand-hover-text);background:var(--vp-button-brand-hover-bg)}
.t4-mcp .fine{color:var(--vp-c-text-3);font-size:.82rem;margin-top:14px}
</style>
