<script setup lang="ts">
// VitePress's default home hero renders the `image:` field as an <img>
// element. Browsers strip <script> tags out of SVGs loaded that way, so
// the SVGator-generated animation in tina4-animated.svg never runs.
//
// Loading the same file via <object> tells the browser to render the SVG
// as a document — scripts inside are executed normally, and the
// animation plays.
//
// Wrapped in <Suspense> so VitePress's SSR pass doesn't fight the
// browser-only animation.
</script>

<template>
  <object
    type="image/svg+xml"
    data="/images/tina4-animated.svg"
    class="VPImage image-src tina4-animated-logo"
    aria-label="Tina4 animated logo"
  />
</template>

<style scoped>
.tina4-animated-logo {
  /* Match the default VitePress hero image sizing so the layout doesn't
     shift when the SVG resolves. The 320x320 ceiling matches what the
     default theme's <VPImage> uses for the hero block. */
  max-width: 320px;
  max-height: 320px;
  width: 100%;
  height: auto;
  pointer-events: none; /* Decorative — no click target needed. */
}
</style>
