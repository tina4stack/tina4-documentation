/* Ask Tina4 on the landing page.
 *
 * Drives the EXISTING floating chat widget rather than talking to the RAG a
 * second time. tina4press injects .tp-chat into document.body from
 * themeConfig.chat, so a question typed up here is handed to that widget: same
 * endpoint, same answer rendering, same conversation thread. A second fetch
 * client would mean two things to keep in step and answers that format
 * differently depending on which box you used.
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

  ready(function () {
    var form = document.querySelector(".tp-ask-hero-form");
    if (!form) return; // not the landing page
    var box = form.querySelector(".tp-ask-hero-input");
    var pillWrap = document.querySelector(".tp-ask-pills");

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
          // Autocomplete the input, do not fire the question. The reader may
          // want to edit it, and submitting on click would take the choice away.
        });
        pillWrap.appendChild(b);
      });
    }

    // ---- hand the question to the real chat widget ------------------------
    form.addEventListener("submit", function (e) {
      e.preventDefault();
      var q = (box.value || "").trim();
      if (!q) { box.focus(); return; }

      var panel = document.querySelector(".tp-chat-panel");
      var chatForm = document.querySelector(".tp-chat-form");
      var chatInput = document.querySelector(".tp-chat-input");
      var chatBtn = document.querySelector(".tp-chat-btn");

      // Absent only if the chat is disabled in config or its script failed.
      // Send the reader somewhere useful instead of swallowing the question.
      if (!panel || !chatForm || !chatInput) {
        window.location.href = "/get-started";
        return;
      }

      if (panel.hidden && chatBtn) chatBtn.click(); // open it exactly as a click does
      chatInput.value = q;
      box.value = "";

      // requestSubmit runs the widget's own submit handler AND its validation.
      // Dispatching a bare "submit" event skips validation in some browsers.
      if (chatForm.requestSubmit) chatForm.requestSubmit();
      else chatForm.dispatchEvent(new Event("submit", { cancelable: true, bubbles: true }));
    });
  });
})();
