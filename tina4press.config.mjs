/*
 * Copyright (c) 2026 Code Infinity
 * SPDX-License-Identifier: MPL-2.0
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */
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
    text: "Discord",
    href: "https://discord.gg/vEXqaNcZm",
    label: "Join the Tina4 community on Discord",
    // The Discord wordmark glyph, drawn on the shared 24x24 viewBox.
    icon: `<path d="M20.317 4.3698a19.7913 19.7913 0 00-4.8851-1.5152.0741.0741 0 00-.0785.0371c-.211.3753-.4447.8648-.6083 1.2495-1.8447-.2762-3.68-.2762-5.4868 0-.1636-.3933-.4058-.8742-.6177-1.2495a.077.077 0 00-.0785-.037 19.7363 19.7363 0 00-4.8852 1.515.0699.0699 0 00-.0321.0277C.5334 9.0458-.319 13.5799.0992 18.0578a.0824.0824 0 00.0312.0561c2.0528 1.5076 4.0413 2.4228 5.9929 3.0294a.0777.0777 0 00.0842-.0276c.4616-.6304.8731-1.2952 1.226-1.9942a.076.076 0 00-.0416-.1057c-.6528-.2476-1.2743-.5495-1.8722-.8923a.077.077 0 01-.0076-.1277c.1258-.0943.2517-.1923.3718-.2914a.0743.0743 0 01.0776-.0105c3.9278 1.7933 8.18 1.7933 12.0614 0a.0739.0739 0 01.0785.0095c.1202.099.246.1981.3728.2924a.077.077 0 01-.0066.1276 12.2986 12.2986 0 01-1.873.8914.0766.0766 0 00-.0407.1067c.3604.698.7719 1.3628 1.225 1.9932a.076.076 0 00.0842.0286c1.961-.6067 3.9495-1.5219 6.0023-3.0294a.077.077 0 00.0313-.0552c.5004-5.177-.8382-9.6739-3.5485-13.6604a.061.061 0 00-.0312-.0286zM8.02 15.3312c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9555-2.4189 2.157-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.9555 2.4189-2.1569 2.4189zm7.9748 0c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9554-2.4189 2.1569-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.946 2.4189-2.1568 2.4189Z"/>`,
  },
  {
    text: "Code Infinity",
    href: "https://codeinfinity.co.za",
    label: "Code Infinity, the team behind Tina4",
    // The infinity mark from the Code Infinity logo (the loop path of
    // home/assets/c8e-logo-blue.svg), scaled onto the shared 24x24 viewBox:
    // it spans the full width, centred vertically.
    icon: `<g transform="matrix(0.15094 0 0 0.15094 -9.660 5.208)"><path d="M184.34 89.29C165.16 92.33 145 76.42 133.52 65.26C126.91 57.1 120.5 51.39 120.5 51.39C114.38 45.43 103.83 37.15 95.66 38.45C86.59 39.89 80.38 48.44 81.83 57.49C83.26 66.54 91.82 72.74 100.89 71.3C107.72 70.22 113.88 62.65 118.03 55.81C122.39 60.28 126.63 64.87 130.74 69.56C124.73 78.19 115.73 87.26 103.74 89.16C84.8 92.17 66.94 79.23 63.94 60.33C60.93 41.43 73.88 23.6 92.82 20.59C107.03 18.34 120.61 27.27 129.21 34.78C129.21 34.78 135.68 41.07 142.23 48.34C152.87 59.64 170.04 73.26 181.51 71.44C196.15 69.12 206.17 55.34 203.84 40.72C201.51 26.09 187.71 16.1 173.06 18.42C162.26 20.14 151.51 33.51 144.92 43.89C140.03 38.71 135.56 34.11 131.99 30.5C140.19 18.38 153.55 3.21 170.22 0.56C172.62 0.18 175 0 177.34 0C199.07 0 218.25 15.8 221.77 37.88C225.67 62.35 208.89 85.42 184.37 89.3H184.35L184.34 89.29Z"/></g>`,
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
            "database", "orm", "query-builder", "graph-databases",
            "authentication", "sessions-cookies", "middleware-security"],
  },
  {
    text: "Building Apps",
    stems: ["caching", "queues", "events", "localization", "logging",
            "email", "frontend", "testing", "scaffolding"],
  },
  {
    text: "APIs & Protocols",
    stems: ["swagger", "api-client", "graphql", "websocket", "sse",
            "wsdl-soap", "realtime-webrtc", "ai-client", "sso", "gis",
            "web-push",
            "iot-mqtt"],
  },
  {
    text: "Advanced",
    stems: ["di-container", "service-runner"],
  },
  {
    // MCP earns its own heading rather than hiding under "Advanced": readers
    // look for "MCP" by name (both using the built-in dev-tools server and
    // building their own), and a generic group buried the two chapters.
    text: "MCP",
    stems: ["mcp-dev-tools", "custom-mcp-servers"],
  },
  { text: "Developer Tools", stems: ["dev-tools", "cli", "vibe-coding-with-ai"] },
  { text: "Operations", stems: ["environment-variables", "deployment", "complete-app"] },
  { text: "Releases", stems: ["releases"] },
  { text: "Reference", stems: ["upgrading-from-v2", "feature-list"] },
];

// Open Graph and Twitter card tags, so a shared tina4.com link unfurls with the
// Tina4 robot instead of a blank box. These are SITE-WIDE: the image and the
// card type apply to every page. og:title and og:description are deliberately
// left out here so each page's own <title> and <meta name="description"> stand
// in - Slack and X fall back to them - which keeps the per-page title in the
// unfurl rather than flattening all pages to one. A served tina4press release
// can later make og:title/og:url per-page; this is the zero-dependency version.
// Inter and Inconsolata, self-hosted in docs/public/fonts and shared with the
// home page (home/), so the whole site loads one set of font files. fonts.css
// declares them; themeConfig.fonts below puts them first in tina4press's font
// stacks. The two upright files are preloaded, as the home page does.
const FONT_HEAD = [
  ["link", { rel: "stylesheet", href: "/fonts/fonts.css" }],
  ["link", { rel: "preload", href: "/fonts/inter-latin-wght-normal.woff2", as: "font", type: "font/woff2", crossorigin: "anonymous" }],
  ["link", { rel: "preload", href: "/fonts/inconsolata-latin-wght-normal.woff2", as: "font", type: "font/woff2", crossorigin: "anonymous" }],
];

const OG_IMAGE = "https://tina4.com/og-image.png";
const OG_META = [
  ["meta", { property: "og:type", content: "website" }],
  ["meta", { property: "og:site_name", content: "Tina4" }],
  ["meta", { property: "og:image", content: OG_IMAGE }],
  ["meta", { property: "og:image:width", content: "1200" }],
  ["meta", { property: "og:image:height", content: "630" }],
  ["meta", { property: "og:image:alt", content: "The Tina4 robot" }],
  ["meta", { name: "twitter:card", content: "summary_large_image" }],
  ["meta", { name: "twitter:image", content: OG_IMAGE }],
];

export default {
  title: "Tina4",
  description: "One framework, four languages, 140 features, zero runtime dependencies.",
  hostname: "https://tina4.com",
  base: "/",
  cleanUrls: true,
  srcDir: "docs",
  outDir: "docs/.vitepress/dist",
  // headHtml() reads config.head (VitePress format: [tag, attrs, innerHTML]).
  // Top level, NOT themeConfig - it is not a theme option.
  head: [["style", { id: "tp-site-links" }, SITE_LINK_CSS], ...FONT_HEAD, ...OG_META],
  themeConfig: {
    analytics: "G-FZRRSBE9M0",
    // The header, matched to the home page (one collapse point, nav on one line).
    customCss: ["theme/docs-header.css"],
    // Inter and Inconsolata only (DESIGN.md s0), from FONT_HEAD above.
    fonts: {
      body: '"Inter", system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
      mono: '"Inconsolata", ui-monospace, Menlo, Consolas, monospace',
    },
    // All theme colors as constants — tweak these to retheme the whole site.
    colors: {
      light: { brand: "#2f5fe0", brand2: "#4888ff" },
      // The cool slate of the home page (DESIGN.md s4), so the shared theme
      // toggle does not jump between two darks.
      dark: {
        brand: "#8db4ff", brand2: "#6b9bff",
        bg: "#262335", bgSoft: "#2f2c3f", bgMute: "#38344a",
        border: "#3b3650", border2: "#4a4560",
        fg: "#efecf6", fg2: "#b9b3cb", fg3: "#9a94b2",
        codeBg: "#1e1b2b", sel: "#3d4470",
      },
    },
    logo: "/logo.svg",
    nav: [
      { text: "Home", link: "index.html" },
      { text: "Introduction", link: "general/01-what-is-tina4.html" },
      { text: "Build with AI", link: "build-with-ai.html" },
      { text: "tina4-js", link: "js/index.html" },
      { text: "Python", link: "python/index.html" },
      { text: "Node.js", link: "nodejs/index.html" },
      { text: "PHP", link: "php/index.html" },
      { text: "Ruby", link: "ruby/index.html" },
      { text: "Code Viewer", link: "/download/code-viewer/" },
    ],
    sidebar: null, // auto, section-scoped; grouped below (ported from SECTION_GROUPS)
    sectionLabels: { js: "tina4-js", python: "Python", nodejs: "Node.js", php: "PHP", ruby: "Ruby", general: "Understanding Tina4", v2: "v2 Docs" },
    // Built-in RAG chat ("Ask Tina4") — floating widget, hits the hosted RAG.
    chat: { api: "https://rag.tina4.com", label: "Ask Tina4", model: "Powered by Tina4", placeholder: "How do I define a route?" },
    // The home page (home/, scripts/build-home.mjs) reads chat.api too, and
    // reuses these strings for its search. tina4press's defaults carry an em
    // dash and the ellipsis character; the docs ban both.
    messages: {
      chatError: "Sorry, the assistant is unreachable right now.",
      chatPlaceholder: "Ask a question...",
      searchPlaceholder: "Search the docs...",
      searchEmpty: "Type to search the docs...",
    },
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
      // Four conceptual pages that were all landing under "Foundations".
      general: [
        {
          text: "Understanding Tina4",
          stems: ["what-is-tina4", "architecture", "choosing-your-language", "environment-variables"],
        },
        { text: "Developer tools", stems: ["cli"] },
        { text: "Project policies", stems: ["contributing", "releasing", "security-research", "contributor-licence-agreement"] },
      ],
    },
    search: true,
    footer: "Simple. Fast. Human. · MPL-2.0 · Copyright Code Infinity",

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
