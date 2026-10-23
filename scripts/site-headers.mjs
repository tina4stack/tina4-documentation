// Copyright (c) 2026 Code Infinity
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// site-headers.mjs - the security headers tina4.com sends, in one place.
//
// build-home.mjs writes them into the .htaccess tina4press generates (Apache
// serves tina4.com), and preview-site.mjs sends the same ones locally, so a
// local test sees exactly what the live site will enforce.
//
//   every response:  HSTS, X-Content-Type-Options, Referrer-Policy
//   the home page:   an enforced Content Security Policy (CSP)
//   docs pages:      the same CSP in report-only mode. tina4press writes inline
//                    scripts and styles into every page, so enforcing it there
//                    would break the docs; report-only lists what is left in the
//                    browser console until tina4press stops doing that.
//
// The CSP allows this site, the Google Analytics hosts (themeConfig.analytics
// loads on every page) and the chat's RAG (themeConfig.chat.api). No inline
// script, no inline style, no plugins, no framing by other sites.

export function contentSecurityPolicy(ragOrigin) {
  // GA4 beacons go to analytics.google.com, region-1.analytics.google.com,
  // www.google.com/g/collect and stats.g.doubleclick.net (seen in the browser).
  const ga = ["https://*.google-analytics.com", "https://analytics.google.com", "https://*.analytics.google.com",
    "https://*.googletagmanager.com", "https://*.g.doubleclick.net", "https://*.google.com"];
  return [
    "default-src 'self'",
    "script-src 'self' https://www.googletagmanager.com",
    "style-src 'self'",
    // GA's audience pixel comes from the visitor's own country domain
    // (www.google.co.za, www.google.de, ...): allow images from any HTTPS host.
    "img-src 'self' data: https:",
    `connect-src 'self' ${ragOrigin} ${ga.join(" ")}`,
    "font-src 'self'",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'self'",
  ].join("; ");
}

// Sent on every response. HSTS covers tina4.com only (no includeSubDomains):
// not every subdomain has been checked for HTTPS.
export const COMMON_HEADERS = {
  "Strict-Transport-Security": "max-age=31536000",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "strict-origin-when-cross-origin",
};

const HOME_PATH = /^\/(index\.html)?$/;

// The headers for one request path, as the preview server sends them.
export function headersFor(urlPath, ragOrigin) {
  const csp = contentSecurityPolicy(ragOrigin);
  return {
    ...COMMON_HEADERS,
    [HOME_PATH.test(urlPath) ? "Content-Security-Policy" : "Content-Security-Policy-Report-Only"]: csp,
  };
}

// The same, as an Apache block for .htaccess. Wrapped in <IfModule>, so a
// server without mod_headers ignores it instead of failing every request.
export function htaccessBlock(ragOrigin) {
  const csp = contentSecurityPolicy(ragOrigin);
  return [
    "",
    "# Security headers (scripts/site-headers.mjs, written by scripts/build-home.mjs).",
    "<IfModule mod_headers.c>",
    ...Object.entries(COMMON_HEADERS).map(([name, value]) => `  Header always set ${name} "${value}"`),
    `  <If "%{REQUEST_URI} =~ m#${HOME_PATH.source}#">`,
    `    Header always set Content-Security-Policy "${csp}"`,
    "  </If>",
    "  <Else>",
    `    Header always set Content-Security-Policy-Report-Only "${csp}"`,
    "  </Else>",
    "</IfModule>",
    "",
  ].join("\n");
}
