/* Ask Tina4 on the landing page.
 *
 * Answers render INLINE, under the search box. The floating chat panel is left
 * alone: a reader who asks from the hero stays on the page and reads the answer
 * where they are, rather than being thrown into a corner popup.
 *
 * It reads its endpoint from window.__TP_CHAT__, the SAME object tina4press
 * builds for the floating widget from themeConfig.chat. So the api URL, the ask
 * path and the language hint have ONE definition: change themeConfig.chat and
 * both surfaces follow. Only the rendering is local, because the widget draws
 * into its own panel and this has to draw into the page.
 *
 * Loaded with <script src> from docs/public/ rather than inlined in index.md
 * ON PURPOSE: tina4press runs the markdown processor over the contents of an
 * inline <script>, wrapping the JS in <p> tags so it never executes. A tag with
 * no inner content cannot be mangled.
 */
(function () {
  "use strict";

  var PILLS = [
    "How do I define a route?",
    "How do I connect a database?",
    "How do I add JWT auth?",
    "How do I run a background job?",
    "How do I deploy with Docker?",
  ];

  function ready(fn) {
    if (document.readyState !== "loading") fn();
    else document.addEventListener("DOMContentLoaded", fn);
  }

  function esc(s) {
    return String(s).replace(/[&<>]/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c];
    });
  }

  /* Minimal markdown: fenced code, inline code, links, bold, paragraphs.
     Everything is escaped FIRST, so nothing in a RAG answer can inject markup
     into the page.

     Code blocks are LIFTED OUT before any prose formatting and put back
     afterwards. The obvious approach - replace every \n with <br>, then undo it
     inside <pre> - is what the widget does, and it is why answers arrived full
     of gaps: <pre> is already a block element with its own margins, so the
     stray <br> either side of a fence stacked on top of that and opened a
     canyon around every sample. Blank lines between paragraphs doubled up the
     same way. Lifting the blocks out means prose never sees the code's
     newlines, and the code never sees a <br>. */

  /* Syntax highlighting that reuses the SITE'S OWN token classes.
     tina4press highlights fenced code at BUILD time, so a runtime answer got
     none. Rather than ship a palette, this emits the same tk-* spans the build
     emits (tk-keyword, tk-string, tk-number, tk-comment, tk-fn). Those classes
     are styled globally in theme.css from CSS variables, so the colours match
     the rest of the site and follow the light/dark toggle for free.

     It runs over ALREADY-ESCAPED text, so entities are stepped over as opaque
     units and no span can ever be opened inside one. */

  /* Inline SVG, not an icon font or an image: no extra request, it inherits
     currentColor so it follows the theme and the copied state for free. */
  var ICON_COPY = '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" ' +
    'stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" ' +
    'aria-hidden="true"><rect x="9" y="9" width="11" height="11" rx="2"></rect>' +
    '<path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>';
  var ICON_DONE = '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" ' +
    'stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" ' +
    'aria-hidden="true"><path d="M20 6L9 17l-5-5"></path></svg>';

  var KEYWORDS = {
    php: "function class public private protected static return if else elseif for foreach while do switch case break continue new echo print try catch finally throw namespace use extends implements interface trait abstract final const var global instanceof as fn match null true false",
    python: "def class return if elif else for while import from as try except finally raise with async await lambda pass break continue global nonlocal yield in is not and or None True False self",
    javascript: "function class return if else for while do switch case break continue new const let var import export from default extends async await yield try catch finally throw typeof instanceof in of null undefined true false this super static get set",
    ruby: "def class module return if elsif else unless while until for do end begin rescue ensure raise yield require require_relative attr_accessor attr_reader attr_writer self nil true false and or not then case when next break",
    bash: "if then else elif fi for while do done case esac function return export local echo cd exit source set unset in"
  };
  KEYWORDS.js = KEYWORDS.javascript;
  KEYWORDS.ts = KEYWORDS.typescript = KEYWORDS.javascript;
  KEYWORDS.py = KEYWORDS.python;
  KEYWORDS.rb = KEYWORDS.ruby;
  KEYWORDS.sh = KEYWORDS.shell = KEYWORDS.bash;

  function highlight(code, lang) {
    var words = KEYWORDS[(lang || "").toLowerCase()];
    if (!words) return code;                 // unknown language: leave it plain
    var kw = Object.create(null);
    words.split(" ").forEach(function (w) { kw[w] = 1; });

    var out = "", i = 0, n = code.length;
    function span(cls, text) { return '<span class="tk-' + cls + '">' + text + "</span>"; }

    while (i < n) {
      var c = code[i];

      // an HTML entity is one opaque unit - never split it
      if (c === "&") {
        var semi = code.indexOf(";", i);
        if (semi > -1 && semi - i <= 6) { out += code.slice(i, semi + 1); i = semi + 1; continue; }
      }

      // comments
      if (code.startsWith("//", i) || c === "#") {
        var eol = code.indexOf("\n", i); if (eol === -1) eol = n;
        out += span("comment", code.slice(i, eol)); i = eol; continue;
      }
      if (code.startsWith("/*", i)) {
        var close = code.indexOf("*/", i); close = close === -1 ? n : close + 2;
        out += span("comment", code.slice(i, close)); i = close; continue;
      }

      // strings (single or double, backslash escapes respected)
      if (c === '"' || c === "'") {
        var j = i + 1;
        while (j < n && code[j] !== c) { if (code[j] === "\\") j++; j++; }
        out += span("string", code.slice(i, Math.min(j + 1, n))); i = j + 1; continue;
      }

      // numbers
      if (/[0-9]/.test(c) && !/[\w$]/.test(code[i - 1] || "")) {
        var m = /^[0-9][0-9_.]*/.exec(code.slice(i));
        out += span("number", m[0]); i += m[0].length; continue;
      }

      // identifiers: keyword, or a function name when followed by (
      if (/[A-Za-z_$]/.test(c)) {
        var id = /^[A-Za-z0-9_$]+/.exec(code.slice(i))[0];
        var after = code.slice(i + id.length);
        if (kw[id]) out += span("keyword", id);
        else if (/^\s*\(/.test(after)) out += span("fn", id);
        else out += id;
        i += id.length; continue;
      }

      out += c; i++;
    }
    return out;
  }

  function md(t) {
    var h = esc(t);

    // 1) lift fenced blocks out, leaving an inert placeholder behind
    var blocks = [];
    h = h.replace(/```(\w*)\r?\n([\s\S]*?)```/g, function (_, lang, code) {
      blocks.push({ code: code.replace(/\s+$/, ""), lang: lang });
      return "\u0000BLOCK" + (blocks.length - 1) + "\u0000";
    });

    // 2) inline formatting on the prose only
    h = h.replace(/`([^`\n]+)`/g, "<code>$1</code>");
    h = h.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, '<a href="$2">$1</a>');
    h = h.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");

    // 2b) ATX headings: lift to top-level blocks (a heading inside a <p> is
    //     invalid - the browser closes the paragraph early, the same trap the
    //     fenced blocks avoid). RAG answers use ### for their sub-sections.
    h = h.replace(/^[ \t]*(#{1,6})[ \t]+(.+?)[ \t]*#*[ \t]*$/gm, function (_, hashes, text) {
      blocks.push({ heading: text.trim(), level: hashes.length });
      return "\u0000BLOCK" + (blocks.length - 1) + "\u0000";
    });

    // 3) paragraphs: a blank line starts one, a single newline is a soft break.
    //    Each chunk is split around its placeholders so a block is ALWAYS
    //    emitted at top level. A <pre> inside a <p> is invalid: the browser
    //    auto-closes the paragraph early, reopening the very gap this is meant
    //    to remove. A fence mid-sentence is common in RAG answers.
    var out = h.split(/\n{2,}/).map(function (part) {
      part = part.trim();
      if (!part) return "";
      return part.split(/(\u0000BLOCK\d+\u0000)/).map(function (seg) {
        if (!seg) return "";
        if (/^\u0000BLOCK\d+\u0000$/.test(seg)) return seg;
        seg = seg.trim();
        return seg ? "<p>" + seg.replace(/\n/g, "<br>") + "</p>" : "";
      }).join("");
    }).join("");

    // 4) put the code back
    return out.replace(/\u0000BLOCK(\d+)\u0000/g, function (_, i) {
      var b = blocks[Number(i)];
      if (b.heading !== undefined) {
        return "<h" + b.level + ">" + b.heading + "</h" + b.level + ">";
      }
      // Same shell the build emits: a .tp-code wrapper with a .tp-copy button
      // as a SIBLING of <pre>. That inherits the theme's copy styling, and the
      // handler below mirrors what client.js binds - it cannot bind these
      // itself because it runs on load and these blocks arrive later.
      return '<div class="tp-code">' +
             '<button class="tp-copy" type="button" aria-label="Copy code" title="Copy code">' + ICON_COPY + '</button>' +
             "<pre><code>" + highlight(b.code, b.lang) + "</code></pre></div>";
    });
  }

  ready(function () {
    var form = document.querySelector(".tp-ask-hero-form");
    if (!form) return; // not the landing page
    var box = form.querySelector(".tp-ask-hero-input");
    var pillWrap = document.querySelector(".tp-ask-pills");
    var out = document.querySelector(".tp-ask-answer");

    // ---- suggestion pills -------------------------------------------------
    // Built here rather than written into index.md so the list lives in one
    // place and the markup cannot drift from the behaviour.
    if (pillWrap) {
      PILLS.forEach(function (text) {
        var b = document.createElement("button");
        b.type = "button";
        b.className = "tp-ask-pill";
        b.textContent = text;
        b.addEventListener("click", function () {
          box.value = text;
          box.focus();
          // Autocomplete only. The reader may want to edit it, and submitting
          // on click would take that choice away.
        });
        pillWrap.appendChild(b);
      });
    }

    if (!out) return;

    function show(html, state) {
      out.className = "tp-ask-answer" + (state ? " is-" + state : "");
      out.innerHTML = html;
      out.hidden = false;
      bindCopy();
    }

    // client.js binds .tp-copy once on load, over the blocks the BUILD wrote.
    // These arrive at runtime, long after, so they need binding here. Same
    // behaviour: copy the pre's text, confirm, revert after a moment.
    function bindCopy() {
      out.querySelectorAll(".tp-copy").forEach(function (btn) {
        btn.addEventListener("click", function () {
          var pre = btn.parentElement.querySelector("pre");
          var text = pre ? pre.innerText : "";
          if (!navigator.clipboard) return;
          navigator.clipboard.writeText(text).then(function () {
            btn.innerHTML = ICON_DONE;
            btn.setAttribute("aria-label", "Copied");
            btn.classList.add("tp-copied");
            setTimeout(function () {
              btn.innerHTML = ICON_COPY;
              btn.setAttribute("aria-label", "Copy code");
              btn.classList.remove("tp-copied");
            }, 1400);
          });
        });
      });
    }

    var inFlight = false;

    form.addEventListener("submit", function (e) {
      e.preventDefault();
      var q = (box.value || "").trim();
      if (!q) { box.focus(); return; }
      // A second submit while the first is still open would race two answers
      // into the same container, and the slower one would win.
      if (inFlight) return;

      var cfg = window.__TP_CHAT__;
      if (!cfg || !cfg.api) {
        // Chat disabled in config. Send the reader somewhere useful rather
        // than swallowing the question.
        window.location.href = "/get-started";
        return;
      }

      var api = String(cfg.api).replace(/\/+$/, "");
      var askPath = cfg.askPath || "/v1/ask";
      var lang = cfg.language || (location.pathname.match(/^\/([^/]+)\//) || [])[1] || "";

      inFlight = true;
      show('<div class="tp-ask-q">' + esc(q) + "</div>" +
           '<div class="tp-ask-thinking">Thinking...</div>', "loading");

      fetch(api + askPath, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ query: q, language: lang || undefined, k: 6, stream: false }),
      })
        .then(function (r) { return r.json(); })
        .then(function (d) {
          var answer = d.answer || d.response || d.text || "(no answer)";
          show('<div class="tp-ask-q">' + esc(q) + "</div>" +
               '<div class="tp-ask-a">' + md(answer) + "</div>", "done");
        })
        .catch(function () {
          show('<div class="tp-ask-q">' + esc(q) + "</div>" +
               '<div class="tp-ask-a">Sorry, the assistant is unreachable right now. ' +
               'The <a href="/get-started">Get Started</a> guide covers the basics.</div>', "error");
        })
        .then(function () { inFlight = false; });
    });
  });
})();
