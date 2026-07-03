// Custom theme extension. We keep VitePress's default theme entirely
// intact and only override one slot — `home-hero-image` — so the
// SVGator-animated logo gets loaded via <object> instead of <img>.
// (Without this, browsers ignore the embedded <script> and the SVG is
// frozen on the first frame.)
import { h } from 'vue'
import DefaultTheme from 'vitepress/theme'
import HomeHeroImage from './HomeHeroImage.vue'
import InstallTabs from './InstallTabs.vue'
import FeaturesGrid from './FeaturesGrid.vue'
import TinaCoderPromo from './TinaCoderPromo.vue'
import './style.css'

export default {
  extends: DefaultTheme,
  Layout() {
    return h(DefaultTheme.Layout, null, {
      'home-hero-image': () => h(HomeHeroImage),
      'home-features-before': () => h(InstallTabs),
    })
  },
  enhanceApp({ app }) {
    app.component('FeaturesGrid', FeaturesGrid)
    app.component('TinaCoderPromo', TinaCoderPromo)
  },
}
