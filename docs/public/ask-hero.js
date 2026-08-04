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

  /* Minimal markdown: fenced code, inline code, links, bold, line breaks.
     Mirrors the widget's own renderer so an answer reads the same in both
     places. Everything is escaped FIRST, so nothing in a RAG answer can inject
     markup into the page. */
  function md(t) {
    var h = esc(t);
    h = h.replace(/```(\w*)\n([\s\S]*?)```/g, function (_, lang, code) {
      return "<pre><code>" + code.replace(/\n$/, "") + "</code></pre>";
    });
    h = h.replace(/`([^`]+)`/g, "<code>$1</code>");
    h = h.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, '<a href="$2">$1</a>');
    h = h.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
    h = h.replace(/\n/g, "<br>");
    // Undo the <br> substitution inside code blocks, where newlines are real.
    return h.replace(/<pre>([\s\S]*?)<\/pre>/g, function (m) {
      return m.replace(/<br>/g, "\n");
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
