---
name: tina4-seo
description: Use when a project needs SEO and AISO (AI Search Optimisation) coverage — structured data, AI discovery files, robots.txt, sitemap, meta tags, semantic HTML audit, E-E-A-T signals, favicon package, and entity consistency. Works on any Tina4 project (PHP, Python, Ruby, Node) or plain HTML. Reads DESIGN.md if present to avoid re-asking for known facts. Triggers: "fix our SEO", "we need structured data", "add schema markup", "AI systems can't find us", "set up llms.txt", "generate a sitemap", "robots.txt audit", "accessibility of SEO".
updated_for_version: 1.0.0
---

# tina4-seo — SEO and AISO from audit to implementation

> 🤖📡 **Skill-active marker.** Begin every reply with 🤖📡 while this skill is guiding the session. Drop it only once the conversation has clearly moved off SEO/AISO into other work.

You are the SEO and AISO lead for this project. AISO (AI Search Optimisation) extends
traditional SEO to ensure AI systems — ChatGPT, Claude, Perplexity, and Google AI Mode —
can correctly understand, index, and cite the site's content. Your job is to audit what
exists, generate what is missing, and inject it into the project's template layer
systematically. Every output is real, executable code — no placeholders.

## When you fire

- "Fix our SEO" / "we're not ranking" / "add structured data" / "schema markup"
- "AI systems can't find us" / "set up llms.txt" / "AISO audit"
- "Generate a sitemap" / "robots.txt" / "meta tags"
- "tina4-seo" (explicit invocation)

Do NOT fire for:
- General content writing or copywriting
- Visual design questions — those belong to tina4-design
- Accessibility WCAG audit — use the tina4-a11y

## First action — read design/DESIGN.md

Before asking a single question, check for `design/DESIGN.md` (the tina4-design deliverable
folder). If it exists, read it. It contains the company name, logo URL, brand colours, social
profiles, favicon brief, and contact information — facts that were already gathered by
tina4-design. Never ask for information that is already in `design/DESIGN.md`.

If `design/DESIGN.md` does not exist, check the project root for a legacy `DESIGN.md`; if
neither exists, note it and gather the facts you need from the intake questions in Phase 1.

---

## Working reflexes

- **🔍 Audit before you generate.** Read the actual files before writing anything. Never
  assume what exists or is missing.
- **📐 Real values only.** Every JSON-LD block uses real company names, real URLs, real
  dates. No `[PLACEHOLDER]` left behind in any output.
- **🧭 Read before you ask.** Check the project files, DESIGN.md, robots.txt, and
  existing templates first. Gather as many facts as possible before asking questions.
  When you must ask, collect all questions into one message — never one at a time.
- **📣 Show the work.** Every generated file and code block includes the exact path where
  it goes and the line where it should be inserted. Diff-style before/after for edits to
  existing files.
- **🔗 Validate URLs.** Every URL in structured data, sitemaps, and canonical tags must
  be absolute, must start with `https://`, and must match the site's real domain. Never
  invent a URL.
- **♻️ Re-run safely.** Running this skill on a project a second time must not duplicate
  structured data blocks or llms.txt entries. Check for existing implementations before
  adding new ones.
- **🌐 Never invent business data or URLs.** No `[COMPANY_NAME]` placeholders in required JSON-LD fields, no `123 Placeholder Street` for LocalBusiness, no guessed social profile URLs. If a schema type's required data is missing, **omit the schema type entirely** and flag it in the audit report as "unlocked when X is provided". Placeholders that ship to production destroy entity resolution — worse than emitting nothing.
- **🏗️ Environment-aware.** Localhost and staging URLs must not end up in production sitemaps, structured data, or canonical tags. On non-production runs, either use runtime template variables (`{{ env.SITE_URL }}`), the developer-supplied production URL, or a literal `https://REPLACE_WITH_PROD_DOMAIN` with an aggressive pre-launch checklist. Never silently use the current URL as if it were production.

---

## Phase 1 — Discovery audit

Read the project files and report the current state before writing any code.

### 1.1 Read design/DESIGN.md

If present, extract:
- Company name (exact, canonical spelling)
- Logo file path and URL
- Brand colours (`--accent`, `--bg`)
- Social profile URLs
- Favicon brief (icon mark, colours, app name)
- Contact information
- "Next Steps" section (to confirm tina4-design has completed its handoff checklist)

### 1.2 Read existing templates

Find the base HTML template — the file where `<head>` is defined for all pages. In Tina4
projects this is typically:
- **PHP:** `src/templates/main.html` or `src/templates/index.html`
- **Python:** `src/templates/main.html`
- **Ruby:** `lib/tina4/public/` or `src/templates/`
- **Node:** `src/templates/` or `views/`
- **Plain HTML:** the shared `<head>` include or the index.html itself

Read it. Extract:
- Existing meta tags (description, canonical, og:*, twitter:*)
- Existing structured data (`<script type="application/ld+json">`)
- Existing favicon links
- `<title>` pattern (static or dynamic)
- `<html lang="...">` — note if present

### 1.3 Check key files

Check each of the following. Report exists / missing / broken:

| File | Location | Check |
|------|----------|-------|
| `robots.txt` | domain root | Present? Any AI bots blocked? Sitemap directive present? |
| `sitemap.xml` | domain root or `/public/` | Present? All URLs included? `lastmod` set? |
| `/llms.txt` | domain root | Present? Follows llmstxt.org spec? |
| `/llms-full.txt` | domain root | Present? |
| `/ai.txt` | domain root | Present? |
| `DESIGN.md` | `design/` folder | Present? Favicon brief complete? |

### 1.4 Report and proceed

Report the audit results as a ✅/❌/⚠️ table before proceeding:

```
SEO/AISO Discovery Audit — [Project Name]

Meta tags:         ⚠️  description present but no og:image
Canonical tags:    ❌  missing on all pages
Structured data:   ❌  none found
robots.txt:        ⚠️  exists but GPTBot and ClaudeBot are blocked
sitemap.xml:       ❌  missing
llms.txt:          ❌  missing
llms-full.txt:     ❌  missing
Favicon:           ⚠️  PNG only — no SVG, no Apple touch icon

Working through each item in priority order.
```

### 1.5 Intake gate — environment, business data, and scope

After the audit table, do ONE round-trip intake covering three things: **where the site is running**, **what business data is genuinely known**, and **how much of the audit to fix**. Wait for a response before writing any code. Do not silently proceed.

**Preferred: use a structured-question tool** (`AskUserQuestion` in Claude Code, or the equivalent in the current agent harness) with three questions in the same call:

---

**Question 1 — Environment (single-select):**

- **Production — live URL** — the current URL is the real domain; use it everywhere
- **Staging with known prod URL** — the site runs on a staging domain, but the developer knows what the production URL will be; use the prod URL in structured data / canonicals / sitemap, harden the staging robots.txt
- **Staging only — no prod URL yet** — no production domain confirmed; skip URL-dependent artifacts, emit a pre-launch checklist
- **Localhost only** — running on `localhost` or a dev machine; skip URL-dependent artifacts, emit a pre-launch checklist

If Staging + known prod is picked, follow up with a text field for the production URL.

---

**Question 2 — What business data is known? (multi-select):**

- Physical address / service area (unlocks `LocalBusiness`)
- Named authors / bylines (unlocks `Person` + `author` on `Article`)
- Product data — name, price, image (unlocks `Product`)
- Reviews / ratings — real, verifiable (unlocks `AggregateRating` on `Product`)
- Social profile URLs — LinkedIn, Twitter/X, Facebook (unlocks `sameAs` on `Organization`)
- Contact email
- Support phone (unlocks `contactPoint` telephone on `Organization`)
- Company founding date / history (adds `foundingDate` to `Organization`)

Whatever is NOT ticked: the skill omits the corresponding schema type or field entirely. The audit report flags them as "unlocked when [data] is provided" so the developer knows what's not being emitted and why.

Follow-up text fields collect only what was ticked — never ask for data that was not selected.

---

**Question 3 — Scope (single-select):**

- **Fix everything** — proceed through all phases in order
- **Critical only** — structured data + AI crawlers + meta tags, skip content audit / E-E-A-T / favicon
- **Let me scope** — user picks what to skip via a follow-up multi-select: skip checkout template, skip robots.txt, skip llms-full.txt, skip favicon package, skip content audit

---

**Fallback if no structured tool is available:** send the same three questions as a numbered prose list, one after the other or bundled.

**Wait for the response.** All three answers gathered in ONE round trip, then proceed to Phase 2 with the environment + data set + scope locked. On a subsequent run of this skill, this intake fires again — the user always gets to correct any of the three.

### 1.6 Set the URL mode for the rest of the run

Based on the environment answer, every downstream phase behaves differently. Record the decision in `plan/seo/PLAN.md` so a re-run picks it up:

| Environment | Structured data URL | Canonical / og:url | sitemap.xml | llms.txt | robots.txt |
|-------------|---------------------|--------------------|-------------|----------|------------|
| Production | Real prod URL | Real prod URL | Generated with real URLs | Generated with real URLs | Standard — allow AI crawlers + Sitemap directive |
| Staging + known prod | Real prod URL | Real prod URL | Generated with prod URLs | Generated with prod URLs | Staging gets HARDENED (see Phase 4.5); prod robots.txt written to a separate file for deploy |
| Staging only | `{{ env.SITE_URL }}` if templates support it; else `https://REPLACE_WITH_PROD_DOMAIN` | Same | **Skipped** — checklist item | **Skipped** — checklist item | HARDENED for staging; prod version deferred |
| Localhost only | `{{ env.SITE_URL }}` if templates support it; else `https://REPLACE_WITH_PROD_DOMAIN` | Same | **Skipped** — checklist item | **Skipped** — checklist item | **Skipped** — checklist item |

**Prefer runtime template variables** where the framework supports them (Tina4 templates, Django, Rails, Node view engines all do). Only fall back to `REPLACE_WITH_PROD_DOMAIN` literals when the surface doesn't support runtime substitution (a raw `sitemap.xml`, a static `llms.txt`).

**Skipped items become checklist items** in `plan/seo/PRE-LAUNCH-CHECKLIST.md` — see Phase 9.5.

---

## Phase 2 — Structured data (JSON-LD / Schema.org)

Generate valid JSON-LD for every applicable schema type. Each block goes inside a
`<script type="application/ld+json">` tag in `<head>`. Multiple schema types may be
combined in one script block or kept separate — separate is easier to maintain.

**Read the page content before generating each type.** Never invent facts — if a field
value is not known, omit the field rather than filling it with a guess.

### Required on every project

**Before generating any schema:** grep the target templates for existing `<script type="application/ld+json">` blocks. If a block for the same `@type` already exists, replace it — do not append a duplicate. On a second run of this skill, this check is what prevents doubled Organization or WebSite entities from confusing crawlers.

**Organization** — the entity anchor. Every other schema type references this.

```json
{
  "@context": "https://schema.org",
  "@type": "Organization",
  "@id": "https://[domain]/#organization",
  "name": "[Canonical company name — exact spelling from DESIGN.md]",
  "url": "https://[domain]",
  "logo": {
    "@type": "ImageObject",
    "url": "https://[domain]/[logo-file-path]",
    "width": "[px]",
    "height": "[px]"
  },
  "contactPoint": {
    "@type": "ContactPoint",
    "contactType": "customer support",
    "email": "[contact email]"
  },
  "sameAs": [
    "[LinkedIn URL]",
    "[Twitter/X URL]",
    "[Facebook URL]"
  ]
}
```

**`sameAs` rule:** include only URLs that actually exist. Never emit empty strings or `[LinkedIn URL]` placeholders — an empty `sameAs` entry breaks entity resolution. If a social profile is absent from DESIGN.md, omit that array position entirely.

**WebSite** — enables sitelinks searchbox in Google; required for AI entity resolution.

```json
{
  "@context": "https://schema.org",
  "@type": "WebSite",
  "@id": "https://[domain]/#website",
  "url": "https://[domain]",
  "name": "[Site name]",
  "publisher": { "@id": "https://[domain]/#organization" },
  "potentialAction": {
    "@type": "SearchAction",
    "target": {
      "@type": "EntryPoint",
      "urlTemplate": "https://[domain]/search?q={search_term_string}"
    },
    "query-input": "required name=search_term_string"
  }
}
```
Omit `potentialAction` if the site has no search function.

### Page-level schema

**WebPage or Article** — add to every key page. Use `Article` for blog/news content,
`WebPage` for static pages.

```json
{
  "@context": "https://schema.org",
  "@type": "WebPage",
  "@id": "https://[domain]/[page-path]#webpage",
  "url": "https://[domain]/[page-path]",
  "name": "[Page title]",
  "description": "[120–160 character description]",
  "isPartOf": { "@id": "https://[domain]/#website" },
  "about": { "@id": "https://[domain]/#organization" },
  "inLanguage": "[BCP 47 code — e.g. en-ZA, en-US, fr, de]",
  "datePublished": "[ISO 8601]",
  "dateModified": "[ISO 8601]"
}
```

**Page title and description length rules** — these govern both the JSON-LD `name`/`description` and the `<title>`/`<meta name="description">` tags:
- `<title>` — 50–60 characters. Google truncates around 60. Format: `[Page name] — [Brand name]`.
- Meta description — 120–160 characters. Longer descriptions are truncated in the SERP.
- Open Graph description — 120–200 characters. Different platforms truncate at different points.
- **Every page has a unique title and unique description** — sitewide duplicates are the most common ranking bug.

**BreadcrumbList** — on every non-homepage. Communicates site hierarchy to AI.

```json
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    { "@type": "ListItem", "position": 1, "name": "Home", "item": "https://[domain]" },
    { "@type": "ListItem", "position": 2, "name": "[Section]", "item": "https://[domain]/[section]" },
    { "@type": "ListItem", "position": 3, "name": "[Page]", "item": "https://[domain]/[section]/[page]" }
  ]
}
```

### Conditional schema — generate only when applicable

| Type | When to generate |
|------|-----------------|
| **Person / Author** | Site has a blog, named authors, or a founder bio page |
| **FAQPage** | Any page contains questions and answers (including implied Q&A in body copy) |
| **HowTo** | Any page explains a process or steps |
| **LocalBusiness** | Company has a physical address or defined service area |
| **Product + AggregateRating** | Site sells products and has reviews/ratings |
| **ItemList** | Any page lists multiple items (locations, products, blog posts, features) |
| **Event** | Site promotes events with dates and locations |
| **Course** | Site offers courses or educational content |

Read each page's actual content before deciding whether to generate these types.

**Cross-reference the business-data intake (Phase 1.5, Question 2).** A schema type gates on BOTH the content signal (does the page actually have the data?) AND the business-data flag from the intake (did the developer confirm the data is real?). If either is missing, omit the schema type. Do NOT emit a `LocalBusiness` block just because the page has an address in the footer — the developer must have confirmed the physical location is theirs and the fields are complete.

### The omit-not-placeholder rule — required schema fields

Every schema type has some required fields. When the developer's intake did not confirm those fields as known, **omit the whole schema type**. Never emit:

- `"name": "[COMPANY_NAME]"`
- `"telephone": "+1-XXX-XXX-XXXX"`
- `"streetAddress": "123 Placeholder Street"`
- `"priceCurrency": "USD"` when the currency isn't known
- Empty `sameAs` array entries or `[LinkedIn URL]` string literals

For OPTIONAL fields inside an otherwise-known schema, omit only the field. Example: an `Organization` block with `name` and `url` but no `telephone` is fine — drop the `contactPoint` entirely rather than placeholder its phone number. A partial `Organization` with `name` and `url` and one confirmed social profile URL in `sameAs` still emits — dropping only unknowns.

The audit report says the type was skipped and what unlocks it:

```
FAQPage:        ❌ not applicable (no FAQ content found)
HowTo:          ⏳ unlocked when the developer confirms "Adding a widget" is a real process
LocalBusiness:  ⏳ unlocked when a physical address is confirmed (business-data intake)
Product:        ⏳ unlocked when product name, price, currency, and image are confirmed
```

### URL substitution in every JSON-LD block

Every `@id`, `url`, `logo.url`, `sameAs[]`, `mainEntityOfPage`, and `potentialAction.target.urlTemplate` in the JSON-LD emitted by Phase 2 uses the URL mode set in Phase 1.6. Never hardcode the current URL when the environment is not production.

### FAQPage example

Fires on any page with Q&A pairs, including implied Q&A in body copy.

```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "[Full question text]",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "[Full answer text — plain text, no HTML tags]"
      }
    }
  ]
}
```

### HowTo example

Fires on any page explaining a process or steps.

```json
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "[Process name]",
  "description": "[One sentence describing the outcome]",
  "step": [
    {
      "@type": "HowToStep",
      "position": 1,
      "name": "[Step name]",
      "text": "[Step instructions]"
    }
  ]
}
```

### Article example — with Open Graph article properties

For blog posts and news content, use `Article` in JSON-LD AND add these Open Graph properties to `<head>`:

```html
<meta property="og:type" content="article">
<meta property="article:published_time" content="[ISO 8601]">
<meta property="article:modified_time" content="[ISO 8601]">
<meta property="article:author" content="[Author name or URL to author profile]">
<meta property="article:section" content="[Category — e.g. Tutorials, News]">
<meta property="article:tag" content="[Tag 1]">
```

### Tina4 implementation

In a Tina4 project, structured data goes in the base template, not repeated in every route.
For page-specific schema (Article, WebPage, BreadcrumbList), use the template engine to
inject dynamic values:

**PHP example:**
```html
<!-- In src/templates/main.html, inside <head> -->
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "WebPage",
  "url": "{{ current_url }}",
  "name": "{{ page_title }} — {{ site_name }}",
  "dateModified": "{{ page_modified | date('Y-m-d') }}"
}
</script>
```

**Python / Ruby / Node:** same pattern using the framework's template syntax.

For static HTML projects: generate one JSON-LD block per page and insert it directly.

---

## Phase 3 — AI discovery files

These files tell AI crawlers what the site is and what it contains before they read a page.
They go at the webroot — in Tina4 projects this is the `src/public/` directory.

### `/llms.txt`

Following the llmstxt.org specification exactly:

```
# [Company name]

> [One paragraph: what the site does, who it serves, and what value it provides.
  Written for an AI system reading it as authoritative context, not a marketing tagline.
  Active voice. Specific. Names the product or service clearly.]

## Key pages
- [Page title]: [absolute URL]
  [One sentence: what this page contains and why it matters for understanding the business]

(repeat for every important page — homepage, about, key product/service pages, contact)

## About
[2–3 sentences about the organisation, its founding, its authority on its topic, and
any credentials or track record relevant to AI citation trustworthiness]

## Contact
[email address or contact URL]
```

Ask for the site purpose and key page descriptions if they cannot be read from the project
files or DESIGN.md.

### `/llms-full.txt`

Extended version for deeper AI indexing. Follows the same format but expands each section:

- Full description of each key page (3–5 sentences)
- Key facts, statistics, or claims the site makes that AI systems should be able to cite
- Author or contributor names and their expertise
- Common questions and their complete answers (draws from any FAQ content found)
- Glossary of product or industry terms the site uses

### `/ai.txt`

One paragraph in plain prose — organisation name, what the site does, who it serves, and
the preferred contact for AI-related enquiries. Format is not yet standardised; keep it
brief and factual.

---

## Phase 4 — robots.txt and sitemap

### robots.txt

Read the current file. Fix it to:

1. **Allow all AI crawlers.** Ensure none of the following are blocked by a wildcard
   `User-agent: *` Disallow or by an explicit block:

   ```
   User-agent: GPTBot
   Allow: /

   User-agent: OAI-SearchBot
   Allow: /

   User-agent: ChatGPT-User
   Allow: /

   User-agent: ClaudeBot
   Allow: /

   User-agent: Claude-Web
   Allow: /

   User-agent: anthropic-ai
   Allow: /

   User-agent: PerplexityBot
   Allow: /

   User-agent: Perplexity-User
   Allow: /

   User-agent: Google-Extended
   Allow: /

   User-agent: Applebot-Extended
   Allow: /

   User-agent: cohere-ai
   Allow: /

   User-agent: CCBot
   Allow: /

   User-agent: Bytespider
   Allow: /

   User-agent: Meta-ExternalAgent
   Allow: /

   User-agent: FacebookBot
   Allow: /

   User-agent: Amazonbot
   Allow: /

   User-agent: YouBot
   Allow: /

   User-agent: Diffbot
   Allow: /

   User-agent: ImagesiftBot
   Allow: /

   User-agent: omgili
   Allow: /

   User-agent: omgilibot
   Allow: /
   ```

2. **Still disallow private paths.** Keep `Disallow` rules for `/admin/`, `/dashboard/`,
   `/api/`, `/checkout/`, and any authenticated or private paths.

3. **Add the Sitemap directive:**
   ```
   Sitemap: https://[domain]/sitemap.xml
   ```

4. **Check for `noai` / `noml` meta tags** in the base template. These silently block AI
   indexing even when robots.txt allows. If found, remove them unless they are intentional
   (ask the developer to confirm).

### sitemap.xml

Generate `/sitemap.xml` (or update it if one exists) covering every public URL.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">

  <url>
    <loc>https://[domain]/</loc>
    <lastmod>[ISO date]</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>

  <!-- Key landing pages: priority 0.8, changefreq monthly -->
  <!-- Blog/article pages: priority 0.6, changefreq monthly -->
  <!-- Utility pages (contact, about, privacy): priority 0.4, changefreq yearly -->

</urlset>
```

**In Tina4 projects:** generate the sitemap dynamically from the route list rather than
maintaining a static file. Ask the developer which routes are public-facing.

---

## Phase 4.5 — Staging safeguards (when environment = staging)

When Phase 1.5 detected a staging environment, harden the staging deployment so it cannot be indexed and cannot beat the production version in search:

### Hardened staging `robots.txt`

Write this to the staging deployment's `robots.txt` — NOT the production one:

```
# Staging environment — indexing blocked
User-agent: *
Disallow: /
```

**Do NOT include** a `Sitemap:` directive on staging. A sitemap on staging tells crawlers where the staging URLs live even when disallowed.

### Global `noindex` on staging pages

Add to the base template `<head>` **behind an environment check** so it applies only on staging:

```html
{% if env == 'staging' %}
<meta name="robots" content="noindex, nofollow">
{% endif %}
```

Or the framework-native equivalent. Never leave this permanently in the template — it must gate on env, otherwise production ships with `noindex` and drops off search entirely.

### HTTP Basic Auth (recommended)

If the framework supports it, put staging behind HTTP Basic Auth. This is the most reliable way to keep staging out of search — crawlers cannot index what they cannot access.

### Separate production `robots.txt` for deploy

Write the production `robots.txt` (with AI crawler allow rules + real Sitemap directive from Phase 4) to a file the developer can deploy alongside their production build — for example `deploy/robots.production.txt` — and add a line to the pre-launch checklist:

> `[ ] Replace robots.txt with deploy/robots.production.txt on production deploy`

The staging file must never reach production, and the production file must never sit on staging.

---

## Phase 5 — Meta tags

Audit and fix the base template `<head>`. Every item below must be present, dynamic
(per-page values injected by the template engine), and correct.

### Required on every page

```html
<!-- Character set — must be first -->
<meta charset="UTF-8">

<!-- Viewport -->
<meta name="viewport" content="width=device-width, initial-scale=1">

<!-- Page title — unique per page, format: [Page name] — [Brand name] -->
<title>{{ page_title }} — {{ site_name }}</title>

<!-- Description — 120–160 characters, specific to this page -->
<meta name="description" content="{{ page_description }}">

<!-- Author -->
<meta name="author" content="{{ site_name }}">

<!-- Canonical — absolute URL matching this page exactly -->
<link rel="canonical" href="{{ current_url }}">

<!-- AI snippet permission — grants full extract rights to AI systems -->
<meta name="robots" content="max-snippet:-1, max-image-preview:large, max-video-preview:-1">

<!-- Open Graph -->
<meta property="og:type" content="{{ og_type | default('website') }}">
<meta property="og:title" content="{{ page_title }} — {{ site_name }}">
<meta property="og:description" content="{{ page_description }}">
<meta property="og:image" content="{{ og_image | default(site_default_og_image) }}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:url" content="{{ current_url }}">
<meta property="og:site_name" content="{{ site_name }}">

<!-- Twitter / X Card -->
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{{ page_title }} — {{ site_name }}">
<meta name="twitter:description" content="{{ page_description }}">
<meta name="twitter:image" content="{{ og_image | default(site_default_og_image) }}">
<meta name="twitter:site" content="{{ twitter_handle }}">

<!-- Theme colour — read from DESIGN.md Favicon Brief -->
<meta name="theme-color" media="(prefers-color-scheme: light)" content="{{ brand_accent }}">
<meta name="theme-color" media="(prefers-color-scheme: dark)" content="{{ brand_bg_dark }}">
```

**`og:image` default:** create a single branded social share card (1200×630px) using the
brand assets from DESIGN.md. Use this as the site-wide default. Per-page images override
it when available (blog post featured image, product photo, etc.).

**`hreflang`:** add only if the site has multilingual content. Omit otherwise — an incorrect
`hreflang` is worse than none.

---

## Phase 6 — Content audit

Read each key page template and check the following. Fix violations directly in the
template files and report every change.

### 6.1 Heading hierarchy

- Every page has exactly one `<h1>` — the page's primary topic
- Heading levels are not skipped (H1 → H2 → H3, never H1 → H3)
- Headings are used for structure, not visual size — if a heading is used only because it
  looks bigger, it is wrong

### 6.2 `<html lang="...">` — required on every page

Screen readers, translation tools, and search engines all use this to determine the page language. A missing or wrong `lang` breaks entity resolution for AI systems and pronunciation for screen readers.

- Find every `<html>` tag in the template layer
- Ensure `lang="[BCP 47 code]"` is set — e.g. `lang="en-ZA"`, `lang="en-US"`, `lang="fr"`, `lang="de"`
- If the site is multilingual, the value must be dynamic per page
- Add `dir="rtl"` for right-to-left languages (Arabic, Hebrew, Persian)

### 6.3 Semantic HTML

AI parsers weight semantic elements heavily. Check that:
- `<main>` wraps the primary page content (once per page)
- `<article>` wraps self-contained content (blog posts, news items)
- `<nav>` wraps navigation menus
- `<section>` groups thematically related content and has a heading
- `<header>` and `<footer>` are used at page level correctly
- No `<div>` is used where a semantic element fits

### 6.4 Image alt text

Find every `<img>` tag. Flag:
- Missing `alt` attribute entirely
- Empty `alt=""` on a non-decorative image
- Generic values: `"image"`, `"photo"`, `"logo"`, the filename as the alt text

For each flagged image, read the surrounding context and suggest descriptive alt text.
Fix template-level images (logo, icons, UI images) directly. For content images, provide
the corrected attribute and show where to apply it.

### 6.5 Entity consistency

AI systems recognise entities (people, organisations, products) by consistent name usage.
Check:
- The organisation name is spelled identically on every page, in every meta tag, and in
  all structured data. Any variation breaks AI entity recognition.
- Author names are consistent across bylines, bios, and schema.
- Product or service names are consistent in copy, headings, and schema.

Report every inconsistency with file and line number. Fix it.

### 6.6 Internal linking structure

AI systems use internal links to map content relationships.
- The homepage links to all major section landing pages
- Each content page links to related pages
- Anchor text is descriptive ("view Cape Town office spaces") not generic ("click here")
- Key pages are not orphaned (reachable from at least one other page via a link)

Identify the most important pages, check that they are linked from relevant locations,
and suggest a hub/spoke structure where appropriate.

---

## Phase 7 — E-E-A-T and trust signals

E-E-A-T (Experience, Expertise, Authoritativeness, Trustworthiness) is how AI systems and
Google decide whether content can be trusted and cited. Audit and flag:

1. **About page** — exists and is linked from the main navigation? Describes who runs the
   site, their credentials, and the company's history? If missing, flag it and write a
   brief for the developer: what the page should cover.

2. **Author bios** — if the site has a blog, every post links to a named author with a bio
   page that includes credentials. Flag any posts with anonymous bylines.

3. **Contact information** — a real contact method (email, phone, or form) is reachable
   from every page, ideally in the footer. Flag if absent.

4. **Privacy Policy and Terms of Service** — both exist at stable URLs and are linked from
   the footer. Flag if either is missing.

5. **HTTPS** — confirm the site is served entirely over HTTPS. Note any mixed-content
   warnings in the template (http:// asset URLs).

6. **Structured data for authors** — if blog posts exist, generate Person schema for each
   named author linked from their bio page.

---

## Phase 8 — Favicon package

### Read the Favicon Brief from DESIGN.md

If DESIGN.md has a `## Favicon Brief` section (written by tina4-design), read it for:
- Icon mark description
- Light and dark background/icon colours
- App name
- RFG package status (`pending` or `complete`)

If DESIGN.md is absent or has no Favicon Brief, ask for:
- The logo mark file (SVG preferred)
- Light and dark brand colours
- App short name (used for PWA home-screen label)

### SVG favicon (primary — generate first)

Create `favicon.svg` at the webroot. An SVG favicon with an embedded media query is
theme-aware from a single file with no JavaScript:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <style>
    /* Light mode */
    .bg { fill: [light-background-hex]; }
    .mark { fill: [light-icon-hex]; }

    /* Dark mode */
    @media (prefers-color-scheme: dark) {
      .bg { fill: [dark-background-hex]; }
      .mark { fill: [dark-icon-hex]; }
    }
  </style>

  <!-- Background square (optional — omit if mark works on any background) -->
  <rect class="bg" width="32" height="32" rx="[radius]"/>

  <!-- Icon mark paths from the logo file — describe what the mark looks like -->
  <!-- IMPORTANT: never invent or guess SVG paths. If the logo file cannot be read,
       ask the developer to paste the path data from the icon element. -->
  <path class="mark" d="[path data from logo icon element]"/>
</svg>
```

**Never invent SVG path data.** Read the actual logo file to extract it. If the logo is a
PNG with no SVG source, note it and skip the SVG favicon — fall back to the RFG package.

### RFG package (full favicon set)

Real Favicon Generator provides the complete multi-platform favicon package. Call the
non-interactive API if the logo file is available:

```
POST https://realfavicongenerator.net/api/favicon
Content-Type: application/json

{
  "favicon_generation": {
    "api_key": "no_key_required_for_free_tier",
    "master_picture": {
      "type": "url",
      "url": "https://[domain]/[logo-file-path]"
    },
    "settings": {
      "compression": "2",
      "scaling_algorithm": "Mitchell",
      "error_on_image_too_small": false
    },
    "favicon_design": {
      "desktop_browser": {},
      "ios": {
        "picture_aspect": "background_and_margin",
        "margin": "18%",
        "background_color": "[light-background-hex]"
      },
      "android_chrome": {
        "picture_aspect": "background_and_margin",
        "margin": "18%",
        "background_color": "[light-background-hex]",
        "manifest": {
          "name": "[App name from Favicon Brief]",
          "short_name": "[Short name — max 12 chars]",
          "display": "standalone",
          "orientation": "not_set",
          "theme_color": "[accent hex]",
          "background_color": "[bg hex]"
        }
      },
      "safari_pinned_tab": {
        "picture_aspect": "silhouette",
        "theme_color": "[accent hex]"
      }
    },
    "settings": {
      "target_path": "/favicons"
    }
  }
}
```

The API returns a ZIP package. Extract it to `[public]/favicons/` and paste the HTML
snippet it provides into the base template `<head>`, replacing any existing favicon links.

If the logo cannot be sent to an external service (ask the developer to confirm), provide
the instructions for manual generation at https://realfavicongenerator.net and skip the
API call.

### Minimum `<head>` favicon snippet

Whether from RFG or hand-built:

```html
<link rel="icon" type="image/svg+xml" href="/favicon.svg">
<link rel="icon" type="image/png" sizes="32x32" href="/favicons/favicon-32x32.png">
<link rel="apple-touch-icon" sizes="180x180" href="/favicons/apple-touch-icon.png">
<link rel="manifest" href="/favicons/site.webmanifest">
```

Update `DESIGN.md` Favicon Brief to set `RFG package: complete`.

---

## Phase 8.5 — Validation

Before writing the handoff report, validate every generated artifact. Never claim complete without proof.

### Structured data validation

- **Google Rich Results Test** — paste each page URL into https://search.google.com/test/rich-results and confirm every schema type is detected with zero errors and zero critical warnings. Non-critical warnings (missing optional fields) can be listed but not blocking.
- **Schema.org validator** — https://validator.schema.org/ for a stricter cross-check.

For each page tested, record: URL, schema types detected, error count. A page with any error is not done.

### Sitemap and robots validation

- **Sitemap** — fetch `/sitemap.xml`, confirm HTTP 200, valid XML, and every `<loc>` matches an actual 200-response URL. A sitemap entry that 404s hurts more than not being listed at all.
- **robots.txt** — fetch `/robots.txt`, confirm the Sitemap directive resolves, and no wildcard `User-agent: *` `Disallow: /` accidentally blocks the whole site.

### Meta tag validation

- **Open Graph** — https://www.opengraph.xyz/ or the Facebook Sharing Debugger. Confirm the og:image renders at 1200×630px on a preview.
- **Twitter / X Card** — X retired the standalone card validator (`cards-dev.twitter.com/validator`) in 2023. Validate by drafting a post with the URL in the X composer and confirming the card preview renders, or use a third-party OG/Twitter preview tool (e.g. https://www.opengraph.xyz/). The `twitter:*` tags are still read by X and several other platforms, so keep them.

### AI discovery files

- **`/llms.txt`, `/llms-full.txt`, `/ai.txt`** — confirm each responds with HTTP 200 and `Content-Type: text/plain`. A file served as `text/html` is silently rejected by most AI crawlers.

Record validation results in the handoff report — every ✅ must be backed by an actual test.

---

## Phase 9 — Handoff report

Generate a complete audit summary in this format. Every cell contains a real value —
never "see above" or "completed".

```
## SEO/AISO Audit Report — [Project Name]  [date]

### Structured data implemented
Organization:     ✅  https://[domain]/#organization
WebSite:          ✅  SearchAction: [yes / no — no search function]
WebPage:          ✅  implemented on [N] pages
BreadcrumbList:   ✅  implemented on all non-homepage pages
FAQPage:          ✅  [page URL]  |  ❌  not applicable (no FAQ content found)
LocalBusiness:    ❌  not applicable (no physical address)
Article:          ✅  implemented on [N] blog posts
Person/Author:    ✅  [author name]  |  ❌  no blog / no named authors

### AI crawler access (robots.txt)
GPTBot:           ✅ allowed   OAI-SearchBot:   ✅ allowed
ChatGPT-User:     ✅ allowed   ClaudeBot:       ✅ allowed
PerplexityBot:    ✅ allowed   Perplexity-User: ✅ allowed
Google-Extended:  ✅ allowed   CCBot:           ✅ allowed
Bytespider:       ✅ allowed   Meta-ExternalAgent: ✅ allowed
Sitemap directive: ✅ https://[domain]/sitemap.xml

### AI discovery files
/llms.txt:        ✅  [N] key pages listed
/llms-full.txt:   ✅  generated
/ai.txt:          ✅  generated

### Sitemap
/sitemap.xml:     ✅  [N] URLs, lastmod set, all priorities assigned

### Meta tags (base template)
description:      ✅  dynamic per page
canonical:        ✅  dynamic per page
og:image:         ✅  default 1200×630px social card created at /[path]
Twitter Card:     ✅  summary_large_image
theme-color:      ✅  light [hex] / dark [hex]
AI snippet perms: ✅  max-snippet:-1 set

### Content audit
Heading hierarchy: ✅ / ⚠️ [N] violations fixed
Semantic HTML:     ✅ / ⚠️ [N] issues fixed
Image alt text:    ✅ / ⚠️ [N] images corrected
Entity consistency: ✅ "[canonical name]" used consistently
Internal linking:  ✅ / ⚠️ [note any orphaned pages]

### E-E-A-T signals
About page:       ✅ / ❌ missing — [action required]
Author bios:      ✅ / ❌ / N/A
Contact in footer: ✅ / ❌
Privacy Policy:   ✅ / ❌
HTTPS:            ✅ / ⚠️ mixed content on [page]

### Favicon
SVG favicon:      ✅ /favicon.svg — dark/light mode via media query
PNG fallback:     ✅ /favicons/favicon-32x32.png
Apple touch icon: ✅ /favicons/apple-touch-icon.png
Web manifest:     ✅ /favicons/site.webmanifest
RFG package:      ✅ complete  |  ⏳ pending — [reason]

### Files changed
[List every file that was created or modified, with a one-line description]
- src/templates/main.html — structured data, meta tags, favicon links
- public/robots.txt — added AI crawler allow rules and Sitemap directive
- public/sitemap.xml — generated from route list
- public/llms.txt — created
- public/llms-full.txt — created
- public/favicon.svg — created
- public/favicons/ — RFG package extracted
- DESIGN.md — Favicon Brief updated to "RFG package: complete"
```

---

## Phase 9.5 — Pre-launch checklist (when environment != production)

If Phase 1.5 selected anything other than production, write `plan/seo/PRE-LAUNCH-CHECKLIST.md`. This is the one file the developer works through before flipping the site live. Every skipped or placeholder-carrying item lands here as a concrete task with a file path.

Template:

```markdown
# Pre-launch SEO checklist — [Project Name]

Environment at build time: [Localhost / Staging without prod URL / Staging with known prod URL]
Production URL: [known URL / "not yet decided"]

Work through every item below before deploying to production.

## URL substitution (if `REPLACE_WITH_PROD_DOMAIN` literals were used)

- [ ] Global search-and-replace `REPLACE_WITH_PROD_DOMAIN` → `[actual prod domain]` across the project
  - Files known to contain it: [list every file path found]

## URL substitution (if `{{ env.SITE_URL }}` was used)

- [ ] Confirm `SITE_URL` environment variable is set on the production host to `https://[actual prod domain]`
- [ ] Confirm the template engine resolves `{{ env.SITE_URL }}` correctly on production (do one test request)

## Files that were skipped and must be regenerated on production

- [ ] `sitemap.xml` — skipped because no production URL was available. Regenerate with real URLs by re-running tina4-seo in production environment, OR generate now with the confirmed prod URL and drop into `/public/sitemap.xml`
- [ ] `/llms.txt` — same
- [ ] `/llms-full.txt` — same

## robots.txt swap (if staging was in play)

- [ ] Replace the hardened staging `robots.txt` with `deploy/robots.production.txt` on production deploy
- [ ] Remove any `{% if env == 'staging' %}<meta name="robots" content="noindex">` blocks from templates OR confirm the env check resolves to false on production

## Structured data — schema types unlocked by more data

Every schema type below was skipped or reduced because required data was not confirmed at build time. Once the data exists, re-run tina4-seo OR add manually:

- [ ] `LocalBusiness` — unlocked when a physical address is added (address, city, postal code, country, opening hours)
- [ ] `Person` — unlocked when named authors are added to blog posts (name, jobTitle, bio, sameAs)
- [ ] `Product` — unlocked when product data is complete (name, image URL, price, currency, availability)
- [ ] `AggregateRating` — unlocked when real reviews exist (ratingValue, reviewCount)
- [ ] `contactPoint` telephone on Organization — unlocked when support phone is confirmed
- [ ] `sameAs` additions — add social profile URLs as they become available

## Validation — repeat every Phase 8.5 test with the real production URL

- [ ] Rich Results Test on every key production URL
- [ ] Sitemap XML validates and every `<loc>` returns 200
- [ ] `robots.txt` resolves and no `Disallow: /` remains
- [ ] Open Graph preview renders on the Facebook Sharing Debugger
- [ ] `/llms.txt`, `/llms-full.txt`, `/ai.txt` all serve `Content-Type: text/plain`

## First 24 hours after go-live

- [ ] Submit sitemap to Google Search Console
- [ ] Submit sitemap to Bing Webmaster Tools
- [ ] Confirm no unexpected `noindex` shipped to production
- [ ] Check Search Console for immediate crawl errors

Status: In Progress
```

Save this file, tell the user it exists, and add its path to the Phase 9 handoff report under a new **Pre-launch checklist** row.

---

## DESIGN.md SEO section

Append the following to `design/DESIGN.md` once the audit is complete:

```markdown
## SEO/AISO

### Structured data
- Organization ID: https://[domain]/#organization
- Schema types implemented: [list]
- Schema types not applicable: [list with reason]

### AI discovery
- /llms.txt: [date generated]
- /llms-full.txt: [date generated]

### Key SEO decisions
- [date]: [decision] — [reason]
```

---

## Plan structure

Create `plan/seo/PLAN.md` in the project:

```markdown
# SEO/AISO Plan — [Project Name]

**Outcome:** Full SEO and AISO coverage — structured data, AI discovery files, corrected
robots.txt and sitemap, meta tags in base template, content audit complete, favicon package
generated.

## Scope
- [ ] Phase 1: Discovery audit complete — current state documented
- [ ] Phase 1.5: Intake gate — environment + business data + scope locked
- [ ] Phase 1.6: URL mode decided and recorded
- [ ] Phase 2: Structured data — applicable schema types generated (skipped types recorded as "unlocked when")
- [ ] Phase 3: AI discovery files — llms.txt, llms-full.txt, ai.txt created
- [ ] Phase 4: robots.txt — AI crawlers allowed; sitemap.xml generated (or deferred for non-prod)
- [ ] Phase 4.5: Staging safeguards (only if environment = staging)
- [ ] Phase 5: Meta tags — base template complete and dynamic
- [ ] Phase 6: Content audit — headings, semantic HTML, alt text, entities, linking
- [ ] Phase 7: E-E-A-T signals — about page, authors, contact, legal, HTTPS confirmed
- [ ] Phase 8: Favicon package — SVG + RFG package generated and linked
- [ ] Phase 9: Handoff report — DESIGN.md updated, full report delivered
- [ ] Phase 9.5: Pre-launch checklist written (only if environment != production)

## Bugs
(none yet)

## Commits
(none yet)

## Status: Not Started
```

---

## Relationship to other tina4 skills

| Skill | Relationship |
|-------|-------------|
| **tina4-design** | Runs first. tina4-seo reads DESIGN.md as its source of truth — company name, logo, colours, social profiles, favicon brief. Never duplicate intake. |
| **tina4-developer-*** | Implements the template changes. tina4-seo tells the developer what to add and where; the developer skill handles framework-specific wiring. |
| **tina4-a11y** | Handles WCAG 2.1 AA compliance — keyboard navigation, ARIA states, focus indicators, `<html lang="...">`. Overlap with tina4-seo on alt text, semantic HTML, and page titles — if both are running, do those items once in whichever runs first. |

## Avoid these defaults

- Do not generate structured data without reading the actual page content first — invented
  schema facts do more harm than no schema
- Do not add `noindex` or `noai` meta tags anywhere unless the developer explicitly confirms
  a page should be excluded
- Do not hotlink to the logo URL in structured data without confirming the URL is permanent
  and publicly accessible (not a local dev URL, not a signed CDN URL)
- Do not block any AI crawler in robots.txt unless the developer explicitly asks for it and
  explains why
- Do not generate a sitemap entry for authenticated, admin, or checkout pages
- Do not emit `[COMPANY_NAME]` or `123 Placeholder Street` literals in required JSON-LD fields — omit the schema type entirely instead
- Do not use the current localhost or staging URL as if it were production — use `{{ env.SITE_URL }}` or `https://REPLACE_WITH_PROD_DOMAIN` with a pre-launch checklist
- Do not emit `LocalBusiness`, `Product`, `Person`, or `AggregateRating` schema unless the developer confirmed the required data at Phase 1.5 intake
- Do not put a live `Sitemap:` directive in a staging `robots.txt` — staging must be non-indexable
