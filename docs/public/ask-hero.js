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
  function md(t) {
    var h = esc(t);

    // 1) lift fenced blocks out, leaving an inert placeholder behind
    var blocks = [];
    h = h.replace(/```(\w*)\r?\n([\s\S]*?)```/g, function (_, lang, code) {
      blocks.push(code.replace(/\s+$/, ""));
      return "\u0000BLOCK" + (blocks.length - 1) + "\u0000";
    });

    // 2) inline formatting on the prose only
    h = h.replace(/`([^`\n]+)`/g, "<code>$1</code>");
    h = h.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, '<a href="$2">$1</a>');
    h = h.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");

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
      return "<pre><code>" + blocks[Number(i)] + "</code></pre>";
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
