/* Ask Tina4, the site's chat: the same on the home page and every docs page
   (markup home/chat.html, styles home/chat.css). It asks the hosted RAG whose
   endpoint (CHAT in tina4press.config.mjs) the build writes into data-api on
   .t4-chat: POST {api}/v1/ask { query, language, k, stream:false } ->
   { answer, sources[] }. stream:false because the streamed reply carries no
   sources, and the citations are the point.
   The language: on a language's docs pages (/python/..., /php/...), that
   language; otherwise the one picked on the home page (T4LANG there, the
   "t4-lang" choice it remembers elsewhere), else Python. */
(function(){
  var wrap = document.querySelector(".t4-chat"); if(!wrap) return;
  var btn = wrap.querySelector(".t4-chat-btn"), panel = wrap.querySelector(".t4-chat-panel");
  var log = wrap.querySelector(".t4-chat-log"), form = wrap.querySelector(".t4-chat-form");
  var input = wrap.querySelector(".t4-chat-input"), closeBtn = wrap.querySelector(".t4-chat-close");
  var API = (wrap.getAttribute("data-api") || "https://rag.tina4.com").replace(/\/+$/, "");
  var ASK_PATH = wrap.getAttribute("data-ask-path") || "/v1/ask";
  var NAMES = { python: "Python", php: "PHP", ruby: "Ruby", nodejs: "Node.js" };
  var ASK = ["How do I define a route?", "How do I connect a database?", "How do I add JWT auth?", "How do I run a background job?"];
  var ERROR = "Sorry, the assistant is unreachable right now. The docs have the answer too: try the search on any docs page.";
  var PAGE_LANG = (location.pathname.match(/^\/(python|php|ruby|nodejs)\//) || [])[1] || "";
  function picked(){
    if(window.T4LANG) return T4LANG.get();
    try { var s = localStorage.getItem("t4-lang"); if(/^(python|php|ruby|nodejs)$/.test(s)) return s; } catch(e){}
    return "";
  }
  function lang(){ return PAGE_LANG || picked() || "python"; }
  /* the hello says where the language came from */
  function langReason(){
    if(PAGE_LANG) return "the docs you are reading";
    if(window.T4LANG) return "the language picked on this page";
    return picked() ? "the language you picked on the home page" : "";
  }

  function esc(s){ return String(s).replace(/[&<>"]/g, function(c){ return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  /* a link in an answer must go somewhere ordinary: http(s), or a path on this site */
  function safeUrl(u){
    u = u.replace(/^(?:&lt;|<)+/, "").replace(/(?:&gt;|>)+$/, "").replace(/[.,;:!?]+$/, "");
    return /^https?:\/\//i.test(u) || /^\/(?!\/)/.test(u) ? u : null;
  }
  function linkAttrs(u){ return /^https?:\/\//i.test(u) ? ' target="_blank" rel="noreferrer"' : ""; }
  /* the same small markdown tina4press renders: fenced code, inline code, links,
     bold, line breaks */
  function md(t){
    var h = esc(t);
    h = h.replace(/```[\w-]*\n([\s\S]*?)```/g, function(_, c){ return "<pre><code>" + c.replace(/\n$/, "") + "</code></pre>"; });
    h = h.replace(/`([^`]+)`/g, "<code>$1</code>");
    /* answers use ### headings; a bold line reads right in a chat bubble */
    h = h.split(/(<pre>[\s\S]*?<\/pre>)/).map(function(part){
      return part.indexOf("<pre>") === 0 ? part : part.replace(/^#{1,6}\s+(.+)$/gm, "<strong>$1</strong>");
    }).join("");
    h = h.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, function(all, text, url){
      var u = safeUrl(url); return u ? '<a href="' + u + '"' + linkAttrs(u) + ">" + text + "</a>" : text;
    });
    h = h.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>").replace(/\n/g, "<br>");
    return h.replace(/<pre>([\s\S]*?)<\/pre>/g, function(m){ return m.replace(/<br>/g, "\n"); });
  }
  function add(cls, html){
    var el = document.createElement("div"); el.className = cls; el.innerHTML = html;
    log.appendChild(el); log.scrollTop = log.scrollHeight; return el;
  }
  function suggest(){
    var box = add("t4-chat-suggest", "");
    ASK.forEach(function(q){
      var c = document.createElement("button"); c.type = "button"; c.className = "t4-chat-chip"; c.textContent = q;
      c.addEventListener("click", function(){ box.parentNode && box.parentNode.removeChild(box); ask(q); }); box.appendChild(c);
    });
  }
  /* the structured sources[] become citations: always real URLs, unlike a link an
     answer might mangle. One per URL, without the "(path)" the service appends */
  function sources(list){
    var seen = {}, items = "";
    (list || []).forEach(function(s){
      var u = s && s.url && safeUrl(esc(s.url)); if(!u || seen[u]) return; seen[u] = 1;
      items += '<a class="t4-chat-src" href="' + u + '"' + linkAttrs(u) + ">" + esc((s.title || s.url).replace(/\s*\([^)]*\)\s*$/, "")) + "</a>";
    });
    if(items) add("t4-chat-sources", '<div class="t4-chat-sources-label">Sources</div>' + items);
  }
  function ask(q){
    q = q.trim(); if(!q) return;
    add("t4-chat-msg t4-chat-you", esc(q));
    var thinking = add("t4-chat-msg t4-chat-bot", '<span class="t4-chat-thinking" role="img" aria-label="Thinking"><span></span><span></span><span></span></span>');
    var ctl = window.AbortController ? new AbortController() : null, timer = ctl && setTimeout(function(){ ctl.abort(); }, 45000);
    fetch(API + ASK_PATH, {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ query: q, language: lang(), k: 6, stream: false }),
      signal: ctl ? ctl.signal : undefined
    }).then(function(r){ if(!r.ok) throw new Error("HTTP " + r.status); return r.json(); }).then(function(d){
      thinking.innerHTML = md(d.answer || d.response || d.text || "I found nothing on that in the docs. Try asking it another way.");
      sources(d.sources);
      log.scrollTop = log.scrollHeight;
    }).catch(function(){
      thinking.textContent = ERROR;
    }).then(function(){ if(timer) clearTimeout(timer); });
  }

  var opened = false;
  /* the morph starts from the button's exact pill: hand the CSS its size and its
     offset from the panel's bottom-right corner (both boxes are laid out even while
     the panel is closed, so this measures cleanly either way) */
  function morphFromButton(){
    var b = btn.getBoundingClientRect(), p = panel.getBoundingClientRect();
    if(!b.width || !p.width) return;
    panel.style.setProperty("--bw", Math.round(b.width) + "px");
    panel.style.setProperty("--bh", Math.round(b.height) + "px");
    panel.style.setProperty("--gr", Math.max(0, Math.round(p.right - b.right)) + "px");
    panel.style.setProperty("--gb", Math.max(0, Math.round(p.bottom - b.bottom)) + "px");
  }
  window.addEventListener("resize", morphFromButton);
  function setOpen(on){
    morphFromButton();
    panel.hidden = !on; wrap.classList.toggle("open", on); btn.setAttribute("aria-expanded", on ? "true" : "false");
    if(on){
      if(!opened){                      /* the first time: Tina says hello and offers questions */
        opened = true;
        add("t4-chat-msg t4-chat-bot", md("Hi, I'm Tina. Ask me how to do something in Tina4. I'll answer for **" + NAMES[lang()] + "**" + (langReason() ? ", " + langReason() : "") + "."));
        suggest();
      }
      setTimeout(function(){ input.focus(); }, 30);
    } else btn.focus();
  }
  btn.addEventListener("click", function(){ setOpen(panel.hidden); });
  closeBtn.addEventListener("click", function(){ setOpen(false); });
  var expand = wrap.querySelector(".t4-chat-expand");
  if(expand) expand.addEventListener("click", function(){ var w = wrap.classList.toggle("wide"); expand.setAttribute("aria-pressed", w ? "true" : "false"); expand.setAttribute("aria-label", w ? "Narrower panel" : "Wider panel"); });

  document.addEventListener("keydown", function(e){ if(e.key === "Escape" && !panel.hidden) setOpen(false); });
  form.addEventListener("submit", function(e){ e.preventDefault(); var q = input.value; input.value = ""; ask(q); });
})();
