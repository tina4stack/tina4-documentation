#!/usr/bin/env node
// Copyright (c) 2026 Code Infinity
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// build-home.mjs - build the tina4.com home page, which is NOT a tina4press page.
//
// The home page lives in home/ (index.html, home.css, home.js, assets/). This
// script runs at the end of `docs:build`, after `tina4press build`, and:
//
//   1. fills the page's header nav from the nav tina4press just rendered into
//      its own index.html (tina4press renders it from `nav` in
//      tina4press.config.mjs, so the hrefs match its clean-URL format exactly);
//   2. bakes the newest releases into the page from docs/<lang>/36-releases.md,
//      and the newest version into the hero's `tina4 serve` banner;
//   3. writes the chat endpoint from themeConfig.chat into the page, and the
//      docs pages' analytics tag (themeConfig.analytics) into its <head>;
//   4. writes dist/index.html (replacing tina4press's home), copies the page's
//      files to dist/assets/home/, and writes dist/releases/latest.json;
//   5. appends the site's security headers (scripts/site-headers.mjs) to the
//      .htaccess tina4press wrote: a strict CSP on the home page;
//   6. fails the build if a link on the page points at nothing, the page has an
//      inline script or style its CSP would block, or it carries punctuation
//      the docs ban (DESIGN.md s0, audit-truth.py).
//
// It runs after tina4press re-copies docs/public and rewrites .htaccess, so
// neither can undo it. docs/index.md stays: tina4press still builds it for the
// search index, the sitemap and the RAG corpus; only its HTML is replaced.
//
// Zero dependencies. Run it on its own after a tina4press build:
//   node scripts/build-home.mjs
import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync, statSync, copyFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { htaccessBlock } from "./site-headers.mjs";

const REPO = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const HOME = join(REPO, "home");
const LANGS = ["python", "php", "ruby", "nodejs"];
const RELEASE_COUNT = 4;
// The same characters scripts/audit-truth.py bans from the docs, plus the
// multiplication sign (DESIGN.md s0).
const BANNED = /[\u2013\u2014\u00d7\u2018\u2019\u201a\u201b\u201c\u201d\u201e\u201f\u2026\u2032\u2033]/;

const config = (await import(pathToFileURL(join(REPO, "tina4press.config.mjs")).href)).default;
const DIST = resolve(REPO, config.outDir || "docs/.vitepress/dist");
const DOCS = resolve(REPO, config.srcDir || "docs");

const warnings = [];
function fail(message) {
  console.error(`build-home: ${message}`);
  process.exit(1);
}
function esc(text) {
  return String(text).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
}
// Replace what sits between <!-- home:NAME --> and <!-- /home:NAME -->.
function fillBlock(html, name, inner) {
  const pattern = new RegExp(`(<!-- home:${name} -->)[\\s\\S]*?(\\n[ \\t]*<!-- /home:${name} -->)`);
  if (!pattern.test(html)) fail(`home/index.html has no home:${name} block`);
  return html.replace(pattern, (_, open, close) => `${open}\n${inner}${close}`);
}
function indentOf(html, name) {
  const m = html.match(new RegExp(`\\n([ \\t]*)<!-- home:${name} -->`));
  return m ? m[1] : "";
}

if (!existsSync(join(DIST, "index.html"))) fail(`no ${join(DIST, "index.html")}: run tina4press build first`);
let page = readFileSync(join(HOME, "index.html"), "utf8");

// ---- 1. header nav, from the docs header tina4press rendered ----
// Every tina4press page carries the same header. Read it from tina4press's
// index.html; on a re-run (`pnpm docs:home`) that file is already this page, so
// fall back to the first docs page that has the header.
const NAV = /<nav class="tp-nav">([\s\S]*?)<\/nav>/;
function pressPage() {
  const candidates = [join(DIST, "index.html"),
    ...readdirSync(DIST).map((name) => join(DIST, name, "index.html")).filter((p) => existsSync(p))];
  for (const file of candidates) {
    const html = readFileSync(file, "utf8");
    if (NAV.test(html)) return html;
  }
  return null;
}
const pressHtml = pressPage();
if (!pressHtml) fail("no tina4press page in the build has <nav class=\"tp-nav\">: did its header markup change?");
const navHtml = pressHtml.match(NAV)[1];
const navLinks = [...navHtml.matchAll(/<a\b[^>]*\bhref="([^"]*)"[^>]*>([\s\S]*?)<\/a>/g)]
  .map((m) => ({ href: m[1], text: m[2].trim() }));
if (!navLinks.length) fail("tina4press's header nav has no links");
{
  const pad = indentOf(page, "nav");
  page = fillBlock(page, "nav", navLinks
    .map((l) => `${pad}<a href="${l.href}"${l.href === "/" ? ' aria-current="page"' : ""}>${l.text}</a>`)
    .join("\n"));
}

// ---- 1b. analytics: the same tag as every docs page ----
// tina4press writes the Google Analytics tag from themeConfig.analytics into
// every page's <head>: the gtag.js loader plus a small inline setup script.
// Read the measurement ID from that tag, so the home page is measured the same
// way and an ID change in the config reaches it too, but load the setup from
// home/gtag-init.js: the home page's CSP allows no inline script.
{
  const configured = (config.themeConfig || {}).analytics;
  const GTAG = /<script async src="https:\/\/www\.googletagmanager\.com\/gtag\/js\?id=([A-Za-z0-9-]+)"><\/script>/;
  const id = (pressHtml.match(GTAG) || [])[1];
  if (configured && !id) fail("themeConfig.analytics is set but the docs pages carry no analytics tag: did tina4press change it?");
  if (!/<!-- home:analytics -->/.test(page)) fail("home/index.html has no <!-- home:analytics --> marker");
  page = page.replace("<!-- home:analytics -->", id
    ? `<script async src="https://www.googletagmanager.com/gtag/js?id=${id}"></script>\n` +
      `<script src="/assets/home/gtag-init.js" data-ga="${id}"></script>`
    : "");
}

// ---- 1c. search: tina4press's own, so it works exactly as on the docs pages ----
// The home page loads tina4press's client.js (and tina4-js, which it uses), so
// Ctrl/Cmd+K, the modal, the index and the results are the docs' own code. From
// a docs page this copies the three things client.js expects to find:
//   - the search modal markup (into <!-- home:search -->);
//   - its settings, window.__TP_BASE__ and __TP_I18N__ (the UI strings), as
//     press-config.js: the docs set them in an inline script, which the home
//     page's CSP forbids. __TP_CHAT__ stays out, or client.js would add its own
//     chat widget next to the page's;
//   - the modal's rules from tina4press's theme.css, as search.css (the whole
//     theme.css would restyle the page). home.css maps their colour variables.
let searchCss = "", pressConfig = "";
{
  const at = pressHtml.indexOf('<div class="tp-search-modal"');
  if (at < 0) fail("the docs pages carry no tina4press search modal: did tina4press change it?");
  let depth = 0, end = at;
  for (const m of pressHtml.slice(at).matchAll(/<div\b|<\/div>/g)) {
    depth += m[0] === "</div>" ? -1 : 1;
    if (depth === 0) { end = at + m.index + m[0].length; break; }
  }
  if (end === at) fail("could not find the end of tina4press's search modal");
  if (!/<!-- home:search -->/.test(page)) fail("home/index.html has no <!-- home:search --> marker");
  page = page.replace("<!-- home:search -->", pressHtml.slice(at, end));
  if (!/id="tp-search-open"/.test(page)) fail("home/index.html has no #tp-search-open button for client.js to wire");

  const base = (pressHtml.match(/window\.__TP_BASE__=("[^"]*");/) || [])[1];
  const i18n = (pressHtml.match(/window\.__TP_I18N__=(\{.*?\});/) || [])[1];
  if (!base || !i18n) fail("the docs pages do not set window.__TP_BASE__ / __TP_I18N__: did tina4press change them?");
  JSON.parse(i18n);   // fail loudly on a shape change rather than ship a broken script
  pressConfig = "/* tina4press's settings for its client.js, copied from a docs page by\n" +
    "   scripts/build-home.mjs (the docs set them inline; the home page's CSP forbids that) */\n" +
    `window.__TP_BASE__=${base};\nwindow.__TP_I18N__=${i18n};\n`;

  // Top-level rules of theme.css whose selectors belong to the modal (not the
  // docs header's search button, not @media blocks).
  const theme = readFileSync(join(DIST, "assets", "theme.css"), "utf8").replace(/\/\*[\s\S]*?\*\//g, "");
  const SEARCH = /tp-search-(modal|box|results|foot|empty)|#tp-search-input|\.tp-sr\b/;
  const rules = [];
  for (let i = 0, depth = 0, start = 0; i < theme.length; i++) {
    if (theme[i] === "{") depth++;
    else if (theme[i] === "}" && --depth === 0) {
      const rule = theme.slice(start, i + 1).trim(); start = i + 1;
      if (rule.startsWith("@")) continue;
      const brace = rule.indexOf("{");
      const selectors = rule.slice(0, brace).split(",").map((s) => s.trim()).filter((s) => SEARCH.test(s));
      if (selectors.length) rules.push(selectors.join(", ") + " " + rule.slice(brace));
    }
  }
  if (rules.length < 8) fail(`found only ${rules.length} search rules in tina4press's theme.css: did its markup change?`);
  searchCss = "/* tina4press's search modal rules, copied from its theme.css by scripts/build-home.mjs */\n" +
    rules.join("\n") + "\n";
}

// ---- 2. releases, from our own release notes ----
const HEADING = /^## v(\d+\.\d+\.\d+) \((\d{4}-\d{2}-\d{2})\) - (.+?)\s*$/gm;
function readNotes(lang) {
  const file = join(DOCS, lang, "36-releases.md");
  if (!existsSync(file)) return [];
  return [...readFileSync(file, "utf8").matchAll(HEADING)].map((m) => ({ version: m[1], date: m[2], headline: m[3] }));
}
// Each release's anchor in each language's built notes. tina4press slugs the
// whole heading, and each language words its headline its own way, so read the
// ids it actually wrote rather than guess them.
function anchorsFor(lang) {
  const file = join(DIST, lang, "36-releases", "index.html");
  if (!existsSync(file)) return [];
  return [...readFileSync(file, "utf8").matchAll(/<h2 id="(v\d+-[^"]*)"/g)].map((m) => m[1]);
}
function anchorOf(anchors, version) {
  const prefix = `v${version.replace(/\./g, "")}-`;
  return anchors.find((id) => id.startsWith(prefix)) || null;
}
// The four languages word some headlines differently (Python adds its
// Python-only change). Take the wording most languages share; Python on a tie.
function sharedHeadline(version, notesByLang) {
  const counts = new Map();
  for (const lang of LANGS) {
    const hit = notesByLang[lang].find((r) => r.version === version);
    if (hit) counts.set(hit.headline, (counts.get(hit.headline) || 0) + 1);
  }
  const python = (notesByLang.python.find((r) => r.version === version) || {}).headline;
  let best = python, bestCount = python ? counts.get(python) : 0;
  for (const [headline, count] of counts) if (count > bestCount) { best = headline; bestCount = count; }
  return best;
}
// Headline markdown is plain text plus the odd `code` span.
function headlineHtml(text) {
  return esc(text).replace(/`([^`]+)`/g, "<code>$1</code>");
}
function headlinePlain(text) {
  return text.replace(/`([^`]+)`/g, "$1");
}

const notesByLang = Object.fromEntries(LANGS.map((lang) => [lang, readNotes(lang)]));
const releases = notesByLang.python.slice(0, RELEASE_COUNT).map((r) => ({
  version: `v${r.version}`, date: r.date, headline: sharedHeadline(r.version, notesByLang),
  anchors: Object.fromEntries(LANGS.map((lang) => [lang, anchorOf(anchorsFor(lang), r.version)])),
}));

if (releases.length) {
  const pad = indentOf(page, "releases");
  const newest = releases[0];
  const notesAttrs = LANGS.map((lang) => ` data-${lang}="/${lang}/36-releases/"`).join("");
  const rows = releases.map((r) => {
    const attrs = LANGS.map((lang) =>
      ` data-${lang}="/${lang}/36-releases/${r.anchors[lang] ? `#${r.anchors[lang]}` : ""}"`).join("");
    const href = `/python/36-releases/${r.anchors.python ? `#${r.anchors.python}` : ""}`;
    return `${pad}    <li><a class="rel-link" href="${href}"${attrs}><code>${r.version}</code>` +
      `<span class="rel-date">${r.date}</span><span class="rel-h">${headlineHtml(r.headline)}</span></a></li>`;
  });
  page = fillBlock(page, "releases", [
    `${pad}<div class="shipped-ver"><code>${newest.version}</code><span>${newest.date}</span></div>`,
    `${pad}<div>`,
    `${pad}  <h2 id="shipped-h" class="shipped-h">Recent releases</h2>`,
    `${pad}  <ol class="shipped-list">`,
    ...rows,
    `${pad}  </ol>`,
    `${pad}  <p class="shipped-foot">Across all four frameworks. <a class="rel-notes" href="/python/36-releases/"${notesAttrs}>` +
      `Release notes <svg class="i" aria-hidden="true"><use href="#i-arrow-right"/></svg></a></p>`,
    `${pad}</div>`,
  ].join("\n"));
  // the hero's `tina4 serve` banner prints the newest version
  if (!/data-version="[^"]*"/.test(page)) fail("home/index.html: the boot element has no data-version attribute");
  page = page.replace(/(id="boot"[^>]*\bdata-version=")[^"]*"/, `$1${newest.version}"`);
} else {
  warnings.push("no release headings found in docs/python/36-releases.md: kept the page's last-known releases");
}

// ---- 3. the chat endpoint, from themeConfig.chat ----
const chat = (config.themeConfig && config.themeConfig.chat) || {};
if (chat.api) {
  page = page.replace(/(<div class="tp-chat"[^>]*\bdata-api=")[^"]*"/, `$1${esc(chat.api)}"`);
  page = page.replace(/(<div class="tp-chat"[^>]*\bdata-ask-path=")[^"]*"/, `$1${esc(chat.askPath || "/v1/ask")}"`);
} else {
  warnings.push("themeConfig.chat.api is not set: the page keeps its own chat endpoint");
}

// ---- 4. write the page, its files and the releases endpoint ----
function copyTree(from, to) {
  mkdirSync(to, { recursive: true });
  for (const name of readdirSync(from)) {
    const source = join(from, name), target = join(to, name);
    if (statSync(source).isDirectory()) copyTree(source, target);
    else copyFileSync(source, target);
  }
}
// The page's own CSS and scripts (home/*.css, home/*.js) keep fixed names, so
// stamp each link with a hash of the file: a deploy that changes them is
// fetched fresh instead of from cache. Each one must be loaded by the page.
const OWN_FILES = readdirSync(HOME).filter((name) => /\.(css|js)$/.test(name));
for (const name of OWN_FILES) {
  const hash = createHash("sha256").update(readFileSync(join(HOME, name))).digest("hex").slice(0, 10);
  const pattern = new RegExp(`"/assets/home/${name.replace(/\./g, "\\.")}(\\?v=[^"]*)?"`);
  if (!pattern.test(page)) {
    if (name === "gtag-init.js" && !/gtag-init/.test(page)) continue;   // analytics is off
    fail(`home/index.html does not load /assets/home/${name}`);
  }
  page = page.replace(pattern, `"/assets/home/${name}?v=${hash}"`);
}
// ...and the two files this build generates for the search (step 1c).
const GENERATED = { "press-config.js": pressConfig, "search.css": searchCss };
for (const [name, body] of Object.entries(GENERATED)) {
  const hash = createHash("sha256").update(body).digest("hex").slice(0, 10);
  const pattern = new RegExp(`"/assets/home/${name.replace(/\./g, "\\.")}(\\?v=[^"]*)?"`);
  if (!pattern.test(page)) fail(`home/index.html does not load /assets/home/${name}`);
  page = page.replace(pattern, `"/assets/home/${name}?v=${hash}"`);
}
const ASSET_OUT = join(DIST, "assets", "home");
copyTree(join(HOME, "assets"), ASSET_OUT);
for (const name of OWN_FILES) copyFileSync(join(HOME, name), join(ASSET_OUT, name));
for (const [name, body] of Object.entries(GENERATED)) writeFileSync(join(ASSET_OUT, name), body);
writeFileSync(join(DIST, "index.html"), page);

// Security headers for the whole site (scripts/site-headers.mjs), appended to
// the .htaccess tina4press just wrote. tina4press rewrites that file on every
// build, so the block is added fresh each time (and replaced on a re-run).
{
  const htaccess = join(DIST, ".htaccess");
  if (!existsSync(htaccess)) fail(`no ${htaccess}: tina4press writes it on every build`);
  const MARK = "\n# Security headers (scripts/site-headers.mjs";
  const current = readFileSync(htaccess, "utf8");
  const base = current.includes(MARK) ? current.slice(0, current.indexOf(MARK)) : current.replace(/\n*$/, "\n");
  writeFileSync(htaccess, base + htaccessBlock(chat.api || "https://rag.tina4.com").replace(/^\n/, "\n"));
}

if (releases.length) {
  const list = releases.map((r) => ({ version: r.version, date: r.date, headline: headlinePlain(r.headline) }));
  mkdirSync(join(DIST, "releases"), { recursive: true });
  writeFileSync(join(DIST, "releases", "latest.json"),
    JSON.stringify({ ...list[0], releases: list }, null, 2) + "\n");
}

// ---- 5. checks: every link resolves, no banned punctuation ----
function resolvesToFile(url) {
  const path = decodeURIComponent(url.split("#")[0].split("?")[0]).replace(/^\/+/, "");
  const target = join(DIST, path);
  if (path === "" || path.endsWith("/")) return existsSync(join(target, "index.html"));
  if (existsSync(target) && statSync(target).isFile()) return true;
  return existsSync(join(target, "index.html"));
}
const refs = [...page.matchAll(/\s(?:href|src)="(\/(?!\/)[^"]*)"/g)].map((m) => m[1]);
const assetRefs = [...readFileSync(join(HOME, "home.js"), "utf8").matchAll(/ASSET \+ "([^"]+)"/g)]
  .map((m) => `/assets/home/${m[1]}`);
const dead = [...new Set([...refs, ...assetRefs])].filter((url) => !resolvesToFile(url));
if (dead.length) fail(`dead link(s) on the home page:\n  ${dead.join("\n  ")}`);
// No inline script, no inline style, no event-handler attribute: the page's
// CSP (scripts/site-headers.mjs) would block them on tina4.com.
{
  const inlineScript = [...page.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/g)].find((m) => !/\ssrc=/.test(m[1]) && m[2].trim());
  const inlineStyle = page.match(/<style\b/) || page.match(/<[a-zA-Z][^>]*\sstyle="/);
  const handler = page.match(/<[a-zA-Z][^>]*\son[a-z]+="/);
  for (const [what, hit] of [["an inline <script>", inlineScript], ["an inline style", inlineStyle], ["an event-handler attribute", handler]]) {
    if (hit) fail(`home/index.html has ${what} (line ${page.slice(0, hit.index).split("\n").length}); the home page's CSP blocks it: move it to a file or a class`);
  }
  const svg = readFileSync(join(HOME, "assets", "tina4-robot.svg"), "utf8");
  if (/\sstyle="/.test(svg)) fail("home/assets/tina4-robot.svg has a style attribute; the page inlines the rig, so the CSP would drop it (regenerate it with tools/build-robot-rig.js)");
}
for (const [name, text] of [["index.html", page],
  ...OWN_FILES.map((file) => [file, readFileSync(join(HOME, file), "utf8")])]) {
  const hit = text.match(BANNED);
  if (hit) {
    const line = text.slice(0, hit.index).split("\n").length;
    fail(`home/${name}:${line} has a banned character (U+${hit[0].codePointAt(0).toString(16).toUpperCase().padStart(4, "0")}); use ASCII`);
  }
}

for (const w of warnings) console.warn(`build-home: warning: ${w}`);
console.log(`build-home: wrote index.html (${navLinks.length} nav links, ${releases.length} releases` +
  `${releases.length ? `, newest ${releases[0].version}` : ""}), assets/home/, releases/latest.json; ${refs.length} links checked`);
