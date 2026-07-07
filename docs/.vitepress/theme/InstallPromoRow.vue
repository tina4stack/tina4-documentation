<!--
  Two-column row on the home page: the Install tabs (left) beside the Tina4
  Coding Models "Register Now" promo (right). Registered into the
  `home-features-before` slot in theme/index.ts. Collapses to a single stacked
  column on narrow screens. Both children keep their own styling; this wrapper
  only neutralises their outer width/margin/padding so the grid controls the
  layout and the two cards line up at equal height.
-->
<script setup lang="ts">
import InstallTabs from './InstallTabs.vue'
import TinaCoderPromo from './TinaCoderPromo.vue'
</script>

<template>
  <div class="t4-install-promo">
    <div class="col"><InstallTabs /></div>
    <div class="col"><TinaCoderPromo /></div>
  </div>
</template>

<style>
.t4-install-promo {
  max-width: 1152px;
  margin: 8px auto;
  padding: 0 24px;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24px;
  align-items: stretch;
}
.t4-install-promo .col {
  display: flex;
  flex-direction: column;
  min-width: 0; /* allow the column to shrink below the command's intrinsic width */
}
/* Let each child fill its grid cell instead of self-centering at its own width. */
.t4-install-promo .install {
  padding: 0;
  margin: 0;
  flex: 1;
}
.t4-install-promo .install .install-inner {
  max-width: none;
}
.t4-install-promo .t4-cta {
  margin: 0;
  flex: 1;
  display: flex;
  align-items: center;
}
.t4-install-promo .t4-cta .wrap {
  max-width: none;
}
@media (min-width: 640px) {
  .t4-install-promo { padding: 0 48px; }
}
@media (min-width: 960px) {
  .t4-install-promo { padding: 0 64px; }
}
@media (max-width: 768px) {
  .t4-install-promo {
    grid-template-columns: 1fr;
    gap: 16px;
  }
}
</style>
