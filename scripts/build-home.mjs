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
//   3. writes the chat endpoint from themeConfig.chat into the page;
//   4. writes dist/index.html (replacing tina4press's home), copies the page's
//      files to dist/assets/home/, and writes dist/releases/latest.json;
//   5. fails the build if a link on the page points at nothing, or the page
//      carries punctuation the docs ban (DESIGN.md s0, audit-truth.py).
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
function pressNav() {
  const candidates = [join(DIST, "index.html"),
    ...readdirSync(DIST).map((name) => join(DIST, name, "index.html")).filter((p) => existsSync(p))];
  for (const file of candidates) {
    const m = readFileSync(file, "utf8").match(NAV);
    if (m) return m[1];
  }
  return null;
}
const navHtml = pressNav();
if (!navHtml) fail("no tina4press page in the build has <nav class=\"tp-nav\">: did its header markup change?");
const navLinks = [...navHtml.matchAll(/<a\b[^>]*\bhref="([^"]*)"[^>]*>([\s\S]*?)<\/a>/g)]
  .map((m) => ({ href: m[1], text: m[2].trim() }));
if (!navLinks.length) fail("tina4press's header nav has no links");
{
  const pad = indentOf(page, "nav");
  page = fillBlock(page, "nav", navLinks
    .map((l) => `${pad}<a href="${l.href}"${l.href === "/" ? ' aria-current="page"' : ""}>${l.text}</a>`)
    .join("\n"));
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
// home.css and home.js keep fixed names, so stamp each link with a hash of the
// file: a deploy that changes them is fetched fresh instead of from cache.
for (const name of ["home.css", "home.js"]) {
  const hash = createHash("sha256").update(readFileSync(join(HOME, name))).digest("hex").slice(0, 10);
  const pattern = new RegExp(`"/assets/home/${name.replace(".", "\\.")}(\\?v=[^"]*)?"`);
  if (!pattern.test(page)) fail(`home/index.html does not load /assets/home/${name}`);
  page = page.replace(pattern, `"/assets/home/${name}?v=${hash}"`);
}
const ASSET_OUT = join(DIST, "assets", "home");
copyTree(join(HOME, "assets"), ASSET_OUT);
copyFileSync(join(HOME, "home.css"), join(ASSET_OUT, "home.css"));
copyFileSync(join(HOME, "home.js"), join(ASSET_OUT, "home.js"));
writeFileSync(join(DIST, "index.html"), page);

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
for (const [name, text] of [["index.html", page], ["home.css", readFileSync(join(HOME, "home.css"), "utf8")],
  ["home.js", readFileSync(join(HOME, "home.js"), "utf8")]]) {
  const hit = text.match(BANNED);
  if (hit) {
    const line = text.slice(0, hit.index).split("\n").length;
    fail(`home/${name}:${line} has a banned character (U+${hit[0].codePointAt(0).toString(16).toUpperCase().padStart(4, "0")}); use ASCII`);
  }
}

for (const w of warnings) console.warn(`build-home: warning: ${w}`);
console.log(`build-home: wrote index.html (${navLinks.length} nav links, ${releases.length} releases` +
  `${releases.length ? `, newest ${releases[0].version}` : ""}), assets/home/, releases/latest.json; ${refs.length} links checked`);
