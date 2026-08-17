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
// ── Site links ────────────────────────────────────────────────────────────
//
// Add a link by adding an entry. `icon` is inline SVG (no external request, no
// icon font, no build step) and every path is drawn on a 24x24 viewBox so they
// share one size rule.
//
// SIZE: 22px, set once in SITE_LINK_CSS. The VitePress site rendered these at
// the usual 16px social-icon size and they were too small to read as buttons,
// which is the specific complaint this replaces. Change the --tp-site-icon
// value below to resize every icon at once.
const SITE_LINKS = [
  {
    text: "GitHub",
    href: "https://github.com/tina4stack",
    label: "Tina4 on GitHub",
    icon: `<path d="M12 .5C5.37.5 0 5.87 0 12.5c0 5.3 3.44 9.8 8.21 11.39.6.11.82-.26.82-.58 0-.29-.01-1.05-.02-2.06-3.34.73-4.04-1.61-4.04-1.61-.55-1.39-1.34-1.76-1.34-1.76-1.09-.75.08-.73.08-.73 1.21.09 1.84 1.24 1.84 1.24 1.07 1.84 2.81 1.31 3.5 1 .11-.78.42-1.31.76-1.61-2.67-.3-5.47-1.33-5.47-5.93 0-1.31.47-2.38 1.24-3.22-.13-.3-.54-1.52.11-3.18 0 0 1.01-.32 3.3 1.23a11.5 11.5 0 0 1 6.01 0c2.29-1.55 3.3-1.23 3.3-1.23.65 1.66.24 2.88.12 3.18.77.84 1.23 1.91 1.23 3.22 0 4.61-2.8 5.62-5.48 5.92.43.37.81 1.1.81 2.22 0 1.61-.01 2.9-.01 3.29 0 .32.21.7.83.58A12.01 12.01 0 0 0 24 12.5C24 5.87 18.63.5 12 .5z"/>`,
  },
  {
    text: "Code Infinity",
    href: "https://codeinfinity.co.za",
    label: "Code Infinity, the team behind Tina4",
    // A plain "code" glyph: angle brackets around a slash.
    icon: `<path d="M8.7 17.3 3.4 12l5.3-5.3 1.4 1.4L6.2 12l3.9 3.9-1.4 1.4Zm6.6 0-1.4-1.4 3.9-3.9-3.9-3.9 1.4-1.4L20.6 12l-5.3 5.3Z"/>`,
  },
];

// One rule set, injected once in <head> (see `head` below) rather than once
// per slot render.
const SITE_LINK_CSS = `
:root { --tp-site-icon: 22px; }
.tp-site-links { display: flex; align-items: center; gap: 1rem; flex-wrap: wrap; }
.tp-site-links--compact { gap: .5rem; }
.tp-site-links a {
  display: inline-flex; align-items: center; gap: .45rem;
  color: var(--tp-fg2, currentColor); text-decoration: none;
  font-size: .9rem; line-height: 1; border-radius: 6px; padding: .35rem .5rem;
  transition: color .15s ease, background-color .15s ease;
}
.tp-site-links a:hover { color: var(--tp-brand, currentColor); background: var(--tp-bg-soft, transparent); }
.tp-site-links svg { width: var(--tp-site-icon); height: var(--tp-site-icon); fill: currentColor; flex: 0 0 auto; }
.tp-site-links--full { margin-top: 2rem; padding-top: 1.25rem; border-top: 1px solid var(--tp-border, rgba(127,127,127,.25)); }
/* The header has little room, so only the icons show there. The text stays in
   the DOM for screen readers rather than being dropped. */
.tp-site-links--compact .tp-site-links__text { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); white-space: nowrap; }
@media (max-width: 720px) { .tp-site-links--compact { display: none; } }
`;

/**
 * Render SITE_LINKS as HTML.
 *
 * `compact` is the header form: icons only, text kept for screen readers.
 * Slot values are injected raw by layout.js `slot()`, so this returns markup.
 */
function siteLinksHtml({ compact }) {
  const cls = compact ? "tp-site-links tp-site-links--compact" : "tp-site-links tp-site-links--full";
  const items = SITE_LINKS.map(
    (l) =>
      `<a href="${l.href}" rel="noopener" aria-label="${l.label}" title="${l.label}">` +
      `<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">${l.icon}</svg>` +
      `<span class="tp-site-links__text">${l.text}</span></a>`,
  ).join("");
  return `<div class="${cls}">${items}</div>`;
}

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
            "wsdl-soap", "realtime-webrtc", "ai-client"],
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
  description: "One framework, four languages, 137 features, zero runtime dependencies.",
  hostname: "https://tina4.com",
  base: "/",
  cleanUrls: true,
  srcDir: "docs",
  outDir: "docs/.vitepress/dist",
  // headHtml() reads config.head (VitePress format: [tag, attrs, innerHTML]).
  // Top level, NOT themeConfig - it is not a theme option.
  head: [["style", { id: "tp-site-links" }, SITE_LINK_CSS]],
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
        { text: "Developer tools", stems: ["cli"] },
      ],
    },
    search: true,
    footer: "Simple. Fast. Human. · MIT licensed",

    // Site-wide links. Edit SITE_LINKS at the top of this file to add one.
    //
    // They render through `slots`, NOT through `footer`, and the reason is
    // structural: layout.js emits `footer` only when the page is not the home
    // layout, so anything put there is invisible on tina4.com itself - which
    // is exactly where both of these were reported missing. `headerEnd` and
    // `contentBottom` render on every page, home included.
    //
    // `socialLinks` is deliberately NOT used: tina4press has no such option,
    // so declaring one would look like a fix while changing nothing.
    slots: {
      headerEnd: siteLinksHtml({ compact: true }),
      contentBottom: siteLinksHtml({ compact: false }),
    },
  },
};
