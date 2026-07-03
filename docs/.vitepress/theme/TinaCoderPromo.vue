<!--
  Tina4 Coding Models call-to-action.
  Registered globally in theme/index.ts and dropped into a page as <TinaCoderPromo />.
  Title + one line of context + a call-to-action button. Styling uses VitePress theme
  tokens (--vp-c-*, --vp-button-brand-*) so it blends with the site in light / dark. It
  lives here (not inline in markdown) because an inline <style> in a VitePress .md breaks
  the Vue/markdown compiler.
-->
<template>
  <section class="t4-cta">
    <div class="wrap">
      <h2>Save your paid tokens for the hard parts</h2>
      <p>Let a model that already knows Tina4 write the routes, models, and Tina4CSS. It
        runs on our infrastructure, so the boilerplate costs nothing and your paid tokens
        stay free for the real work. 250 requests a day.</p>
      <a class="cta" href="https://profile.tina4.com">Get your free token -&gt;</a>
    </div>
  </section>
</template>

<style>
.t4-cta{
  background:var(--vp-c-bg-soft);
  border:1px solid var(--vp-c-divider);
  border-radius:16px;
  padding:40px 24px;
  margin:32px 0;
  line-height:1.55;
}
.t4-cta *{box-sizing:border-box}
.t4-cta .wrap{max-width:620px;margin:0 auto;text-align:center;
  display:flex;flex-direction:column;align-items:center;gap:16px}
.t4-cta h2{font-size:clamp(1.6rem,3.6vw,2.2rem);margin:0;letter-spacing:-.02em;
  border:0;padding:0;color:var(--vp-c-text-1)}
.t4-cta p{margin:0;color:var(--vp-c-text-2);font-size:1.02rem;max-width:54ch}
.t4-cta .cta{display:inline-flex;align-items:center;gap:8px;margin-top:4px;font-weight:600;
  text-decoration:none;border-radius:20px;padding:0 24px;line-height:42px;font-size:1rem;
  border:1px solid var(--vp-button-brand-border);
  color:var(--vp-button-brand-text);background:var(--vp-button-brand-bg);
  transition:background-color .25s,border-color .25s,color .25s}
.t4-cta .cta:hover{border-color:var(--vp-button-brand-hover-border);
  color:var(--vp-button-brand-hover-text);background:var(--vp-button-brand-hover-bg)}
</style>
