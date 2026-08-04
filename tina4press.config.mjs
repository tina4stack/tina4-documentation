// tina4press config for tina4.com — mirrors the VitePress themeConfig so this
// is a copy-paste port. Sidebars are auto-generated from the folder structure;
// override per-section here later to match the exact VitePress grouping.

// Menu groups are declared by NAME. Nothing derives a group from a filename
// number any more.
//
// This replaces sidebarRangesDefault, a group-name -> numeric-range table
// ("Foundations": [1, 10]) that every numbered section shared. It made a page's
// menu placement a side effect of its file number, with three consequences:
//
//   1. Inserting one chapter renumbered every chapter after it and silently
//      moved pages into a different group.
//   2. A chapter numbered past the last range (40+) matched nothing and
//      vanished from the sidebar with no error.
//   3. Sections that are not the backend chapter set were grouped by ranges
//      written for it. delphi's 15 chapters were filed under "Foundations" and
//      "Building Apps", and general's four under "Foundations" - names nobody
//      chose for them. realtime-webrtc, a headline feature, sat in "Appendix"
//      purely because it is numbered 39.
//
// The numbers still order chapters WITHIN a group (files are read in sorted
// order), and every published URL is unchanged - only the grouping stopped
// depending on them.
const BACKEND_GROUPS = [
  {
    text: "Foundations",
    stems: ["getting-started", "routing", "request-response", "templates",
            "database", "orm", "query-builder", "authentication",
            "sessions-cookies", "middleware-security"],
  },
  {
    text: "Building Apps",
    stems: ["caching", "queues", "events", "localization", "logging",
            "email", "frontend", "testing", "scaffolding"],
  },
  {
    text: "APIs & Protocols",
    stems: ["swagger", "api-client", "graphql", "websocket", "sse",
            "wsdl-soap", "realtime-webrtc"],
  },
  {
    text: "Advanced",
    stems: ["di-container", "service-runner", "mcp-dev-tools",
            "custom-mcp-servers"],
  },
  { text: "Developer Tools", stems: ["dev-tools", "cli", "vibe-coding-with-ai"] },
  { text: "Operations", stems: ["environment-variables", "deployment", "complete-app"] },
  { text: "Releases", stems: ["releases"] },
  { text: "Reference", stems: ["upgrading-from-v2", "feature-list"] },
];

export default {
  title: "Tina4",
  description: "One framework, four languages, ninety-seven features, zero runtime dependencies.",
  base: "/",
  cleanUrls: true,
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
      { text: "Code Viewer", link: "/download/code-viewer/" },
    ],
    sidebar: null, // auto, section-scoped; grouped below (ported from SECTION_GROUPS)
    sectionLabels: { js: "tina4-js", python: "Python", nodejs: "Node.js", php: "PHP", ruby: "Ruby", delphi: "Delphi", general: "Understanding Tina4", v2: "v2 Docs" },
    // Built-in RAG chat ("Ask Tina4") — floating widget, hits the hosted RAG.
    chat: { api: "https://rag.tina4.com", label: "Ask Tina4", model: "Powered by Tina4", placeholder: "How do I define a route?" },
    // EVERY numbered section declares its groups by name below. There is no
    // numeric-range fallback any more: a section without an entry here gets a
    // flat, complete list rather than pages silently sorted into groups that
    // were written for a different doc set.
    sidebarGroups: {
      js: [
        { text: "Getting Started", stems: ["getting-started"] },
        { text: "Core Concepts", stems: ["signals", "storage", "html-templates", "components", "routing"] },
        { text: "Features", stems: ["api", "websocket", "sse-streaming", "graphql", "i18n", "pwa", "realtime-rtc"] },
        { text: "Tooling", stems: ["debug", "tina4-css"] },
        { text: "Guides", stems: ["backend-integration", "building-a-complete-app", "patterns-and-pitfalls", "vibe-coding-with-ai"] },
      ],
      // The four backend framework docs share one chapter set (same stems,
      // same numbering), so they share one grouping. A chapter a language
      // does not have simply does not appear for it - upgrading-from-v2
      // exists only in python and php, and no group needs to know that.
      python: BACKEND_GROUPS,
      php: BACKEND_GROUPS,
      ruby: BACKEND_GROUPS,
      nodejs: BACKEND_GROUPS,
      // Delphi is its own toolkit, not the backend chapter set. It was being
      // grouped by the backend ranges, so its 15 chapters read "Foundations"
      // and "Building Apps".
      delphi: [
        { text: "Getting Started", stems: ["getting-started"] },
        { text: "Core", stems: ["rest-apis", "json-data-binding", "core-utilities"] },
        { text: "Pages & Templates", stems: ["html-rendering", "page-navigation", "templates"] },
        { text: "Realtime", stems: ["websockets", "socket-server"] },
        { text: "Guides", stems: ["crud-app", "integration", "claude-code", "complete-app", "patterns", "troubleshooting"] },
      ],
      // Four conceptual pages that were all landing under "Foundations".
      general: [
        {
          text: "Understanding Tina4",
          stems: ["what-is-tina4", "architecture", "choosing-your-language", "environment-variables"],
        },
      ],
    },
    search: true,
    footer: "Simple. Fast. Human. · MIT licensed",
  },
};
