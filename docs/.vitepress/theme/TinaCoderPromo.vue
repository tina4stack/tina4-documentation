<!--
  Tina4 Coding Models call-to-action.
  Registered globally in theme/index.ts and dropped into a page as <TinaCoderPromo />.
  A single compact CTA (headline + one line + button). Styling uses VitePress theme
  tokens (--vp-c-*, --vp-button-brand-*) so it blends with the site in light / dark.
  It lives here (not inline in markdown) because an inline <style> in a VitePress .md
  breaks the Vue/markdown compiler.
-->
<template>
  <section class="t4-cta">
    <div class="wrap">
      <span class="eyebrow">New - Free for developers</span>
      <h2>An AI that actually knows Tina4</h2>
      <p>Free, in-house fine-tuned coding models that write idiomatic Tina4 right in your
        editor. They run on our infrastructure, so they never spend your Claude tokens.</p>
      <a class="cta" href="https://profile.tina4.com">Get your free token -&gt;</a>
      <p class="fine">Login with GitHub, star a Tina4 repo, copy your token. 250 requests/day, free.</p>
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
.t4-cta .wrap{max-width:640px;margin:0 auto;text-align:center}
.t4-cta .eyebrow{display:inline-block;font-size:.75rem;font-weight:700;letter-spacing:.08em;
  text-transform:uppercase;color:var(--vp-c-brand-1);
  border:1px solid var(--vp-c-brand-soft);background:var(--vp-c-brand-soft);
  padding:5px 12px;border-radius:999px;margin-bottom:16px}
.t4-cta h2{font-size:clamp(1.6rem,3.6vw,2.2rem);margin:.1em 0;letter-spacing:-.02em;
  border:0;padding:0;color:var(--vp-c-text-1)}
.t4-cta p{color:var(--vp-c-text-2);max-width:56ch;margin:12px auto 0;font-size:1.02rem}
.t4-cta .cta{display:inline-flex;align-items:center;gap:8px;margin-top:22px;font-weight:600;
  text-decoration:none;border-radius:20px;padding:0 24px;line-height:42px;font-size:1rem;
  border:1px solid var(--vp-button-brand-border);
  color:var(--vp-button-brand-text);background:var(--vp-button-brand-bg);
  transition:background-color .25s,border-color .25s,color .25s}
.t4-cta .cta:hover{border-color:var(--vp-button-brand-hover-border);
  color:var(--vp-button-brand-hover-text);background:var(--vp-button-brand-hover-bg)}
.t4-cta .fine{color:var(--vp-c-text-3);font-size:.85rem;margin-top:14px}
</style>
