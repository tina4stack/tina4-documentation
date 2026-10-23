#!/usr/bin/env node
// Copyright (c) 2026 Code Infinity
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// preview-site.mjs - serve the built site locally, working as it does live.
//
// `pnpm docs:preview` serves docs/.vitepress/dist, but the Ask Tina4 chat cannot
// work there: rag.tina4.com only answers pages served from https://tina4.com
// (CORS). This server fixes that for local testing only:
//
//   - it serves the build the way Apache does on tina4.com: /dir/ serves
//     dir/index.html, /dir redirects to /dir/;
//   - in every page it serves, it points the chat (the home page's data-api
//     and the docs widget's window.__TP_CHAT__.api) at itself, and it forwards
//     POST /v1/ask to the real rag.tina4.com from the server, so the answers
//     are the live service's own;
//   - it leaves the Google Analytics tag out unless you pass --analytics, so a
//     local test does not count as a real visit;
//   - it sends the live site's security headers (scripts/site-headers.mjs, the
//     same ones build-home.mjs writes into .htaccess): the home page's CSP is
//     enforced, the docs pages' is report-only. The browser console shows what
//     the policy blocks or would block.
//
// Search needs nothing: its index is a file in the build.
//
// Run after `pnpm docs:build`:
//   node scripts/preview-site.mjs            # http://localhost:4173
//   node scripts/preview-site.mjs --port 5000 --analytics   (or PORT=5000)
//
// Zero dependencies. Never used by the build or the deploy.
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { dirname, extname, join, normalize, resolve, sep } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { headersFor } from "./site-headers.mjs";

const REPO = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const config = (await import(pathToFileURL(join(REPO, "tina4press.config.mjs")).href)).default;
const DIST = resolve(REPO, config.outDir || "docs/.vitepress/dist");
const chat = (config.themeConfig && config.themeConfig.chat) || {};
const RAG = (chat.api || "https://rag.tina4.com").replace(/\/+$/, "");
const ASK_PATH = chat.askPath || "/v1/ask";

const args = process.argv.slice(2);
const portArg = args.indexOf("--port");
const PORT = portArg >= 0 ? Number(args[portArg + 1]) : Number(process.env.PORT) || 4173;
const ANALYTICS = args.includes("--analytics");
const ORIGIN = `http://localhost:${PORT}`;

const TYPES = {
  ".html": "text/html; charset=utf-8", ".css": "text/css; charset=utf-8", ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8", ".json": "application/json", ".svg": "image/svg+xml",
  ".png": "image/png", ".jpg": "image/jpeg", ".ico": "image/x-icon", ".webmanifest": "application/manifest+json",
  ".woff2": "font/woff2", ".txt": "text/plain; charset=utf-8", ".md": "text/plain; charset=utf-8",
  ".pdf": "application/pdf", ".sh": "text/plain; charset=utf-8", ".ps1": "text/plain; charset=utf-8",
};

// Point the chat at this server, and drop the analytics tag unless asked.
function adapt(html) {
  html = html.split(`data-api="${RAG}"`).join(`data-api="${ORIGIN}"`)
    .split(`"api":"${RAG}"`).join(`"api":"${ORIGIN}"`);
  if (!ANALYTICS) {
    html = html.replace(/<script async src="https:\/\/www\.googletagmanager\.com\/gtag\/js\?id=[^"]+"><\/script><script>[\s\S]*?<\/script>/g, "");
  }
  return html;
}

async function forwardAsk(req, res) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  try {
    const upstream = await fetch(RAG + ASK_PATH, {
      method: "POST", headers: { "Content-Type": "application/json" }, body: Buffer.concat(chunks),
    });
    const body = Buffer.from(await upstream.arrayBuffer());
    res.writeHead(upstream.status, { "Content-Type": upstream.headers.get("content-type") || "application/json" });
    res.end(body);
    console.log(`chat  ${upstream.status}  ${RAG + ASK_PATH}`);
  } catch (error) {
    res.writeHead(502, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: `could not reach ${RAG}: ${error.message}` }));
    console.log(`chat  502  ${error.message}`);
  }
}

async function serveFile(req, res) {
  const url = new URL(req.url, ORIGIN);
  const path = decodeURIComponent(url.pathname);
  const target = normalize(join(DIST, path));
  if (target !== DIST && !target.startsWith(DIST + sep)) { res.writeHead(403); res.end(); return; }
  let file = target, info = await stat(file).catch(() => null);
  if (info && info.isDirectory()) {
    if (!path.endsWith("/")) { res.writeHead(301, { Location: path + "/" + url.search }); res.end(); return; }
    file = join(target, "index.html"); info = await stat(file).catch(() => null);
  }
  if (!info) {
    res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    res.end(`404: ${path} is not in the build`);
    console.log(`404   ${path}`);
    return;
  }
  const type = TYPES[extname(file).toLowerCase()] || "application/octet-stream";
  let body = await readFile(file);
  if (type.startsWith("text/html")) body = adapt(body.toString("utf8"));
  res.writeHead(200, { ...headersFor(path, RAG), "Content-Type": type, "Cache-Control": "no-cache" });
  res.end(body);
}

createServer((req, res) => {
  const handler = req.method === "POST" && req.url === ASK_PATH ? forwardAsk : serveFile;
  handler(req, res).catch((error) => { res.writeHead(500); res.end(String(error)); });
}).listen(PORT, () => {
  console.log(`preview-site: ${ORIGIN}  (serving ${DIST})`);
  console.log(`  chat questions go to ${RAG + ASK_PATH}; analytics ${ANALYTICS ? "on" : "off (pass --analytics to keep it)"}`);
});
