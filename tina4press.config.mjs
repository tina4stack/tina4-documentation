// tina4press config for tina4.com — mirrors the VitePress themeConfig so this
// is a copy-paste port. Sidebars are auto-generated from the folder structure;
// override per-section here later to match the exact VitePress grouping.
export default {
  title: "Tina4",
  description: "One framework, four languages, fifty-five features, zero runtime dependencies.",
  base: "/",
  cleanUrls: false, // reverted: dir-style clean URLs 500'd on the live Apache (MultiViews conflict between /foo.html stub and /foo/ dir). Investigate before re-enabling.
  srcDir: "docs",
  outDir: "docs/.vitepress/dist",
  themeConfig: {
    analytics: "G-FZRRSBE9M0",
    // All theme colors as constants — tweak these to retheme the whole site.
    colors: {
      light: { brand: "#2f5fe0", brand2: "#4888ff" },
      dark: {
        brand: "#8db4ff", brand2: "#6b9bff",
        bg: "#17130f", bgSoft: "#201a15", bgMute: "#2a221b",
        border: "#352b22", border2: "#45392e",
        fg: "#ece4da", fg2: "#b4a99a", fg3: "#8a7d6d",
        codeBg: "#140f0b", sel: "#3a2f22",
      },
    },
    logo: "/logo.svg",
    nav: [
      { text: "Home", link: "index.html" },
      { text: "Introduction", link: "general/01-what-is-tina4.html" },
      { text: "tina4-js", link: "js/index.html" },
      { text: "Python", link: "python/index.html" },
      { text: "Node.js", link: "nodejs/index.html" },
      { text: "PHP", link: "php/index.html" },
      { text: "Ruby", link: "ruby/index.html" },
      { text: "Delphi", link: "delphi/index.html" },
    ],
    sidebar: null, // auto, section-scoped; grouped below (ported from SECTION_GROUPS)
    sectionLabels: { js: "tina4-js", python: "Python", nodejs: "Node.js", php: "PHP", ruby: "Ruby", delphi: "Delphi", general: "Understanding Tina4", v2: "v2 Docs" },
    // Built-in RAG chat ("Ask Tina4") — floating widget, hits the hosted RAG.
    chat: { api: "https://rag.tina4.com", label: "Ask Tina4", model: "Powered by Tina4", placeholder: "How do I define a route?" },
    // js uses name-based groups (above); every other chapter section uses this
    // one numeric range table (ported from VitePress SECTION_RANGES).
    sidebarRangesDefault: {
      "Foundations": [1, 10],
      "Building Apps": [11, 19],
      "APIs & Protocols": [20, 25],
      "Advanced": [26, 29],
      "Developer Tools": [30, 32],
      "Operations": [33, 35],
      "Releases": [36, 36],
      "Appendix": [37, 39],
    },
    sidebarGroups: {
      js: [
        { text: "Getting Started", stems: ["getting-started"] },
        { text: "Core Concepts", stems: ["signals", "storage", "html-templates", "components", "routing"] },
        { text: "Features", stems: ["api", "websocket", "sse-streaming", "graphql", "i18n", "pwa", "realtime-rtc"] },
        { text: "Tooling", stems: ["debug", "tina4-css"] },
        { text: "Guides", stems: ["backend-integration", "building-a-complete-app", "patterns-and-pitfalls", "vibe-coding-with-ai"] },
      ],
    },
    search: true,
    footer: "Simple. Fast. Human. · MIT licensed",
  },
};
