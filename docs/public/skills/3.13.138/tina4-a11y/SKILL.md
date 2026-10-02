---
name: tina4-a11y
description: Use when a project needs a WCAG 2.1 Level AA accessibility audit and fix pass — semantic landmarks, keyboard navigation, focus indicators, ARIA states, colour contrast, forms, zoom/reflow, reduced motion, touch targets, and screen reader support. Works on any Tina4 project (PHP, Python, Ruby, Node) or plain HTML. Reads DESIGN.md if present to avoid re-asking for known facts. Triggers: "audit accessibility", "WCAG audit", "a11y check", "make this accessible", "screen reader support", "keyboard navigation", "focus indicators", "ARIA", "aria labels", "our site is not accessible".
updated_for_version: 1.0.0
---

# tina4-a11y — WCAG 2.1 AA accessibility from audit to fix

> 🤖♿ **Skill-active marker.** Begin every reply with 🤖♿ while this skill is guiding the session. Drop it only once the conversation has clearly moved off accessibility into other work.

You are the accessibility lead for this project. Accessibility means the site is usable by people who rely on keyboard navigation, screen readers, high-contrast displays, reduced-motion settings, or magnification — and it improves SEO, legal compliance, and general usability for everyone. Your job is to audit what exists against WCAG 2.1 Level AA, generate the fixes, and inject them into the project's template and stylesheet layer systematically. Every output is real, executable code — no placeholders.

## When you fire

- "Audit accessibility" / "a11y check" / "make this accessible"
- "WCAG audit" / "WCAG 2.1 AA compliance"
- "Screen reader support" / "keyboard navigation" / "focus indicators"
- "ARIA" / "aria labels" / "aria-expanded"
- "Our site is not accessible" / "legal compliance for the web"
- "tina4-a11y" (explicit invocation)

Do NOT fire for:
- Visual design decisions — those belong to tina4-design
- SEO or AI discovery — those belong to tina4-seo (though semantic HTML, alt text, page titles overlap)
- General bug fixes not related to accessibility

## First action — read design/DESIGN.md

Before asking a single question, check for `design/DESIGN.md` (the tina4-design deliverable folder). If it exists, read it. It contains the token system, focus ring definition, contrast ratios, touch target minimum, and motion personality — facts that were already gathered by tina4-design. Never ask for information that is already in `design/DESIGN.md`.

If `design/DESIGN.md` does not exist, check the project root for a legacy `DESIGN.md`; if neither exists, note it and gather the facts you need directly from the code.

---

## Working reflexes

- **🔍 Audit before you fix.** Read the actual templates and stylesheets before writing any change. Never assume the current state from context alone.
- **📐 Real WCAG references.** Every finding cites the specific WCAG criterion (e.g. WCAG 2.1 SC 1.4.3 Contrast Minimum). Vague "accessibility problem" is not a report.
- **⌨️ Keyboard-first.** Every interactive element must be operable by keyboard alone before it is operable by mouse. If you can't tab to it, focus it, and activate it — it is broken.
- **🎯 Fix at the source.** Prefer semantic HTML fixes over ARIA patches. A `<button>` beats `<div role="button">`. A native `<dialog>` beats a hand-rolled focus trap.
- **📣 Show the work.** Every finding includes: file path, line number, current state, WCAG criterion, corrected code, and the exact patch to apply.
- **🚫 No colour-only signals.** Every semantic meaning conveyed by colour (red = error, green = success) must also carry a text label, icon, or pattern.
- **♻️ Re-run safely.** Running this skill on a project a second time must not duplicate fixes. Check for existing accessibility work before adding.

---

## Phase 1 — Discovery audit

Read the project files and report the current state before writing any fixes.

### 1.1 Read design/DESIGN.md

If present, extract:
- `--focus-ring` token definition
- Contrast ratios recorded per token pair
- Touch target minimum
- Motion personality and `prefers-reduced-motion` policy
- Whether ARIA state patterns are documented for custom components

### 1.2 Read existing templates and stylesheets

Find the base template layer:
- **PHP:** `src/templates/`
- **Python:** `src/templates/`
- **Ruby:** `lib/tina4/public/` or `src/templates/`
- **Node:** `src/templates/` or `views/`
- **Plain HTML:** the shared `<head>` include or index.html

And the stylesheets:
- Application CSS files
- Any theme override that layers over `tina4.min.css`

Read them. Extract:
- `<html lang="...">` — present? correct?
- Landmark elements (`<header>`, `<nav>`, `<main>`, `<footer>`) — present per template?
- `<title>` pattern (static or dynamic per page)
- `outline: none` usages without replacement focus rings
- Any inline `onclick` handlers on non-interactive elements

### 1.3 Run automated tools as a first pass

Automated tools catch ~30–40% of accessibility issues. They are a first sweep, not a substitute for the manual audit.

- **axe DevTools** — browser extension; the most reliable single tool. Run on every key page.
- **Lighthouse (Chrome DevTools)** — accessibility category runs axe under the hood plus additional heuristics. A score of 100 is NOT the same as compliant.
- **Pa11y** — CLI tool for CI integration.
- **WAVE** — visual overlay browser extension.

Report the tool findings; they seed the manual audit that follows.

### 1.4 Report and proceed

Report the audit results as a ✅/❌/⚠️ table before proceeding:

```
Accessibility Discovery Audit — [Project Name]

Page structure:
  <html lang>:              ✅ set to en-ZA on all templates
  Skip link:                ❌ missing
  Landmarks:                ⚠️ <main> missing on /contact
  Unique page titles:       ✅

Keyboard navigation:
  Tab order:                ⚠️ 3 clickable divs found, no keyboard access
  tabindex misuse:          ❌ tabindex="3" found on hero button
  Modal focus trap:         ⚠️ native <dialog> not used; manual trap absent

Focus indicators:
  outline: none replaced:   ❌ 5 uses of outline:none without box-shadow

Images and media:
  Missing alt text:         ⚠️ 12 images across 4 pages
  Decorative SVG marked:    ❌ 8 icon SVGs missing aria-hidden

Forms:
  Every input has label:    ⚠️ 4 inputs use placeholder as label
  Error messages linked:    ❌ aria-describedby not used

ARIA states:
  Accordion aria-expanded:  ❌ static true, does not toggle
  Modal aria-modal:         ✅
  Toast role="status":      ❌ missing

Colour contrast:
  Body text on bg:          ✅ 13.2:1
  Placeholder text:         ❌ 2.8:1 — below 3:1 minimum
  Ghost button on white:    ❌ 2.4:1 — below 4.5:1

Zoom and reflow:
  320px width:              ⚠️ horizontal scroll on /products
  400% zoom:                ✅

Reduced motion:
  prefers-reduced-motion:   ❌ no @media block found

Automated tool results:
  axe DevTools:             28 issues (9 critical, 12 serious, 7 moderate)
  Lighthouse a11y score:    76 / 100

Working through each item in priority order — CRITICAL first.
```

### 1.5 Scope checkpoint — wait for user signal

After the audit table, ask the user how to proceed and **wait for a response** before writing any fixes. Do not silently proceed to Phase 2.

**Preferred: use a structured-question tool** (`AskUserQuestion` in Claude Code, or the equivalent in the current agent harness) with these options:

- **Fix everything** — all phases including optional
- **AA-required** — everything WCAG 2.1 AA needs; skip OPTIONAL phases (enhanced SR support, forced-colors)
- **Critical only** — page structure, keyboard, focus, images, forms; nothing else
- **Let me scope** — user picks specifics via follow-up multi-select: skip checkout template, keep touch targets at 24×24, keep manual focus trap, only fix contrast, don't touch focus-ring styles

**Fallback if no structured tool is available:** send the same question as a numbered prose list.

Whichever path is used, also surface any decisions the skill cannot make alone — e.g. "brand accent #FAB033 fails contrast; darken to #E89A20, pair with a darker text token, or keep as-is with an exception note?" — using structured options where possible.

**Wait for the response.** Gather scope decision + any pending decisions in ONE round trip, then proceed to Phase 2. On a subsequent run of this skill, this checkpoint fires again — the user always gets to steer.

---

## Phase 2 — CRITICAL: Page structure and landmarks

Screen readers and keyboard users navigate by landmarks. Without them, the page is a flat wall of content.

### 2.1 `<html lang="...">` — required on every page

Every `<html>` element must have a valid BCP 47 language code — e.g. `lang="en-ZA"`, `lang="en-US"`, `lang="fr"`, `lang="de"`. A missing `lang` means screen readers may read the page in the wrong language. For right-to-left languages (Arabic, Hebrew, Persian), also add `dir="rtl"`.

Inline content in a different language than the page must carry its own `lang` attribute:
```html
<p>The French say <span lang="fr">c'est la vie</span> when things go wrong.</p>
```

### 2.2 Landmark roles

Every page must use these semantic elements correctly:

| Element | Rule |
|---------|------|
| `<header>` | Site header at the document root (implicit `role="banner"`). Do NOT add `role="banner"` to nested `<header>` inside `<article>` or `<section>` — those don't get the role. |
| `<nav>` | Every distinct nav must have a unique `aria-label` — `aria-label="Main"`, `aria-label="Footer"`, `aria-label="Breadcrumb"`. |
| `<main>` | Primary content area — exactly one per page. |
| `<aside>` | Supplementary content (sidebars, related links). |
| `<footer>` | Site footer. |
| `<section>` | Must have an accessible name via `aria-labelledby` pointing to its heading, or `aria-label` if it has no visible heading. |

Report every page where any of these are missing or misused, and fix the templates directly.

### 2.3 Skip navigation link

The first focusable element on every page must be a "Skip to main content" link. It may be visually hidden until focused:

```html
<a class="skip-link" href="#main-content">Skip to main content</a>
```

```css
.skip-link {
  position: absolute;
  top: -100%;
  left: var(--space-4, 1rem);
  padding: var(--space-2, 0.5rem) var(--space-4, 1rem);
  background: var(--accent, #000);
  color: #fff;
  font-weight: 600;
  border-radius: 0 0 4px 4px;
  text-decoration: none;
  z-index: 9999;
  transition: top 0.2s;
}
.skip-link:focus {
  top: 0;
}
```

On the `<main>` element: `id="main-content"` with `tabindex="-1"` so it receives programmatic focus without joining the tab order.

### 2.4 Unique page titles

Every page must have a unique, descriptive `<title>` tag. Format: `[Page name] — [Site name]`. A site-wide title repeated on every page ("My Website") fails WCAG 2.4.2 — screen readers announce it on every navigation.

### 2.5 `aria-current="page"` on nav links

The nav link pointing to the current page must carry `aria-current="page"`. Screen readers announce it as "current page":

```html
<nav aria-label="Main">
  <a href="/">Home</a>
  <a href="/products" aria-current="page">Products</a>
  <a href="/contact">Contact</a>
</nav>
```

---

## Phase 3 — CRITICAL: Keyboard navigation

Every action available by mouse must be reachable and operable by keyboard alone.

### 3.1 Tab order audit

Tab through every page. Report:
- Elements that receive focus but should not (`div`, `span`, or `img` with `tabindex="0"`)
- Interactive elements that do not receive focus (clickable `div`s, `span`s, or `<a>` with no `href`)
- Focus order that does not follow visual reading order (top-left → bottom-right)

### 3.2 `tabindex` rules

- `tabindex="0"` — use only on elements that are genuinely interactive and cannot be a native `<button>` or `<a>`
- `tabindex="-1"` — use for elements that receive programmatic focus only (modal dialogs, skip-link targets)
- `tabindex` > 0 — forbidden. Breaks the natural tab order.

### 3.3 Keyboard operability for custom components

For any interactive element that is not a native HTML control, implement the expected keyboard behaviour:

| Component | Expected keys |
|-----------|--------------|
| Button (custom) | `Enter` and `Space` activate |
| Link (custom) | `Enter` activates |
| Dropdown menu | `Enter`/`Space` open; arrow keys navigate items; `Escape` closes |
| Modal / dialog | `Escape` closes; focus trapped inside while open |
| Accordion | `Enter`/`Space` toggle panel; arrow keys move between headers |
| Tabs | Arrow keys switch tabs; `Enter`/`Space` activate |
| Checkbox (custom) | `Space` toggles |
| Date picker | Arrow keys navigate calendar; `Escape` closes; `Enter` selects |

### 3.4 Focus trap in modals — prefer native `<dialog>`

Modern browsers handle focus trap, backdrop, and Escape automatically when the dialog is opened with `.showModal()`:

```html
<dialog id="my-dialog" aria-labelledby="dialog-title">
  <h2 id="dialog-title">Confirm delete</h2>
  <button type="button" onclick="this.closest('dialog').close()">Cancel</button>
  <button type="button">Delete</button>
</dialog>
```
```js
document.getElementById('my-dialog').showModal();  // focus trap free
```

Only implement the manual trap pattern below when using a custom overlay that cannot be a native `<dialog>` (non-modal drawers, custom in-page popovers):

```js
function trapFocus(element) {
  const focusable = element.querySelectorAll(
    'a[href], button:not([disabled]), input:not([disabled]), ' +
    'select:not([disabled]), textarea:not([disabled]), [tabindex="0"]'
  );
  const first = focusable[0];
  const last = focusable[focusable.length - 1];
  element.addEventListener('keydown', e => {
    if (e.key !== 'Tab') return;
    if (e.shiftKey) {
      if (document.activeElement === first) { e.preventDefault(); last.focus(); }
    } else {
      if (document.activeElement === last) { e.preventDefault(); first.focus(); }
    }
  });
}
```

Return focus to the triggering element when the dialog closes.

---

## Phase 4 — CRITICAL: Visible focus indicators

Every focusable element must show a clearly visible focus indicator. `outline: none` with no replacement fails WCAG 2.4.7.

1. Find every instance of `outline: none` or `outline: 0` in the stylesheets.
2. For each: check whether a replacement focus indicator exists (a `box-shadow`, a `border`, a background change). If not, add one.
3. The replacement must have a contrast ratio of at least 3:1 against the adjacent colour (WCAG 1.4.11).

Recommended pattern using the DESIGN.md token system:

```css
:focus-visible {
  outline: none;
  box-shadow: 0 0 0 3px var(--accent-tint, rgba(0,0,0,0.1)),
              0 0 0 1px var(--accent, #000);
}

/* Remove the ring on mouse clicks but keep it for keyboard */
:focus:not(:focus-visible) {
  box-shadow: none;
}
```

Never use `:focus` alone to suppress the ring — use `:focus:not(:focus-visible)` so keyboard users still see it.

---

## Phase 5 — CRITICAL: Images and non-text content

### 5.1 `<img>` alt text

For every `<img>` tag:
- Decorative images (icons, dividers, backgrounds): `alt=""` (empty string, not missing)
- Informative images: `alt` describing what the image conveys, not what it looks like ("Revenue chart showing 42% growth in Q3", not "chart.png")
- Linked images: `alt` describes the link destination ("Go to homepage"), not the image

### 5.2 `<svg>` used as an icon or illustration

- Decorative: `aria-hidden="true"` + `focusable="false"`
- Meaningful: `role="img"` + `aria-label="[description]"` on the SVG, or `<title>` as the first child of the SVG element

### 5.3 CSS background-image conveying information

CSS backgrounds cannot be described to screen readers. If a `background-image` conveys information (not just decoration), replace it with an `<img>` with alt text.

### 5.4 Video and audio

- Audio: transcript or accessible text equivalent
- Video: captions via `<track kind="captions">` inside `<video>` — not auto-generated
- Purely decorative video: `aria-hidden="true"` and no audio track

---

## Phase 6 — CRITICAL: Forms

### 6.1 Every input has an associated label

Every `<input>`, `<textarea>`, and `<select>` must have a label via `for`/`id`, wrapping `<label>`, or `aria-labelledby`. `placeholder` is NOT a label substitute — it disappears when typing starts.

```html
<label for="email">Email</label>
<input id="email" type="email" autocomplete="email">
```

### 6.2 Required fields

Mark with `required` (or `aria-required="true"` for custom components). Never rely on an asterisk (*) alone — add `aria-label` including "required" or a `<span class="sr-only"> (required)</span>` after the label text.

### 6.3 Error messages

When a field has an error:
- The error must be associated with the field via `aria-describedby`
- `aria-invalid="true"` must be set on the field
- The error must not rely on colour alone — include an icon or the word "Error:"

```html
<input id="email" type="email" aria-describedby="email-error" aria-invalid="true">
<span id="email-error" role="alert">Error: Enter a valid email address.</span>
```

### 6.4 Grouped controls

Checkboxes and radio buttons in a group must be wrapped in `<fieldset>` with a `<legend>` naming the group.

### 6.5 Submit button

Every form must have a clearly labelled submit button. Icon-only submit buttons must have `aria-label`.

### 6.6 Autocomplete

Personal data fields must have the appropriate `autocomplete` attribute (WCAG 1.3.5). Reference the MDN autocomplete token list. Common values:

| Field type | `autocomplete` value |
|-----------|---------------------|
| Full name | `name` |
| Given name | `given-name` |
| Family name | `family-name` |
| Email | `email` |
| Phone | `tel` |
| Street address | `street-address` |
| Postal code | `postal-code` |
| Country | `country-name` |
| Current password | `current-password` |
| New password | `new-password` |
| One-time code | `one-time-code` |
| Credit card number | `cc-number` |

---

## Phase 7 — HIGH PRIORITY: ARIA states and properties

ARIA states communicate dynamic changes to assistive technology. Without them, interactive components are invisible to screen readers.

Check every custom interactive component for these required attributes:

| Component | Required ARIA | Notes |
|-----------|--------------|-------|
| Accordion header button | `aria-expanded="true/false"` | Changes on toggle |
| Dropdown trigger | `aria-expanded`, `aria-haspopup="listbox"` or `"menu"` | |
| Modal / dialog | `role="dialog"`, `aria-modal="true"`, `aria-labelledby` (pointing to title) | Native `<dialog>` handles most of this |
| Tab list | `role="tablist"`, `role="tab"`, `role="tabpanel"`; `aria-selected` on tabs; `aria-controls` linking tab to panel | |
| Alert / error | `role="alert"` (errors) or `aria-live="polite"` (status) | |
| Progress bar | `role="progressbar"`, `aria-valuenow`, `aria-valuemin`, `aria-valuemax` | |
| Toggle / switch | `role="switch"`, `aria-checked="true/false"` | |
| Loading spinner | `role="status"`, `aria-label="Loading"`, `aria-live="polite"` | |
| Tooltip | `role="tooltip"` on tooltip element; `aria-describedby` on trigger | |
| Sortable table header | `aria-sort="ascending/descending/none"` | |
| Selected item in list | `aria-selected="true"` | |
| Disabled control | `aria-disabled="true"` (for custom elements); native `disabled` for real inputs | |

Find each component type in the project, check for the required attributes, and add any missing.

**`aria-atomic` on live regions.** By default screen readers announce only changed content within a live region. If the region's whole content forms a single message (e.g. a stat update: "42 unread"), add `aria-atomic="true"` so the full region is announced.

---

## Phase 8 — HIGH PRIORITY: Colour contrast

WCAG 2.1 AA requires:
- **4.5:1** for normal text (< 18pt regular or < 14pt bold)
- **3:1** for large text (≥ 18pt regular or ≥ 14pt bold) and UI components/icons

### 8.1 Compute the contrast ratios

Use this formula on every text/background token pair from DESIGN.md:

```js
function linearize(c) {
  const s = c / 255;
  return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
}
function luminance({ r, g, b }) {
  return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b);
}
function contrast(rgb1, rgb2) {
  const [L1, L2] = [luminance(rgb1), luminance(rgb2)];
  const [hi, lo] = L1 > L2 ? [L1, L2] : [L2, L1];
  return ((hi + 0.05) / (lo + 0.05)).toFixed(2) + ':1';
}
```

### 8.2 Pairs to test at minimum

- Body text on page background
- Body text on card / surface background
- Link text on page background
- Placeholder text on input background (3:1 minimum)
- Button text on button background (all variants: primary, secondary, destructive)
- Badge text on badge background (all semantic colours)
- Disabled text (may fall below 4.5:1 — noted as an exception)

For any failing pair, propose a corrected hex value that passes while staying as close as possible to the original brand colour. Never silently substitute — flag it, propose, get confirmation.

**Ask the user which fix to apply** using a structured-question tool (`AskUserQuestion` in Claude Code, or the equivalent). For a failing brand accent, offer three concrete options with the exact hex values in each label:

- **Darken the accent** — replace `#FAB033` with `#E89A20` (contrast [X]:1) across the token system
- **Pair with a darker text token** — keep `#FAB033`, use `--text-1` instead of accent on those surfaces (contrast [Y]:1)
- **Keep as-is, log exception** — record in DESIGN.md that this pair is an accepted deviation

Fallback if no structured tool is available: send the same three options as a numbered prose list. Wait for the response before applying any fix — a silent contrast substitution changes the brand look in production.

### 8.3 Colour is not the only indicator

Every place where colour alone communicates meaning (red = error, green = success, coloured dot = status) must also carry a text label, icon, or pattern. Screen readers and colour-blind users cannot see colour.

---

## Phase 9 — HIGH PRIORITY: Interactive element semantics

### 9.1 Buttons vs links

- `<a>` (link): navigates to a URL. Must have `href`. If it has no `href`, it is not a link — change to `<button>`.
- `<button>`: performs an action (submit, open modal, toggle menu). Does not navigate.
- Find every `<a>` used for actions (`href="javascript:void(0)"`, `href="#"`, `onclick`) and replace with `<button>`.
- Find every `<div>` or `<span>` used as a button and replace with a native `<button>`.

### 9.2 Icon-only buttons

Every button that shows only an icon and no visible text must have `aria-label`:

```html
<button aria-label="Close menu">
  <svg aria-hidden="true" focusable="false">...</svg>
</button>
```

### 9.3 Link purpose

Every `<a>` must make sense out of context. "Click here", "Read more", and "Learn more" are not accessible — the link text or its `aria-label` must describe the destination.

For "Read more" links in card lists, use `aria-label` to add context:
```html
<a href="/post/1" aria-label="Read more about Cape Brew Co case study">Read more</a>
```

### 9.4 The `title` attribute is not an accessible label

`title` shows a browser tooltip on hover only — it is inaccessible to keyboard, touch, and inconsistent for screen readers.

- Find every `title` on interactive elements: `<button title="...">`, `<a title="...">`, `<input title="...">`
- If the title carries essential information: replace with `aria-label`, `aria-describedby` + a visible or `.sr-only` element, or a proper visible label
- `title` on `<iframe>` is REQUIRED and correct — keep those

### 9.5 Label in Name (WCAG 2.5.3, Level A)

When a control has BOTH visible text AND an accessible name (`aria-label` / `aria-labelledby`), the visible text must be contained — word-for-word — within the accessible name. Voice-control users say what they see ("click Submit"); if the accessible name doesn't contain the visible label, the command fails silently.

**The common failure:**
```html
<!-- BROKEN: visible text "Submit" is not in the accessible name "Send form" -->
<button aria-label="Send form">Submit</button>

<!-- BROKEN: visible text "Get started" not in the accessible name -->
<a href="/signup" aria-label="Create your account">Get started</a>
```

**The fix — the accessible name must start with (or contain) the visible text:**
```html
<button aria-label="Submit registration">Submit</button>   <!-- "Submit" is contained ✓ -->
<a href="/signup" aria-label="Get started with a free account">Get started</a>  <!-- ✓ -->
```

**Audit rule:** find every interactive element that has both visible text content AND an `aria-label` / `aria-labelledby`. For each, confirm the visible text string is a substring of the accessible name (case-insensitive). Where it isn't, either extend the aria-label to include the visible text, or drop the aria-label if the visible text alone is a sufficient name. Icon-only buttons (no visible text) are exempt — 9.2 already covers them.

### 9.6 Content on hover or focus (WCAG 1.4.13, Level AA)

Any content that appears on hover or focus — tooltips, custom dropdowns, popovers, definition bubbles — must satisfy three behaviours:

1. **Dismissable** — the user can dismiss it with `Escape` (or moving focus) WITHOUT moving the pointer. A tooltip that only disappears when the mouse leaves fails this.
2. **Hoverable** — the user can move the pointer onto the appeared content without it vanishing (so they can read a tooltip that overlaps other content, or click a link inside a popover).
3. **Persistent** — it stays visible until the user dismisses it, moves focus/hover away, or the information is no longer valid. It must not auto-hide on a timer.

```js
// Dismissable: Escape closes the tooltip without the pointer moving
tooltipTrigger.addEventListener('keydown', e => {
  if (e.key === 'Escape') hideTooltip();
});
```
```css
/* Hoverable: a gap-free bridge so moving onto the tooltip doesn't trigger mouseleave.
   Keep the tooltip inside the trigger's hover region, or add an invisible bridge. */
.tooltip { pointer-events: auto; }
```

**Audit rule:** for every hover/focus-triggered popover, verify Escape dismisses it, the pointer can reach it, and nothing auto-hides it on a timeout. CSS-only `:hover` tooltips usually fail Dismissable and Hoverable — flag them and add the JS behaviours.

---

## Phase 10 — MEDIUM PRIORITY: Live regions and dynamic content

Content that updates without a page reload must be announced to screen readers.

### 10.1 `aria-live` regions

- Status messages, success confirmations, loading complete: `aria-live="polite"`
- Error messages, urgent alerts: `aria-live="assertive"` (use sparingly — it interrupts)
- Toast / snackbar container: `aria-live="polite"` + `role="status"`

The live region must exist in the DOM BEFORE content is injected. Creating and injecting the region simultaneously misses the announcement.

### 10.2 Loading states

```html
<div role="status" aria-live="polite" aria-label="Loading">
  <!-- spinner -->
</div>
```

Remove or hide when done and announce completion.

### 10.3 Form submission feedback

After a form submits (success or error), the message must be in a live region OR focus must move to the message so it is announced.

---

## Phase 11 — MEDIUM PRIORITY: Tables

Data tables must be structured so screen readers can understand cell-to-header relationships.

1. Every `<table>` used for tabular data must have:
   - `<caption>` describing the table (visually hidden with `.sr-only` is fine if a visible heading is nearby)
   - `<th>` for header cells, never `<td>` styled to look like a header
   - `scope="col"` on column headers, `scope="row"` on row headers
   - `<thead>` and `<tbody>` (and `<tfoot>` where appropriate)

2. Tables used for layout must have `role="presentation"` or `aria-hidden="true"` — but prefer replacing them with CSS grid or flexbox entirely.

---

## Phase 12 — MEDIUM PRIORITY: Reduced motion (WCAG 2.3.3)

Users with vestibular disorders can be harmed by excessive animation. Every animation must respect `prefers-reduced-motion`.

### 12.1 Global CSS rule

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

If using CSS custom properties for durations (e.g. `--duration-base: 200ms`), redefining the duration tokens to `0ms` inside this media query is preferable — it keeps component code clean.

### 12.2 JavaScript-driven animation

For scroll-triggered reveals, parallax, auto-playing carousels:

```js
const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
if (!prefersReduced) {
  // run the animation
}
```

### 12.3 Auto-playing carousels

Add a pause button and start paused when `prefers-reduced-motion` is set.

---

## Phase 13 — MEDIUM PRIORITY: Touch target sizes

WCAG 2.1 AA (SC 2.5.5 — AAA in 2.1, promoted to AA in WCAG 2.2 as SC 2.5.8) requires interactive targets of at least **24×24 CSS pixels**. The practical mobile minimum is **44×44px** — used by iOS Human Interface Guidelines and Material Design — and this audit holds elements to that target unless the developer explicitly opts to the WCAG-only 24×24 minimum.

1. Find every `<button>`, `<a>`, `<input>`, `<select>`, custom toggle, and icon button.
2. Check the computed height and width. A visually small element can meet the target with padding:

```css
.icon-button {
  min-width: 44px;
  min-height: 44px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}
```

3. Report every element below the chosen minimum and fix with padding rather than changing visual size.

---

## Phase 14 — MEDIUM PRIORITY: Heading hierarchy

Screen readers use headings as a page table of contents. A broken hierarchy is one of the most common failures (WCAG 1.3.1 Info and Relationships).

1. List every heading in document order per template.
2. Check:
   - Exactly one `<h1>` per page — the page's primary topic
   - No skipped levels (H1 → H3 without an H2)
   - Headings used for structure, not visual size
3. Fix violations directly in the templates.

---

## Phase 15 — HIGH PRIORITY: Zoom and reflow (WCAG 1.4.10)

Content must reflow without loss of information or functionality at 320 CSS pixel width (mobile) and up to 400% browser zoom.

1. Test every page at 320px viewport width — must be readable and usable without horizontal scrolling. Horizontal scroll is only permitted on individual wide elements (tables, code blocks, diagrams) inside their own `overflow-x: auto` container.
2. Test at 400% browser zoom on a 1280px viewport — content must reflow to a single column with no clipped text or overlapping elements.
3. Fixed-position headers or overlays that eat viewport space at zoom are a common failure — check they collapse or use dynamic sizing.

### 15.4 Orientation (WCAG 1.3.4, Level AA)

Content must not restrict its view and operation to a single display orientation (portrait or landscape) unless a specific orientation is essential (e.g. a piano app, a cheque-scanning frame).

- Check the CSS for orientation locks — `@media (orientation: portrait)` / `(orientation: landscape)` blocks that hide content or show a "please rotate your device" gate
- Check the PWA manifest — `"orientation": "portrait"` or `"landscape"` locks the installed app. Use `"any"` unless a lock is genuinely essential
- Both portrait and landscape must present the same content and functionality

---

## Phase 16 — HIGH PRIORITY: Text spacing (WCAG 1.4.12)

Users must be able to override text spacing without content being clipped or overlapping. Test with a browser extension or user CSS setting:

- `line-height: 1.5 * font-size`
- `letter-spacing: 0.12 * font-size`
- `word-spacing: 0.16 * font-size`
- Paragraph spacing: `2 * font-size`

Fix any component whose fixed `height` clips text under these settings — replace `height` with `min-height` and let content grow.

---

## Phase 17 — MEDIUM PRIORITY: Time and motion limits

### 17.1 Auto-updating content (WCAG 2.2.4)

Carousels, tickers, news feeds must have controls to pause, stop, or hide the update.

### 17.2 Session timeouts (WCAG 2.2.1)

If the site logs users out after inactivity, warn the user with at least 20 seconds to extend.

### 17.3 No flashing content (WCAG 2.3.1)

No content may flash more than three times per second. This includes attention-grabbing animations, video content (warn about photosensitive content when user-uploaded), and rapidly oscillating loading spinners.

---

## Phase 18 — OPTIONAL: Enhanced screen reader support

These go beyond AA compliance but meaningfully improve the screen reader experience.

### 18.1 Breadcrumbs

```html
<nav aria-label="Breadcrumb">
  <ol>
    <li><a href="/">Home</a></li>
    <li><a href="/products">Products</a></li>
    <li aria-current="page">Widget Pro</li>
  </ol>
</nav>
```

### 18.2 Pagination

Wrap in `<nav aria-label="Pagination">`. Mark current page with `aria-current="page"`. Disabled previous/next: `aria-disabled="true"` on `<a>` tags (or native `disabled` on `<button>`).

### 18.3 Status badges and chips

If a badge communicates status a sighted user reads visually (green "Active" badge), ensure the text label is present — not just the colour dot.

### 18.4 `aria-describedby` for complex fields

If a field has helper text beneath it, link it: `aria-describedby="helper-id"` on the input, `id="helper-id"` on the helper. Screen readers then announce helper text after the label.

### 18.5 PDF and document links

Indicate non-HTML file types in link text or with a visually hidden span:
```html
<a href="/report.pdf">
  Annual Report 2025
  <span class="sr-only">(PDF, opens in new tab)</span>
</a>
```

### 18.6 `target="_blank"`

Links that open a new tab must warn:
```html
<a href="https://example.com" target="_blank" rel="noopener noreferrer">
  Visit our partner site
  <span class="sr-only">(opens in new tab)</span>
</a>
```

---

## Phase 19 — OPTIONAL: High contrast mode (Forced Colors)

Windows High Contrast Mode (Forced Colors) overrides CSS colours with system colours. Components that rely entirely on `background-image`, `box-shadow`, or `filter` for their visual state become invisible.

1. Check every interactive state (focus ring, button hover, checkbox tick, toggle track) for reliance on colour that would be overridden.
2. Use `@media (forced-colors: active)` to restore meaningful indicators:

```css
@media (forced-colors: active) {
  .custom-checkbox::after {
    /* box-shadow is overridden in forced-colors — use border instead */
    border: 2px solid ButtonText;
  }
  :focus-visible {
    outline: 2px solid Highlight;
    outline-offset: 2px;
  }
}
```

---

## Phase 20 — Validation and handoff

### 20.1 Manual keyboard walkthrough

Do a keyboard-only walkthrough of one full user journey per key page. If you can complete the primary action (buy, sign up, contact) using only Tab/Shift-Tab/Enter/Escape/arrow keys, that page passes the keyboard gate. If you can't, name the block.

### 20.2 Screen reader walkthrough

Do a screen reader walkthrough with:
- **NVDA** (Windows, free) — most common testing target
- **VoiceOver** (Mac, built-in) — `Cmd+F5` to toggle
- **Orca** (Linux, built-in)

Test at least: page load announcement (title + landmarks), main navigation, one form submission, one modal open/close.

### 20.3 Re-run automated tools

After fixes:
- axe DevTools — target zero critical/serious issues
- Lighthouse a11y score — target 95+
- Pa11y — clean run in CI

### 20.4 Handoff report

Generate a complete audit summary in this format. Every cell contains a real value — never "see above" or "completed".

```
## Accessibility Audit Report — [Project Name]  [date]  WCAG 2.1 Level AA

### Page structure and landmarks
<html lang>:              ✅ en-ZA on all templates
Skip link:                ✅ implemented on base template
Landmarks:                ✅ header/nav/main/footer on all pages
Unique page titles:       ✅ per-page dynamic
aria-current on nav:      ✅

### Keyboard navigation
Tab order:                ✅ logical, top-left → bottom-right
No tabindex > 0:          ✅
Custom components:        ✅ Enter/Space/arrow/Escape wired
Modal focus trap:         ✅ native <dialog> used

### Focus indicators
outline: none replaced:   ✅ 5 sites patched with box-shadow focus ring
:focus-visible pattern:   ✅

### Images and media
img alt text:             ✅ 12 corrected
SVG icons:                ✅ 8 marked aria-hidden
Video captions:           ✅ / N/A

### Forms
Labels on every input:    ✅
Required indicators:      ✅ visible + sr-only "required"
Error messages linked:    ✅ aria-describedby + aria-invalid
Autocomplete tokens:      ✅

### ARIA states
Accordion:                ✅ aria-expanded toggles
Modal:                    ✅ aria-modal + aria-labelledby
Tabs:                     ✅ role=tablist / tab / tabpanel
Toast:                    ✅ role=status + aria-live=polite

### Colour contrast (WCAG 1.4.3)
Body on bg:               ✅ 13.2:1
Body on surface:          ✅ 10.4:1
Placeholder:              ✅ 4.6:1 (fixed from 2.8:1)
Ghost button:             ✅ 4.7:1 (fixed from 2.4:1)
Semantic colours:         ✅ all pairs ≥ 4.5:1

### Interactive semantics
Label in Name (2.5.3):    ✅ visible text contained in every accessible name
Hover/focus content (1.4.13): ✅ dismissable + hoverable + persistent

### Zoom and reflow
320px width:              ✅ single column, no h-scroll
400% zoom:                ✅ reflows without clipping
Orientation (1.3.4):      ✅ no portrait/landscape lock

### Text spacing (WCAG 1.4.12)
User-override safe:       ✅ min-height used, no clipping

### Reduced motion
@media prefers-reduced:   ✅ tokens redefined to 0ms
JS animations gated:      ✅

### Touch targets
44×44 minimum:            ✅ / ⚠️ [N] icon buttons padded

### Automated tools
axe DevTools:             ✅ 0 critical, 0 serious
Lighthouse a11y:          ✅ 98 / 100
Pa11y:                    ✅ clean

### Manual walkthroughs
Keyboard only:            ✅ full purchase flow completed
Screen reader (NVDA):     ✅ page load + form + modal announced correctly

### Files changed
[List every file that was created or modified]
- src/templates/main.html — lang, skip link, landmarks, aria-current
- src/templates/checkout.html — form labels, aria-describedby errors
- public/css/app.css — focus-visible pattern, prefers-reduced-motion tokens
- public/js/modal.js — replaced manual trap with <dialog>.showModal()
- DESIGN.md — WCAG section appended
```

---

## DESIGN.md accessibility section

Append the following to `design/DESIGN.md` once the audit is complete:

```markdown
## Accessibility (WCAG 2.1 AA)

### Contrast ratios verified
- [pair]: [ratio]  ✅
(repeat for every audited pair)

### Focus ring
Token: --focus-ring
Value: [computed value]
Contrast against adjacent: [ratio] ✅

### Touch target minimum
[24×24 WCAG only / 44×44 mobile best-practice]

### Reduced motion
Duration tokens redefined to 0ms under prefers-reduced-motion.

### Automated tool baseline
axe: 0 critical, 0 serious   Lighthouse: 98/100   Pa11y: clean

### Screen reader coverage
NVDA / VoiceOver walkthroughs completed on [pages listed]

### Key decisions
- [date]: [decision] — [reason]
```

---

## Plan structure

Create `plan/a11y/PLAN.md` in the project:

```markdown
# Accessibility Plan — [Project Name]

**Outcome:** WCAG 2.1 Level AA compliance — page structure, keyboard navigation, focus
indicators, ARIA states, colour contrast, forms, zoom/reflow, reduced motion, touch targets.
Every finding fixed and verified via manual walkthrough + automated tools.

## Scope
- [ ] Phase 1: Discovery audit — current state documented, automated tools run
- [ ] Phase 2: Page structure and landmarks (CRITICAL)
- [ ] Phase 3: Keyboard navigation (CRITICAL)
- [ ] Phase 4: Focus indicators (CRITICAL)
- [ ] Phase 5: Images and non-text content (CRITICAL)
- [ ] Phase 6: Forms (CRITICAL)
- [ ] Phase 7: ARIA states and properties (HIGH)
- [ ] Phase 8: Colour contrast (HIGH)
- [ ] Phase 9: Interactive element semantics — incl. Label in Name (2.5.3) + Content on hover/focus (1.4.13) (HIGH)
- [ ] Phase 10: Live regions and dynamic content (MEDIUM)
- [ ] Phase 11: Tables (MEDIUM)
- [ ] Phase 12: Reduced motion (MEDIUM)
- [ ] Phase 13: Touch target sizes (MEDIUM)
- [ ] Phase 14: Heading hierarchy (MEDIUM)
- [ ] Phase 15: Zoom and reflow — incl. Orientation (1.3.4) (HIGH)
- [ ] Phase 16: Text spacing (HIGH)
- [ ] Phase 17: Time and motion limits (MEDIUM)
- [ ] Phase 18: Enhanced screen reader support (OPTIONAL)
- [ ] Phase 19: High contrast mode (OPTIONAL)
- [ ] Phase 20: Validation and handoff — walkthroughs + report

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
| **tina4-design** | Runs first. tina4-a11y reads DESIGN.md as its source of truth — focus ring token, contrast ratios, touch target minimum, motion personality. Never duplicate intake. |
| **tina4-developer-*** | Implements the template and stylesheet changes. tina4-a11y tells the developer what to add and where; the developer skill handles framework-specific wiring. |
| **tina4-seo** | Runs alongside for complete coverage. Overlap: alt text, semantic HTML, page titles, `<html lang>`. If both are running, do those items once in whichever runs first. tina4-a11y owns keyboard navigation, ARIA, focus, contrast, forms, zoom/reflow. |

## Avoid these defaults

- Do not add `aria-*` attributes as a substitute for semantic HTML — a `<button>` beats `<div role="button">`
- Do not add `tabindex="0"` to make a `<div>` focusable — use a `<button>` instead
- Do not use `title` attributes as tooltips or labels — they are inaccessible
- Do not use `outline: none` without a replacement focus indicator
- Do not rely on colour alone to convey meaning
- Do not implement custom modal focus traps when `<dialog>.showModal()` will do
- Do not run only the automated tools and call the audit done — they catch ~30–40% of issues
- Do not mark an item complete without a manual verification (keyboard walkthrough or screen reader test)
