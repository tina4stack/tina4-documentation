#!/usr/bin/env node
// Copyright (c) 2026 Code Infinity
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// gen-md-companions.mjs - publish every docs page as clean markdown, the
// llmstxt.org convention: a page's markdown lives at its source path.
//
//   docs/python/36-releases.md -> https://tina4.com/python/36-releases.md
//   docs/python/index.md       -> https://tina4.com/python/index.md
//   docs/index.md              -> https://tina4.com/index.md
//
// It runs in `docs:build` after `tina4press build` and before build-home.mjs:
//
//   1. walks docs/ exactly as tina4press does (skips public/, node_modules and
//      dot-folders) and writes each page into the built site at its source
//      path, frontmatter stripped. A page whose body has no H1 gets one from
//      its frontmatter title, or from the <title> tina4press rendered;
//   2. adds <link rel="alternate" type="text/markdown" href="..."> to the head
//      of the page's HTML, so an agent on any page can find its markdown.
//      (rel="describedby" -> /llms.txt is site-wide: `head` in
//      tina4press.config.mjs, and home/index.html for the home page.);
//   3. writes a small mod_mime block into the .htaccess tina4press generated,
//      ahead of the security headers build-home.mjs appends, so .md is served
//      as UTF-8 text/markdown.
//
// It fails the build when a page has no HTML to link from, or when a
// companion would land on a file published from docs/public.
//
// Zero dependencies. Run it on its own after a tina4press build:
//   node scripts/gen-md-companions.mjs
import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync, statSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const REPO = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const { default: config } = await import(pathToFileURL(join(REPO, "tina4press.config.mjs")).href);
const DOCS = resolve(REPO, config.srcDir || "docs");
const DIST = resolve(REPO, config.outDir || "docs/.vitepress/dist");
const BASE = (config.base || "/").replace(/\/*$/, "/");
const CLEAN = !!config.cleanUrls;

function fail(message) {
  console.error(`gen-md-companions: ${message}`);
  process.exit(1);
}

// The same walk as tina4press's build.js, so the companions are exactly the
// pages it built.
function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    if (name === "public" || name === "node_modules" || name.startsWith(".")) continue;
    const path = join(dir, name);
    if (statSync(path).isDirectory()) walk(path, out);
    else if (name.endsWith(".md")) out.push(path);
  }
  return out;
}

// Where tina4press wrote a page's HTML (its outFileFor()).
function htmlFileFor(rel) {
  const noExt = rel.replace(/\.md$/, "");
  if (!CLEAN) return noExt + ".html";
  if (noExt === "index") return "index.html";
  if (noExt.endsWith("/index")) return noExt + ".html";
  return noExt + "/index.html";
}

const FRONTMATTER = /^\uFEFF?---\r?\n([\s\S]*?)\r?\n---\r?\n?/;
function unquote(value) {
  const v = value.trim();
  return /^(["']).*\1$/.test(v) ? v.slice(1, -1) : v;
}
function decodeEntities(text) {
  return text.replace(/&(amp|lt|gt|quot|#39);/g, (_, e) => ({ amp: "&", lt: "<", gt: ">", quot: '"', "#39": "'" })[e]);
}

// A title for a page whose body has no H1: its frontmatter title, else a home
// layout's hero name and text, else the <title> tina4press rendered, without
// the " - Site" suffix it appends.
function titleOf(frontmatter, html) {
  const field = (pattern) => unquote((frontmatter.match(pattern) || [])[1] || "");
  const title = field(/^title:\s*(.+)$/m);
  if (title) return title;
  const hero = [field(/^\s+name:\s*(.+)$/m), field(/^\s+text:\s*(.+)$/m)].filter(Boolean).join(" ");
  if (/^hero:/m.test(frontmatter) && hero) return hero;
  const rendered = decodeEntities((html.match(/<title>([\s\S]*?)<\/title>/) || [])[1] || "").trim();
  const suffix = rendered.lastIndexOf(` · ${config.title}`);
  return suffix > 0 ? rendered.slice(0, suffix) : rendered;
}

function companionOf(source, html) {
  const fm = source.match(FRONTMATTER);
  let body = (fm ? source.slice(fm[0].length) : source).replace(/^\s*\n/, "");
  body = body.replace(/\s*$/, "\n");
  if (!/^#\s+\S/.test(body)) {
    const title = titleOf(fm ? fm[1] : "", html);
    if (title) body = `# ${title}\n\n${body}`;
  }
  return body;
}

const ALTERNATE = /<link\b[^>]*\btype="text\/markdown"/;
const pages = existsSync(DOCS) ? walk(DOCS) : [];
if (!pages.length) fail(`no markdown pages under ${DOCS}`);
if (!existsSync(DIST)) fail(`no ${DIST}: run tina4press build first`);

let linked = 0;
for (const abs of pages) {
  const rel = relative(DOCS, abs).replace(/\\/g, "/");
  const htmlFile = join(DIST, htmlFileFor(rel));
  let html;
  try {
    html = readFileSync(htmlFile, "utf8");
  } catch (error) {
    if (error.code === "ENOENT") fail(`${rel} has no built page at ${relative(REPO, htmlFile)}: did tina4press change its output layout?`);
    throw error;
  }

  const target = join(DIST, rel);
  const body = companionOf(readFileSync(abs, "utf8"), html);
  // tina4press copies docs/public over the site root: a file there at the same
  // path would be served instead of the page. Never overwrite it.
  if (existsSync(join(DOCS, "public", rel))) {
    fail(`${rel}: docs/public/${rel} is published at the same URL as this page's markdown; rename one of them`);
  }
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, body);

  if (!ALTERNATE.test(html)) {
    if (!html.includes("</head>")) fail(`${relative(REPO, htmlFile)} has no </head>`);
    const link = `<link rel="alternate" type="text/markdown" href="${BASE}${rel}">`;
    writeFileSync(htmlFile, html.replace("</head>", `${link}\n</head>`));
    linked++;
  }
}

// mod_mime: Apache would send .md without a charset. Put the block ahead of the
// security headers (build-home.mjs cuts the file at its own marker on a re-run,
// so anything after that marker would be lost).
{
  const htaccess = join(DIST, ".htaccess");
  let current;
  try {
    current = readFileSync(htaccess, "utf8");
  } catch (error) {
    if (error.code === "ENOENT") fail(`no ${htaccess}: tina4press writes it on every build`);
    throw error;
  }
  const OPEN = "# Markdown companions (scripts/gen-md-companions.mjs).";
  const CLOSE = "# /Markdown companions";
  const block = [
    OPEN,
    "<IfModule mod_mime.c>",
    "  AddType text/markdown .md",
    "  AddCharset utf-8 .md",
    "</IfModule>",
    CLOSE,
    "",
  ].join("\n");
  const old = new RegExp(`\\n?${OPEN.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}[\\s\\S]*?${CLOSE}\\n?`);
  let text = current.replace(old, "\n");
  const SECURITY = "\n# Security headers (scripts/site-headers.mjs";
  const at = text.indexOf(SECURITY);
  text = at < 0
    ? text.replace(/\n*$/, "\n\n") + block
    : text.slice(0, at).replace(/\n*$/, "\n\n") + block + text.slice(at);
  writeFileSync(htaccess, text);
}

console.log(`gen-md-companions: wrote ${pages.length} markdown companions, linked ${linked} page(s) to theirs`);
