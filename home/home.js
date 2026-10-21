/* tina4.com home page. Served at /assets/home/home.js by scripts/build-home.mjs;
   the page itself is home/index.html. No dependencies. This script talks to one
   outside service: the Ask Tina4 chat (rag.tina4.com, the same as the docs widget). */
var ASSET = "/assets/home/";
var REDUCE = window.matchMedia && matchMedia("(prefers-reduced-motion: reduce)").matches;

/* one language choice for the whole page: pick Ruby in any tabbed section and every
   section follows, remembered for the next visit (per browser, a convenience only) */
var T4LANG = (function(){
  var subs = [], cur = "python";
  try { var s = localStorage.getItem("t4-lang"); if(/^(python|php|ruby|nodejs)$/.test(s)) cur = s; } catch(e){}
  return {
    get: function(){ return cur; },
    set: function(l){ if(l === cur) return; cur = l;
      try { localStorage.setItem("t4-lang", l); } catch(e){}
      subs.forEach(function(f){ f(l); }); },
    on: function(f){ subs.push(f); }
  };
})();

/* ---------- big, tall screens: the stat strip joins the bottom of the hero ---------- */
(function(){
  var hero = document.querySelector(".hero"), strip = document.querySelector(".stat-strip");
  if(!hero || !strip || !window.matchMedia) return;
  var home = strip.parentNode, next = strip.nextSibling, mq = matchMedia("(min-width:1500px) and (min-height:800px)");
  function place(){
    var inHero = strip.parentNode === hero;
    if(mq.matches && !inHero){ hero.appendChild(strip); hero.classList.add("has-stats"); }
    else if(!mq.matches && inHero){ home.insertBefore(strip, next); hero.classList.remove("has-stats"); }
  }
  place();
  if(mq.addEventListener) mq.addEventListener("change", place); else if(mq.addListener) mq.addListener(place);
})();

/* ---------- A: the living dependency tangle that resolves to one clean node ---------- */
(function(){
  var svg = document.getElementById("tangle"); if(!svg) return;
  var hero = svg.parentNode, cap = document.getElementById("tangle-cap");
  var robot = document.querySelector(".hero-robot");
  var NS = "http://www.w3.org/2000/svg";

  /* ---------- the robot rig ----------
     tina4-robot.svg is the SVGator robot with its runtime stripped and each part
     tagged (tools/build-robot-rig.js). Here the idle motion is replayed from
     SVGator's own keyframes, and gaze is layered on top: the eyes (the pixel "4")
     and head turn toward the mouse while it moves, otherwise toward the orange dot. */
  var rig = null, mouse = { x:0, y:0, t:-1e9 };
  var LOOP = 17000;
  var KEYS = {   /* [ms, value] or [ms, x, y]; pivot c = the part's frame-0 origin */
    robot: { c:[308.7976,308.8681],
      o:[[0,308.7976,308.8681],[3800,308.7976,308.8681],[5300,320.5269,304.6968],[6400,320.5269,304.6968],[8900,315.5592,322.5162],[11500,296.0022,322.5162],[13600,312.3473,309.9592],[17000,308.7976,308.8681]],
      r:[[0,2.2355],[3800,6.2206],[5300,4.5221],[10800,4.5221],[13200,11.4973],[15400,5.2265],[17000,2.2355]] },
    head: { c:[319.6143,342.8209],
      o:[[0,319.6143,342.8209],[1600,319.8844,330.8277],[4000,305.9402,342.4333],[6400,318.2145,337.4614],[7800,319.2086,319.5343],[12400,327.7177,334.0645],[13900,315.4647,337.4101],[17000,319.6143,342.8209]],
      r:[[0,0],[1000,1.4203],[2400,4.6374],[4600,-6.6001],[5800,-.1456],[8600,3.2716],[11700,-8.4252],[13600,-5.559],[17000,0]] },
    "arm-l": { c:[249.1155,386.3], r:[[0,0],[3400,-7.5094],[6200,-3.9206],[10000,1.1389],[13700,-12.0434],[15300,-17.2728],[17000,0]] },
    "arm-r": { c:[380.9061,374.9446], r:[[0,-2.6686],[5000,8.79],[7800,2.6299],[9300,1.0186],[11600,-1.8989],[13700,3.8143],[15300,-1.4152],[17000,-2.6686]] }
  };
  function smooth(u){ return u*u*(3 - 2*u); }
  function key(arr, t, k){                    /* value of component k at time t, eased per segment */
    for(var i=1;i<arr.length;i++){
      if(t <= arr[i][0]){ var a = arr[i-1], b = arr[i], u = smooth((t - a[0])/(b[0] - a[0])); return a[k] + (b[k] - a[k])*u; }
    }
    return arr[arr.length-1][k];
  }
  function makeRig(root){
    var parts = {};
    ["robot","head","arm-l","arm-r","halo","eyes","shadow","shell","visor","eyes-clip"].forEach(function(n){
      var el = root.querySelector('[data-rig="' + n + '"]');
      parts[n] = { el: el, base: (el && el.getAttribute("transform")) || "" };
    });
    /* highlights: a dozen small sheen shapes that stay with the light during a turn */
    var hls = Array.prototype.map.call(root.querySelectorAll('[data-rig="hl"]'), function(el){
      return { el: el, base: el.getAttribute("transform") || "" };
    });
    /* the two round "ears" are part of the head, so they move exactly with the shell */
    var ears = Array.prototype.map.call(root.querySelectorAll('[data-rig="ear"]'), function(el){
      return { el: el, base: el.getAttribute("transform") || "" };
    });
    function centre(P, fallback){
      try{ var b = P.el.getBBox(); return [b.x + b.width/2, b.y + b.height/2]; }catch(e){ return fallback; }
    }
    var cShell = parts.shell.el ? centre(parts.shell, [320,250]) : [320,250];
    var cVisor = parts.visor.el ? centre(parts.visor, [320,250]) : [320,250];
    var cEyes  = parts.eyes.el  ? centre(parts.eyes,  [300,250]) : [300,250];
    function scaleAbout(c, sx, sy){
      return "translate(" + c[0].toFixed(1) + "," + c[1].toFixed(1) + ") scale(" + sx.toFixed(4) + "," + sy.toFixed(4) +
             ") translate(" + (-c[0]).toFixed(1) + "," + (-c[1]).toFixed(1) + ")";
    }
    function setT(P, str){ if(P && P.el) P.el.setAttribute("transform", str + " " + P.base); }
    /* real head turn: when the rig carries a designer pose, every head shape (and the
       visor clip) morphs toward it: data-d1 for a right turn, data-d2 (mirrored) for
       a left one. The shapes share one point structure, so it is a straight lerp. */
    var NUMS = /-?(?:\d+\.?\d*|\.\d+)/g;
    var allMorphs = Array.prototype.map.call(root.querySelectorAll("[data-d1]"), function(el){
      var d0 = el.getAttribute("d");
      return { el: el, cmds: d0.match(/[MLCZ]/g), a: d0.match(NUMS).map(Number), body: el.getAttribute("data-mg") === "body",
               r: el.getAttribute("data-d1").match(NUMS).map(Number),
               l: el.hasAttribute("data-d2") ? el.getAttribute("data-d2").match(NUMS).map(Number) : null,
               u: el.hasAttribute("data-du") ? el.getAttribute("data-du").match(NUMS).map(Number) : null,
               dn: el.hasAttribute("data-dd") ? el.getAttribute("data-dd").match(NUMS).map(Number) : null };
    });
    /* the body's shapes (data-mg="body", from the designer's body pose) morph on their
       own, slower clock so the torso follows the head a beat later */
    var morphs = allMorphs.filter(function(m){ return !m.body; }),
        bodyMorphs = allMorphs.filter(function(m){ return m.body; }), bodyM = 0, lastBM = 0;
    /* right turn morphs when there is a pose; the left only with its own pose
       (head-turn-left.svg), otherwise the left side keeps the 2.5D layer turn */
    var morphR = morphs.length > 0, morphL = morphR && !!morphs[0].l, lastM = 0;
    /* the tilt poses (head-look-up.svg, head-look-down.svg): the head looks up or down
       for real, and the tilt is added on top of the turn, so up-right is both at once */
    var morphU = morphR && !!morphs[0].u, morphDn = morphR && !!morphs[0].dn, lastV = 0;
    function morphD(m, t, v){
      /* no left pose: m.l is null; the caller then passes t = 0, so any target
         gives the front shape. Fall back to m.r rather than dereference null.
         v: the tilt, -1 up .. 1 down (shapes without that pose ignore it) */
      var src = t > 0 ? m.r : (m.l || m.r), w = Math.abs(t), out = "", p = 0;
      var vs = v < 0 ? m.u : m.dn, vw = vs ? Math.abs(v) : 0;
      for(var c=0;c<m.cmds.length;c++){
        var k = m.cmds[c], n = k === "C" ? 6 : k === "Z" ? 0 : 2; out += k;
        for(var j=0;j<n;j++,p++){
          var a0 = m.a[p], val = a0 + (src[p] - a0)*w;
          if(vw) val += (vs[p] - a0)*vw;
          out += (j % 2 ? "," : (j ? " " : "")) + val.toFixed(2);
        }
      }
      return out;
    }
    var g = { ex:0, ey:0, tilt:0, lift:0, turn:0, pitch:0 }, lastT = null, ackAt = -1e9, nextBlink = 3000 + Math.random()*3000;

    function pose(name, extraR, extraTx, extraTy, tl){
      var P = parts[name], K = KEYS[name]; if(!P.el) return 0;
      var dr = key(K.r, tl, 1) - K.r[0][1], dx = 0, dy = 0;
      if(K.o){ dx = key(K.o, tl, 1) - K.o[0][1]; dy = key(K.o, tl, 2) - K.o[0][2]; }
      if(name === "head") dr *= .5;             /* calmer idle head: the gaze does the looking */
      var r = dr + (extraR || 0);
      P.el.setAttribute("transform", "translate(" + (dx + (extraTx||0)).toFixed(2) + "," + (dy + (extraTy||0)).toFixed(2) + ") rotate(" +
        r.toFixed(2) + " " + K.c[0] + " " + K.c[1] + ") " + P.base);
      return r;
    }

    var seenAt = -1e9, seenX = 0, seenY = 0;   /* where and when Tina last saw the dot */
    /* the halo's five rings, inner to outer: degrees a second (negative turns the
       other way) and depth z (-1 back .. 1 front). Not ordered by radius, so the
       depth reads as layers rather than a cone */
    var C_HALO = [308.7976, 308.8681];
    var RINGS = [{ spd:9, z:-1 }, { spd:-14, z:.5 }, { spd:21, z:-.4 }, { spd:-11, z:1 }, { spd:6, z:-.75 }];
    var rings = Array.prototype.map.call(root.querySelectorAll('[data-rig="ring"]'), function(el){
      var cfg = RINGS[+el.getAttribute("data-ring")] || { spd:10, z:0 };
      el.style.opacity = (.72 + .28*(cfg.z + 1)/2).toFixed(2);
      if(cfg.z <= -.7) el.setAttribute("filter", "url(#rb-ring-blur)");
      return { el: el, spd: cfg.spd, z: cfg.z, a0: Math.random()*360 };
    });
    return { update: function(t, bxN, byN, free, bz){
      var dt = lastT === null ? 16 : Math.min(50, t - lastT); lastT = t;
      var tl = t % LOOP;

      /* where is the head on screen, and what is it looking at? */
      var hr = hero.getBoundingClientRect(), rr = robot.getBoundingClientRect();
      var ox = rr.left - hr.left + rr.width*.52, oy = rr.top - hr.top + rr.height*.37;
      var useMouse = performance.now() - mouse.t < 1800;
      /* Tina can only see the dot while it is in front of her (bz > 0). When it passes
         behind, she keeps looking where it disappeared for a moment, then gives up
         and looks ahead; when it comes round in front again she picks it back up */
      var sees = free > .05 && bz > .02;
      if(sees){ seenAt = t; seenX = bxN; seenY = byN; }
      var tx2, ty2;
      if(useMouse){ tx2 = mouse.x - hr.left; ty2 = mouse.y - hr.top; }
      else if(sees){ tx2 = bxN; ty2 = byN; }
      else if(t - seenAt < 700){ tx2 = seenX; ty2 = seenY; }
      else { tx2 = ox; ty2 = oy + 40; }                              /* nothing to see: look ahead, slightly down */
      var vx = tx2 - ox, vy = ty2 - oy, d = Math.sqrt(vx*vx + vy*vy), nx = vx/(d + 140), ny = vy/(d + 140);

      /* the orange dot passing close earns a blink and a little wiggle (with a cooldown) */
      var bd = Math.hypot(bxN - ox, byN - oy);
      if(sees && free > .6 && bd < rr.width*.45 && t - ackAt > 6000) ackAt = t;   /* the orbit passes often */
      var ack = Math.max(0, 1 - (t - ackAt)/450), wig = Math.sin((1 - ack)*Math.PI*2)*ack*4;

      /* ease toward the target: eyes are quick, the head follows */
      var ke = 1 - Math.exp(-dt/110), kh = 1 - Math.exp(-dt/320);
      var morphSide = nx >= 0 ? morphR : morphL;
      g.ex += (nx*(morphSide ? 5 : 16) - g.ex)*ke; /* on a morphing side the pose carries the 4 */
      var vSide = ny < 0 ? morphU : morphDn;      /* with a tilt pose, it carries the 4 up and down too */
      g.ey += ((vSide ? Math.max(-2, Math.min(3, ny*4)) : Math.max(-6, Math.min(8, ny*12))) - g.ey)*ke;
      g.tilt += (nx*4 - g.tilt)*kh;               /* less tilt: the turn does the work */
      g.lift += (ny*3 - g.lift)*kh;
      g.turn += (nx - g.turn)*kh;                 /* -1 full left .. 1 full right */
      g.pitch += (ny - g.pitch)*kh;

      pose("robot", 0, 0, 0, tl);
      var headR = pose("head", g.tilt + wig, nx*2, g.lift, tl);

      /* 2.5D turn: the front of the face travels further than the back of the skull,
         and parts nearing the edge foreshorten. Shell least, visor more, the "4" most;
         highlights slide against the turn because the light source stays put. */
      var tu = g.turn, pi = g.pitch, at = Math.abs(tu), ap = Math.abs(pi);
      var turnMorphs = tu >= 0 ? morphR : morphL;
      var tiltMorphs = pi < 0 ? morphU : morphDn;
      if(morphR){
        /* a side without its own pose stays at the front shape (t = 0); the same for
           a tilt direction without its pose (v = 0) */
        var tm = turnMorphs ? Math.max(-1, Math.min(1, tu*1.25)) : 0;
        var vm = tiltMorphs ? Math.max(-1, Math.min(1, pi*1.6)) : 0;
        if(Math.abs(tm - lastM) > .004 || Math.abs(vm - lastV) > .004 || (tm === 0 && lastM !== 0) || (vm === 0 && lastV !== 0)){
          lastM = tm; lastV = vm; for(var mi=0;mi<morphs.length;mi++) morphs[mi].el.setAttribute("d", morphD(morphs[mi], tm, vm));
        }
      }
      if(bodyMorphs.length){
        /* right turn only (there is no left body pose); the body lags the head */
        bodyM += (Math.max(0, Math.min(1, tu*1.25)) - bodyM)*(1 - Math.exp(-dt/450));
        if(Math.abs(bodyM - lastBM) > .004 || (bodyM < .002 && lastBM !== 0)){
          if(bodyM < .002) bodyM = 0;
          lastBM = bodyM; for(var bm=0;bm<bodyMorphs.length;bm++) bodyMorphs[bm].el.setAttribute("d", morphD(bodyMorphs[bm], bodyM));
        }
      }
      /* the 2.5D layer tricks, only for a direction with no pose of its own */
      var hx = turnMorphs ? 0 : tu, hax = turnMorphs ? 0 : at, hy = tiltMorphs ? 0 : pi, hay = tiltMorphs ? 0 : ap;
      var shellT = "translate(" + (hx*3).toFixed(2) + "," + (hy*1.5).toFixed(2) + ") " + scaleAbout(cShell, 1 - .05*hax, 1 - .03*hay);
      setT(parts.shell, shellT);
      for(var ei=0;ei<ears.length;ei++) ears[ei].el.setAttribute("transform", shellT + " " + ears[ei].base);
      var visorT = "translate(" + (hx*9).toFixed(2) + "," + (hy*4).toFixed(2) + ") " + scaleAbout(cVisor, 1 - .07*hax, 1 - .04*hay);
      setT(parts.visor, visorT);
      setT(parts["eyes-clip"], visorT);          /* the visor clip travels with the glass */
      for(var hi=0;hi<hls.length;hi++){
        hls[hi].el.setAttribute("transform", "translate(" + (-hx*3.5).toFixed(2) + "," + (-hy*2).toFixed(2) + ") " + hls[hi].base);
      }
      pose("arm-l", 0, 0, 0, tl);
      pose("arm-r", 0, 0, 0, tl);
      /* the circuit rings: each turns at its own speed (some against the others) and
         sits at its own depth. Front rings are a touch larger and brighter, back
         rings smaller, dimmer and softly blurred, and on mouse parallax (plus a slow
         idle sway) the front ones slide further than the back ones */
      var sec = t/1000;
      for(var ri=0;ri<rings.length;ri++){
        var R = rings[ri], z = R.z;
        var px = (par.x*9 + Math.sin(sec*.35 + ri*1.7)*2)*z, py = (par.y*6 + Math.cos(sec*.3 + ri*2.3)*1.5)*z;
        R.el.setAttribute("transform", "translate(" + px.toFixed(2) + "," + py.toFixed(2) + ") rotate(" +
          ((R.a0 + sec*R.spd) % 360).toFixed(2) + " " + C_HALO[0] + " " + C_HALO[1] + ") " +
          scaleAbout(C_HALO, 1 + .035*z, 1 + .035*z));
      }
      if(parts.eyes.el){
        parts.eyes.el.setAttribute("transform", "translate(" + g.ex.toFixed(2) + "," + g.ey.toFixed(2) + ") " + scaleAbout(cEyes, 1 - .14*hax, 1));
        /* occasional idle blink, plus the acknowledgement blink */
        var blink = 0;
        if(t > nextBlink){ blink = Math.max(0, 1 - (t - nextBlink)/160); if(t - nextBlink > 160) nextBlink = t + 4000 + Math.random()*4000; }
        parts.eyes.el.style.opacity = (1 - .75*Math.max(blink, Math.sin(ack*Math.PI))).toFixed(3);
      }
      if(parts.shadow.el) parts.shadow.el.style.opacity = Math.max(.5, .95 - Math.abs(headR)*.035).toFixed(3);
    }};
  }
  if(!REDUCE && robot && window.fetch){
    window.addEventListener("mousemove", function(ev){ mouse.x = ev.clientX; mouse.y = ev.clientY; mouse.t = performance.now(); }, { passive:true });
    document.addEventListener("mouseleave", function(){ mouse.t = -1e9; });
    fetch(ASSET + "tina4-robot.svg", { cache: "no-cache" }).then(function(r){ if(!r.ok) throw 0; return r.text(); }).then(function(txt){
      robot.innerHTML = txt;
      var root = robot.querySelector("svg");
      if(root) rig = makeRig(root);
    }).catch(function(){ /* keep the static robot */ });
  }
  var W, H, mob, nodes, linkable, spokes, threads, G, pools, beacon, beaconGlow,
      roam, tx, ty, rw = 300, raf = null, visible = true, par = { x:0, y:0 },
      frontSvg = document.getElementById("tangle-front"), frontG = null, beaconFront = false,
      aware = 0, bp = null, pulseAt = -1e9, lastDraw = null,   /* the beacon's mouse awareness and spring state */
      BEACON_K = 3.1324,                                        /* beacon-dot.png: image size over disc size */
      exAt = -1, exNext = -1,                                   /* the beacon's trips into the tangle (seconds) */
      snaps = {}, sparks = [], frameNo = 0, nowT = 0, dtF = 16; /* links it has snapped, and their flashes */
  var bgWrap = hero.querySelector(".hero-bg"), bgMain = hero.querySelector(".hb-main");
  var bootEl = document.getElementById("boot");

  /* ---------- the intro timeline (ms on the hero's own clock) ----------
     1. BOOT: `tina4 serve` types itself in the robot's spot and the dev server's
        real start-up banner prints (docs: python/31-cli.md). Once per session;
        add ?boot to the URL to see it again. Any click, scroll or key skips it.
     2. build-in: the scene assembles back to front, links spin out of the hubs,
        the robot fades up in its clearing.
     3. arrival: the orange beacon glides in from off-screen, rippling the network
        as it passes, and settles into its orbit.
     The headline and buttons are never part of this: they are there from the start. */
  var booted = false;
  try { booted = sessionStorage.getItem("t4-booted") === "1" && !/[?&]boot\b/.test(location.search);
        sessionStorage.setItem("t4-booted", "1"); } catch(err) {}
  var willBoot = !(REDUCE || booted || !bootEl);
  /* each visit that boots shows the next language in turn (Python, PHP, Ruby,
     Node.js), with that runtime's real start-up banner (docs: <lang>/31-cli.md).
     Lines are [html, ms after the previous line]; the ASCII art prints in a burst */
  /* the newest release, written into data-version by scripts/build-home.mjs from
     docs/python/36-releases.md (the attribute in home/index.html is the fallback) */
  var VER = (bootEl && bootEl.getAttribute("data-version")) || "v3";
  var BANNERS = {
    python: [["  Tina4 Python " + VER], ['  HTTP server running at <span class="u">http://0.0.0.0:7146</span>'],
             ["  WebSocket server running at ws://0.0.0.0:7146"], ["  Live reload enabled"], ["  Press Ctrl+C to stop"]],
    php:    [[" _____ _             _  _", 70], ["|_   _(_)_ __   __ _| || |", 70], ["  | | | | '_ \\ / _` | || |_", 70],
             ["  | | | | | | | (_| |__   _|", 70], ["  |_| |_|_| |_|\\__,_|  |_|", 70], [" ", 70],
             ["  Tina4 PHP " + VER], ['  Server running at <span class="u">http://0.0.0.0:7145</span>'],
             ["  Debug mode: ON"], ["  Database: sqlite:///data/app.db"], ["  Press Ctrl+C to stop"]],
    ruby:   [["  Tina4 Ruby " + VER], ['  HTTP server running at <span class="u">http://0.0.0.0:7147</span>'],
             ["  WebSocket server running at ws://0.0.0.0:7147"], ["  Live reload enabled"], ["  Press Ctrl+C to stop"]],
    nodejs: [["  Tina4 Node.js " + VER], ['  HTTP server running at <span class="u">http://0.0.0.0:7148</span>'],
             ["  WebSocket server running at ws://0.0.0.0:7148"], ["  Live reload enabled"], ["  Press Ctrl+C to stop"]]
  };
  var ORDER = ["python", "php", "ruby", "nodejs"], bootLang = ORDER[0];
  if(willBoot){
    try { var li = (+localStorage.getItem("t4-boot-lang") || 0) % ORDER.length;
          bootLang = ORDER[li]; localStorage.setItem("t4-boot-lang", String((li + 1) % ORDER.length)); }
    catch(err) { bootLang = ORDER[Math.floor(Math.random()*ORDER.length)]; }
  }
  var BOOT_LINES = BANNERS[bootLang], LINE_AT = [], at = 1150;
  BOOT_LINES.forEach(function(l, k){ if(k) at += (l[1] || 180); LINE_AT.push(at); });
  var FADE_AT = at + 450, BOOT = willBoot ? FADE_AT + 400 : 0;
  var APPEAR = { bokeh: 0, dust: 0, sat: 200, mid: 400, hub: 600 }, APPEAR_DUR = 700;
  var SPOKES_AT = 700, THREADS_AT = 1100, ROBOT_AT = 900, FLY_AT = 1100, FLY_DUR = 1500;
  var CMD = "tina4 serve", bootKey = "";
  function bootRender(tt){
    if(!bootEl) return;
    if(tt >= BOOT){ if(bootKey !== "done"){ bootKey = "done"; bootEl.style.display = "none"; } return; }
    /* typed at 70ms a character, then the banner line by line, a hold, a fade */
    var typed = Math.max(0, Math.min(CMD.length, Math.floor((tt - 200)/70)));
    var shown = 0; while(shown < LINE_AT.length && tt >= LINE_AT[shown]) shown++;
    var key = typed + "/" + shown;
    if(key !== bootKey){
      bootKey = key;
      bootEl.innerHTML = '<div><span class="p">$</span> ' + CMD.slice(0, typed) +
        (shown === 0 ? '<span class="c"></span>' : "") + "</div>" +
        BOOT_LINES.slice(0, shown).map(function(l){ return "<div>" + l[0] + "</div>"; }).join("");
    }
    var fade = Math.max(0, Math.min(1, (tt - FADE_AT)/400));
    bootEl.style.opacity = (1 - fade).toFixed(3);
    bootEl.style.transform = "translateY(" + (-8*fade).toFixed(1) + "px)";
  }
  /* skip the boot on a deliberate interaction (not on mouse movement) */
  ["pointerdown", "keydown", "wheel", "touchstart"].forEach(function(ev){
    window.addEventListener(ev, function(){ if(clock < BOOT) clock = BOOT; }, { passive: true });
  });

  function rnd(a,b){ return a + Math.random()*(b-a); }
  function mk(n,c){ var e = document.createElementNS(NS,n); if(c) e.setAttribute("class",c); return e; }
  function ease(p){ return p < .5 ? 4*p*p*p : 1 - Math.pow(-2*p+2,3)/2; }
  function prog(tt, start, dur){ return ease(Math.max(0, Math.min(1, (tt - start)/dur))); }

  /* links are batched: each line style is a handful of <path>s, one per opacity
     level, and each frame writes one path string per level. Hundreds of separate
     <line>s cost thousands of DOM writes a frame; this costs a couple of dozen */
  var LEVELS = [.03, .07, .12, .18, .26, .36, .5];
  function Pool(g){
    var P = { g: g, paths: [], buf: [] };
    LEVELS.forEach(function(lv){
      var p = mk("path"); p.setAttribute("stroke-opacity", lv); p.setAttribute("fill", "none");
      g.appendChild(p); P.paths.push(p); P.buf.push([]);
    });
    return P;
  }
  function put(P, x1, y1, x2, y2, o){
    var i = 0; while(i < LEVELS.length - 1 && o > (LEVELS[i] + LEVELS[i+1])/2) i++;
    P.buf[i].push("M" + x1.toFixed(1) + " " + y1.toFixed(1) + "L" + x2.toFixed(1) + " " + y2.toFixed(1));
  }
  function settle(P){
    for(var i=0;i<P.paths.length;i++){ P.paths[i].setAttribute("d", P.buf[i].join("")); P.buf[i].length = 0; }
  }
  /* draw A to B minus the stretch inside a circle of radius r around (cx,cy):
     solve the segment/circle intersection and keep only the outside pieces, so
     the orange beacon never touches a line; it cuts through the web instead */
  function cut(P, ax, ay, bx, by, cx, cy, r, o){
    if(o < .01) return;
    var dx = bx-ax, dy = by-ay, fx = ax-cx, fy = ay-cy;
    var qa = dx*dx + dy*dy, qb = 2*(fx*dx + fy*dy), qc = fx*fx + fy*fy - r*r, disc = qb*qb - 4*qa*qc;
    if(qa === 0 || disc <= 0) return put(P, ax, ay, bx, by, o);
    var sq = Math.sqrt(disc), t1 = (-qb - sq)/(2*qa), t2 = (-qb + sq)/(2*qa);
    if(t2 <= 0 || t1 >= 1) return put(P, ax, ay, bx, by, o);
    if(t1 > 0) put(P, ax, ay, ax + dx*t1, ay + dy*t1, o);
    if(t2 < 1) put(P, ax + dx*t2, ay + dy*t2, bx, by, o);
  }
  /* a ring (the flash where a link snaps), batched into a pool like the links */
  function putRing(P, x, y, r, o){
    var i = 0; while(i < LEVELS.length - 1 && o > (LEVELS[i] + LEVELS[i+1])/2) i++;
    var r2 = (2*r).toFixed(1), rs = r.toFixed(1);
    P.buf[i].push("M" + (x - r).toFixed(1) + " " + y.toFixed(1) + "a" + rs + " " + rs + " 0 1 0 " + r2 + " 0a" + rs + " " + rs + " 0 1 0 -" + r2 + " 0");
  }
  /* cut(), but the link snaps rather than just being hidden: the moment the beacon
     reaches it there is a flash at the break and the cut ends twang back, their tips
     glowing; once the beacon has passed, the gap closes and the link reconnects.
     key names the link so its state carries from frame to frame */
  function snapCut(P, key, ax, ay, bx, by, cx, cy, r, o){
    if(REDUCE) return cut(P, ax, ay, bx, by, cx, cy, r, o);
    if(o < .01) return;
    var dx = bx-ax, dy = by-ay, qa = dx*dx + dy*dy, t1 = 2, t2 = -1, st = snaps[key];
    if(qa > 0){
      var fx = ax-cx, fy = ay-cy, qb = 2*(fx*dx + fy*dy), disc = qb*qb - 4*qa*(fx*fx + fy*fy - r*r);
      if(disc > 0){ var sq = Math.sqrt(disc); t1 = (-qb - sq)/(2*qa); t2 = (-qb + sq)/(2*qa); }
    }
    var len = Math.sqrt(qa) || 1, a, b, heat;
    if(t2 > 0 && t1 < 1){
      if(!st){
        st = snaps[key] = { born: nowT };
        var tm = Math.max(0, Math.min(1, (t1 + t2)/2));
        if(sparks.length < 40 && o > .05) sparks.push({ x: ax + dx*tm, y: ay + dy*tm, t: nowT, o: Math.min(1, o*2.4) });
      }
      st.h = 1; st.a = t1; st.b = t2; st.f = frameNo;
      var age = nowT - st.born, rec = Math.max(-3, 16*Math.exp(-age/240)*Math.cos(age/75))/len;   /* the twang */
      a = t1 - rec; b = t2 + rec; heat = 1;
    } else if(st){
      st.f = frameNo; st.h -= dtF/450;
      if(st.h <= 0){ delete snaps[key]; return put(P, ax, ay, bx, by, o); }
      var c = (st.a + st.b)/2, hw = (st.b - st.a)/2*st.h*st.h;              /* healing shut */
      a = c - hw; b = c + hw; heat = st.h;
    } else return put(P, ax, ay, bx, by, o);
    var tip = 13/len, ho = Math.min(.85, .15 + o*2.4)*heat;
    if(a > 0){
      put(P, ax, ay, ax + dx*a, ay + dy*a, o);
      put(pools.snap, ax + dx*Math.max(0, a - tip), ay + dy*Math.max(0, a - tip), ax + dx*a, ay + dy*a, ho);
    }
    if(b < 1){
      put(P, ax + dx*b, ay + dy*b, bx, by, o);
      put(pools.snap, ax + dx*b, ay + dy*b, ax + dx*Math.min(1, b + tip), ay + dy*Math.min(1, b + tip), ho);
    }
  }

  function measureTarget(cx, cy){
    var hr = hero.getBoundingClientRect(), rr = robot ? robot.getBoundingClientRect() : null;
    if(rr && rr.height > 0){ tx = rr.left - hr.left + rr.width/2; ty = rr.top - hr.top + rr.height*.5; rw = rr.width; }
    else { tx = cx; ty = cy; }
  }

  /* where the network lives: a wedge, dense in the top-right corner and thinning
     along a diagonal into clean dark, like the hairball artwork (a top band on
     mobile), with a clearing round the robot so the clean node stands apart */
  function home(){
    for(var tries=0; tries<400; tries++){
      var x = Math.random()*W, y = Math.random()*H, w;
      if(mob) w = Math.max(0, 1 - y/Math.min(H*.5, ty + rw*.8));    /* a band round Tina, however tall she is */
      else {
        if((x - W*.38)*(H*.85) - y*(W*.62) <= 0) continue;          /* below the diagonal (.38W,0)-(W,.85H) */
        w = Math.pow(Math.max(0, 1 - Math.hypot(W - x, y)/Math.hypot(W*.62, H*.85)), 1.3);
      }
      if(Math.hypot(x - tx, y - (ty - rw*.05)) < rw*.5) continue;   /* the clearing */
      if(Math.random() < w) return [x, y];
    }
    return [W*.85, H*.15];
  }
  /* the far field: out-of-focus dust and bokeh across the whole hero, so a wide
     screen has depth on the left too. Sparser behind the copy, clear of the robot */
  function homeFar(){
    for(var tries=0; tries<200; tries++){
      var x = Math.random()*W, y = Math.random()*H;
      if(Math.hypot(x - tx, y - (ty - rw*.05)) < rw*.6) continue;
      if(Math.random() < (x < W*.5 ? .45 : .8)) return [x, y];
    }
    return [Math.random()*W, Math.random()*H];
  }

  var PULLW = { hub: .45, mid: .75, sat: 1, dust: .6 };   /* how strongly each tier is drawn to the pointer */
  /* depth tiers: radius range, base opacity, drift amplitude, drift speed, mouse
     parallax in px (negative = background, moves against the mouse), and whether
     the beacon shoves it (the foreground tiers) */
  var TIERS = {
    hub:   { r:[7,11],    o:.95, amp:6,  spd:1.6, depth:8,  fg:true },
    mid:   { r:[3,5],     o:.85, amp:12, spd:1.3, depth:5,  fg:true },
    sat:   { r:[1.4,2.4], o:.5,  amp:20, spd:1.0, depth:3,  fg:true },
    dust:  { r:[.6,1.2],  o:.22, amp:26, spd:.7,  depth:-2, fg:false },
    bokeh: { r:[6,14],    o:.3,  amp:30, spd:.5,  depth:-3, fg:false }
  };

  function build(){
    W = hero.clientWidth; H = hero.clientHeight; mob = W < 860;
    svg.setAttribute("viewBox", "0 0 " + W + " " + H);
    svg.textContent = "";
    measureTarget(W*.7, H*.46);
    /* the hero is the one place soft glow is allowed (DESIGN.md s0, s7): radial
       fills for the hub glows, out-of-focus bokeh and the hot orange beacon */
    var defs = mk("defs");
    defs.innerHTML =
      '<radialGradient id="t4-hubglow"><stop offset="0" stop-color="#4888ff" stop-opacity=".55"/><stop offset="1" stop-color="#4888ff" stop-opacity="0"/></radialGradient>' +
      '<radialGradient id="t4-bokeh"><stop offset="0" stop-color="#8fa6e6" stop-opacity=".6"/><stop offset=".6" stop-color="#8fa6e6" stop-opacity=".25"/><stop offset="1" stop-color="#8fa6e6" stop-opacity="0"/></radialGradient>' +
      '<radialGradient id="t4-beacon"><stop offset="0" stop-color="#ff9a2e" stop-opacity=".75"/><stop offset=".35" stop-color="#ff9a2e" stop-opacity=".28"/><stop offset="1" stop-color="#ff9a2e" stop-opacity="0"/></radialGradient>';
    svg.appendChild(defs);
    /* layer order, back to front */
    G = {};
    ["back","threads","cons","sats","spokes","snap","nodes","hubs","beacon"].forEach(function(k){ G[k] = mk("g", "t-" + k); svg.appendChild(G[k]); });
    pools = { threads: Pool(G.threads), mid: Pool(G.cons), sat: Pool(G.sats), spokes: Pool(G.spokes), snap: Pool(G.snap) };
    snaps = {}; sparks = []; exAt = -1; exNext = -1;

    /* counts grow with the hero's area (up to ~1.8x on a big screen) so the network
       keeps its density instead of thinning out */
    var k = mob ? 1 : Math.max(1, Math.min(1.8, W*H/(1376*767)));
    var C = mob ? { hub:4, mid:18, sat:40, dust:30, bokeh:5 }
                : { hub:Math.round(7*k), mid:Math.round(40*k), sat:Math.round(90*k), dust:Math.round(60*k), bokeh:Math.round(10*k) };
    var FAR = mob ? { dust:0, bokeh:0 } : { dust:Math.round(45*k), bokeh:Math.round(7*k) };
    nodes = [];
    Object.keys(C).forEach(function(tier){
      var T = TIERS[tier], nFar = FAR[tier] || 0;
      for(var i=0;i<C[tier] + nFar;i++){
        var h = i < C[tier] ? home() : homeFar(), r = rnd(T.r[0], T.r[1]), el = mk("circle", "n-" + tier), glow = null;
        el.setAttribute("r", r.toFixed(1));
        if(tier === "hub"){ glow = mk("circle", "n-hubglow"); glow.setAttribute("r", (r*4).toFixed(1)); G.hubs.appendChild(glow); }
        (tier === "dust" || tier === "bokeh" ? G.back : tier === "hub" ? G.hubs : G.nodes).appendChild(el);
        if(tier === "mid" && i % 2) el.setAttribute("class", "n-mid n-grey");
        nodes.push({ tier: tier, T: T, el: el, glow: glow, r: r, hx: h[0], hy: h[1],
          x: h[0], y: h[1], px: 0, py: 0, mx: 0, my: 0, ph: rnd(0,6.283), ph2: rnd(0,6.283),
          sp2: rnd(.12,.26)*T.spd, tw: rnd(.6,1.6),
          o: T.o * (tier === "mid" ? rnd(.82,1) : tier === "sat" ? rnd(.7,1.2) : 1) });
      }
    });
    linkable = nodes.filter(function(n){ return n.tier === "mid" || n.tier === "sat"; });

    /* hub spokes: every hub radiates to its 6 to 10 nearest nodes, like the hairball's hubs */
    var hubs = nodes.filter(function(n){ return n.tier === "hub"; });
    spokes = [];
    hubs.forEach(function(hb, hi){
      linkable.map(function(o){ return { o: o, d: Math.hypot(o.hx - hb.hx, o.hy - hb.hy) }; })
        .sort(function(p, q){ return p.d - q.d; })
        .slice(0, 6 + Math.floor(Math.random()*5)).forEach(function(x){ spokes.push([hb, x.o, hi]); });
    });
    /* a few long dotted threads, the hairball's far-reaching links */
    threads = [];
    for(var q=0;q<(mob?5:12);q++) threads.push([hubs[q % hubs.length], linkable[Math.floor(Math.random()*linkable.length)], q]);

    /* the beacon itself is the designer's painted dot (beacon-dot.png, its
       disc centred and BEACON_K times smaller than the image), over a soft glow */
    beaconGlow = mk("circle", "b-glow"); beacon = mk("image", "beacon");
    beacon.setAttribute("href", ASSET + "beacon-dot.png"); beacon.setAttribute("preserveAspectRatio", "xMidYMid meet");
    G.beacon.appendChild(beaconGlow); G.beacon.appendChild(beacon);
    /* the front layer (above the robot) holds the beacon while it is in front */
    if(frontSvg){
      frontSvg.setAttribute("viewBox", "0 0 " + W + " " + H); frontSvg.textContent = "";
      frontG = mk("g", "t-beacon"); frontSvg.appendChild(frontG);
    }
    beaconFront = false; bp = null; aware = 0;
    /* R: how far the beacon shoves dots. L / Ls: longest mid-to-mid / satellite link */
    roam = mob ? { R: 70, L: 110, Ls: 80 } : { R: 95, L: 150, Ls: 90 };
  }

  function draw(t){
    var tt = REDUCE ? 1e9 : t, s = t/1000, B = BOOT;
    bootRender(tt);
    /* the beacon's arrival: q runs 0..1 over the flight, fe eases it */
    var q = Math.max(0, Math.min(1, (tt - B - FLY_AT)/FLY_DUR)), fe = ease(q), flying = q > 0 && q < 1;

    /* mouse parallax, eased, so the depth tiers slide against each other */
    var mx = 0, my = 0;
    if(!REDUCE && performance.now() - mouse.t < 4000){
      var hr = hero.getBoundingClientRect();
      mx = Math.max(-1, Math.min(1, (mouse.x - hr.left - W/2)/(W/2)));
      my = Math.max(-1, Math.min(1, (mouse.y - hr.top - H/2)/(H/2)));
    }
    par.x += (mx - par.x)*.04; par.y += (my - par.y)*.04;

    /* the orbit: round the robot, tilted like a ring seen from slightly above, so
       the lower arc passes in front of the robot and the upper arc behind it.
       Radius and speed breathe, so it also swings out into the network */
    var th = s*.32 + .7*Math.sin(s*.11);
    var orx = rw*(.8 + .35*Math.sin(s*.09 + .5)), ory = rw*(mob ? .22 : .3)*(1 + .33*Math.sin(s*.15 + 1.2));
    var ocx = tx - rw*.12*Math.sin(s*.05), ox = Math.cos(th), oy = Math.sin(th);
    var reach = ox > 0 ? Math.min(orx, W - ocx - 30) : Math.min(orx, ocx - 30);
    var obx = ocx + reach*ox, oby = ty + rw*.05 + ory*oy;
    /* the arrival: a glide in from off-screen top-right along a curve that lands on
       the moving orbit, so the hand-over is seamless */
    var bxN = obx, byN = oby, bz = oy;
    if(q < 1){
      var sx0 = W + 40, sy0 = H*.1, cx1 = tx + rw*.95, cy1 = ty - rw*.95, u = fe;
      bxN = (1-u)*(1-u)*sx0 + 2*u*(1-u)*cx1 + u*u*obx;
      byN = (1-u)*(1-u)*sy0 + 2*u*(1-u)*cy1 + u*u*oby;
      bz = u > .85 ? oy : -1;                    /* it comes in behind, then joins the orbit */
    }

    /* every 12 seconds or so it leaves the orbit on its own: a long curve up through
       the dense corner of the network (the top band on a phone), snapping links as it
       goes, then back into its loop. It leaves from the front of the orbit and stays
       in front, so Tina watches it go and come back. Not while it is chasing the
       pointer; the pointer takes over smoothly if it arrives mid-trip */
    var ex = 0, EX_DUR = 4.2;
    if(q >= 1 && !REDUCE){
      if(exNext < 0) exNext = s + 5;
      if(exAt < 0 && s >= exNext && aware < .05 && oy > .25 && ox > 0) exAt = s;
      if(exAt >= 0){
        var ep = (s - exAt)/EX_DUR;
        if(ep >= 1){ exAt = -1; exNext = s + 8; }
        else {
          var ramp = Math.min(1, ep/.22, (1 - ep)/.25); ramp = ramp*ramp*(3 - 2*ramp);
          var e0x, e0y, ecx, ecy, e1x, e1y;
          if(mob){
            var by0 = Math.max(110, ty - rw*.7);                 /* clear of the header */
            e0x = W*.86; e0y = by0 + 20; ecx = W*.5; ecy = by0 - 40; e1x = W*.12; e1y = by0 + 10;
          } else {
            e0x = W*.7; e0y = H*.42; ecx = W*1.02; ecy = -H*.2; e1x = W*.92; e1y = H*.52;
          }
          var eu = ep, ex1 = (1-eu)*(1-eu)*e0x + 2*eu*(1-eu)*ecx + eu*eu*e1x, ey1 = (1-eu)*(1-eu)*e0y + 2*eu*(1-eu)*ecy + eu*eu*e1y;
          ex1 = Math.max(30, Math.min(W - 30, ex1)); ey1 = Math.max(mob ? 90 : 30, Math.min(H - 30, ey1));
          ex = ramp*(1 - aware);
          bxN += (ex1 - bxN)*ex; byN += (ey1 - byN)*ex;
          bz += (.5 - bz)*Math.min(1, ramp*1.5);                 /* stays in front, Tina's eyes on it */
        }
      }
    }

    /* awareness of the mouse: it rises a beat after the pointer moves over the hero
       and fades once the pointer goes quiet or leaves. While aware, the beacon
       chases the pointer; either way it moves on a spring, so it carries momentum,
       trails the pointer, swings past a little when it stops, then settles */
    var dt = lastDraw === null ? 16 : Math.max(0, Math.min(50, t - lastDraw)); lastDraw = t;
    frameNo++; nowT = t; dtF = dt;
    var mPx = -1e4, mPy = -1e4;                                  /* the pointer in hero space */
    if(q >= 1 && !REDUCE){
      var hb = hero.getBoundingClientRect();
      mPx = mouse.x - hb.left; mPy = mouse.y - hb.top;
      var inHero = mouse.x >= hb.left && mouse.x <= hb.right && mouse.y >= hb.top && mouse.y <= hb.bottom;
      var want = inHero && performance.now() - mouse.t < 1500;
      var wasAware = aware;
      aware += ((want ? 1 : 0) - aware)*(1 - Math.exp(-dt/(want ? 480 : 900)));   /* notices you gradually */
      if(wasAware < .05 && aware >= .05) pulseAt = t;          /* the moment it notices */
      /* stop just beside the pointer, never on top of it */
      var mtx = Math.max(20, Math.min(W - 20, mPx + 18)), mty = Math.max(20, Math.min(H - 20, mPy + 18));
      var gx = bxN + (mtx - bxN)*aware, gy = byN + (mty - byN)*aware;
      if(!bp) bp = { x: bxN, y: byN, vx: 0, vy: 0 };
      /* stiff while orbiting (tracks the ring closely); lazy, well damped and speed-capped
         while chasing, so it drifts after you with a little swing rather than darting */
      var kS = 60 - 54*aware, cS = 2*Math.sqrt(kS)*(.78 - .1*aware), hS = dt/1000;
      bp.vx += (kS*(gx - bp.x) - cS*bp.vx)*hS; bp.vy += (kS*(gy - bp.y) - cS*bp.vy)*hS;
      var vmax = 1600 - 1180*aware, sp = Math.sqrt(bp.vx*bp.vx + bp.vy*bp.vy);   /* px/s: ~420 when chasing */
      if(sp > vmax){ bp.vx *= vmax/sp; bp.vy *= vmax/sp; }
      bp.x += bp.vx*hS; bp.y += bp.vy*hS;
      bxN = bp.x; byN = bp.y;
      bz += (.6 - bz)*aware;                                     /* following you, it comes forward */
    } else bp = null;

    /* swap layers only while the beacon is clear of the robot (on the orbit that is
       its sides), so the switch never shows */
    var front = bz > 0;
    var overRobot = Math.abs(bxN - tx) < rw*.3 && Math.abs(byN - ty) < rw*.45;
    if(frontG && front !== beaconFront && !overRobot){
      beaconFront = front;
      var layer = front ? frontG : G.beacon;
      layer.appendChild(beaconGlow); layer.appendChild(beacon);
    }

    /* the beacon shoves near dots aside; in flight its wake is wider, a ripple
       running through the network as it passes */
    var pushOn = q > 0 ? 1 : 0, pushR = roam.R*(flying ? 1 + 1.4*(1 - fe) : 1 + .45*ex), pushF = 45*(1 + .5*ex);
    for(var i=0;i<nodes.length;i++){
      var n = nodes[i], T = n.T;
      var a = prog(tt, B + APPEAR[n.tier], APPEAR_DUR);     /* the build-in, back to front */
      var rx = n.hx + Math.sin(s*n.sp2 + n.ph2)*T.amp + par.x*T.depth;
      var ry = n.hy + Math.cos(s*n.sp2*.9 + n.ph2)*T.amp*.7 + par.y*T.depth*.6;
      if(pushOn && T.fg){
        var dx = rx - bxN, dy = ry - byN, d = Math.sqrt(dx*dx + dy*dy) || 1;
        var push = d < pushR ? (1 - d/pushR)*pushF : 0, k = REDUCE ? 1 : .12;
        n.px += (dx/d*push - n.px)*k; n.py += (dy/d*push - n.py)*k;
      }
      /* the pointer gently draws the network toward it: lighter nodes more than the
         hubs, the bokeh not at all (it is far back), and with lag so it has weight.
         Up close the beacon still shoves dots away, so they gather round it in a loose ring */
      var pw = PULLW[n.tier] || 0;
      if(pw){
        var gxp = 0, gyp = 0;
        if(aware > .01){
          var qx = mPx - rx, qy = mPy - ry, qd = Math.sqrt(qx*qx + qy*qy) || 1, pr = mob ? 200 : 300;
          if(qd < pr){ var pl = Math.pow(1 - qd/pr, 1.3)*40*pw*aware; gxp = qx/qd*pl; gyp = qy/qd*pl; }
        }
        n.mx += (gxp - n.mx)*.07; n.my += (gyp - n.my)*.07;
      }
      n.x = rx + n.px + n.mx; n.y = ry + n.py + n.my;
      var xs = n.x.toFixed(1), ys = n.y.toFixed(1);
      n.el.setAttribute("cx", xs); n.el.setAttribute("cy", ys);
      if(n.tier === "hub" && a < 1) n.el.setAttribute("r", (n.r*(.35 + .65*a)).toFixed(1));
      if(n.glow){ n.glow.setAttribute("cx", xs); n.glow.setAttribute("cy", ys); n.glow.setAttribute("opacity", a.toFixed(3)); }
      var o = n.o*a;
      if(!REDUCE){
        if(n.tier === "sat" || n.tier === "dust") o *= .55 + .45*Math.sin(s*n.tw + n.ph);
        else if(n.tier === "mid") o *= .9 + .1*Math.sin(s*.8*n.tw + n.ph);
      }
      n.el.setAttribute("opacity", Math.min(1, o).toFixed(3));
    }

    /* beacon: 14 once it has arrived; nearer looks bigger, further smaller */
    var br = 14*(1 + .22*Math.max(-1, Math.min(1, bz))), gap = br + 26;
    /* keep the headline clean on desktop: links fade out toward the text column */
    function fadeX(x){ return mob ? 1 : Math.min(1, Math.max(0, (x - W*.36)/(W*.14))); }
    /* spokes spin out of each hub in turn; the long threads follow */
    for(var si=0; si<spokes.length; si++){
      var A = spokes[si][0], Bn = spokes[si][1], g = prog(tt, B + SPOKES_AT + spokes[si][2]*80, 800);
      if(g > 0) snapCut(pools.spokes, si, A.x, A.y, A.x + (Bn.x - A.x)*g, A.y + (Bn.y - A.y)*g, bxN, byN, gap, .5*fadeX((A.x + Bn.x)/2));
    }
    for(var ti=0; ti<threads.length; ti++){
      var A2 = threads[ti][0], B2 = threads[ti][1], g2 = prog(tt, B + THREADS_AT + threads[ti][2]*60, 900);
      if(g2 > 0) snapCut(pools.threads, 1e4 + ti, A2.x, A2.y, A2.x + (B2.x - A2.x)*g2, A2.y + (B2.y - A2.y)*g2, bxN, byN, gap, .25*fadeX((A2.x + B2.x)/2));
    }
    /* constellation: mids link to mids up to L, anything with a satellite up to Ls;
       it fades in as the beacon arrives */
    if(fe > 0){
      var L = roam.L, L2 = L*L, Ls = roam.Ls, Ls2 = Ls*Ls;
      for(var aa=0;aa<linkable.length;aa++){
        var NA = linkable[aa];
        for(var bb=aa+1;bb<linkable.length;bb++){
          var NB = linkable[bb], ddx = NB.x - NA.x, ddy = NB.y - NA.y, dd = ddx*ddx + ddy*ddy;
          var both = NA.tier === "mid" && NB.tier === "mid";
          if(dd > (both ? L2 : Ls2)) continue;
          var len = Math.sqrt(dd), fx2 = fadeX((NA.x + NB.x)/2);
          if(both) snapCut(pools.mid, 2e4 + aa*1000 + bb, NA.x, NA.y, NB.x, NB.y, bxN, byN, gap, (.18 + .17*(1 - len/L))*fe*fx2);
          else     snapCut(pools.sat, 2e4 + aa*1000 + bb, NA.x, NA.y, NB.x, NB.y, bxN, byN, gap, .2*(1 - len/Ls)*fe*fx2);
        }
      }
    }
    /* links that left the drawing this frame (moved out of reach) drop their snap state */
    for(var sk in snaps) if(snaps[sk].f !== frameNo) delete snaps[sk];
    /* the flashes where links snapped: a quick ring that widens and fades */
    for(var fi=sparks.length-1; fi>=0; fi--){
      var fl = sparks[fi], fa = (t - fl.t)/380;
      if(fa >= 1 || fa < 0){ sparks.splice(fi, 1); continue; }
      putRing(pools.snap, fl.x, fl.y, 3 + 12*fa, fl.o*(1 - fa));
    }
    settle(pools.spokes); settle(pools.threads); settle(pools.mid); settle(pools.sat); settle(pools.snap);

    /* the beacon: the painted dot, like the hairball's lone orange node, with a
       glow that swells when it notices you; hidden until its flight begins, and a
       little dimmer behind the robot */
    var vis = q > 0 ? 1 : 0, far = bz < 0 ? .78 + .22*(1 + bz) : 1;
    var bxs = bxN.toFixed(1), bys = byN.toFixed(1);
    var bs = 2*br*BEACON_K;
    beacon.setAttribute("x", (bxN - bs/2).toFixed(1)); beacon.setAttribute("y", (byN - bs/2).toFixed(1));
    beacon.setAttribute("width", bs.toFixed(1)); beacon.setAttribute("height", bs.toFixed(1));
    var pulse = Math.max(0, 1 - (t - pulseAt)/550);                /* a swell of glow as it notices you */
    beaconGlow.setAttribute("cx", bxs); beaconGlow.setAttribute("cy", bys);
    beaconGlow.setAttribute("r", (br*(4.6 + .25*Math.sin(s*1.3))*(1 + .6*Math.sin(Math.PI*pulse))).toFixed(1));
    beaconGlow.setAttribute("opacity", (vis*far).toFixed(3));
    beacon.setAttribute("opacity", (vis*far).toFixed(3));

    /* the hairball artwork fades in with the background tier */
    if(bgMain) bgMain.style.opacity = (.22*prog(tt, B, APPEAR_DUR + 300)).toFixed(3);
    if(bgWrap) bgWrap.style.transform = "translate(" + (par.x*2).toFixed(2) + "px," + (par.y*2).toFixed(2) + "px)";

    if(rig) rig.update(t, bxN, byN, fe, bz);
    if(tt >= B + ROBOT_AT && robot && !robot.classList.contains("arrived")) robot.classList.add("arrived");
  }

  /* an animation clock that only advances while frames are actually drawn
     (dt capped), so a hidden or background tab pauses the story instead of skipping it */
  var clock = 0, last = null;
  function frame(ts){
    if(last !== null) clock += Math.min(50, ts - last);
    last = ts;
    draw(clock);
    if(visible){ raf = requestAnimationFrame(frame); } else { raf = null; last = null; }
  }

  build();
  if(REDUCE){ draw(0); }
  else {
    raf = requestAnimationFrame(frame);
    if("IntersectionObserver" in window){
      new IntersectionObserver(function(es){
        visible = es[0].isIntersecting;
        if(visible && !raf) raf = requestAnimationFrame(frame);
      }).observe(hero);
    }
  }
  window.addEventListener("load", function(){ measureTarget(W*.7, H*.46); if(REDUCE) draw(0); });
  var rt; window.addEventListener("resize", function(){
    clearTimeout(rt); rt = setTimeout(function(){ build(); if(REDUCE || !raf) draw(clock); }, 200);
  });
})();

/* ---------- B: what you're not installing ---------- */
(function(){
  var grid = document.getElementById("dep-grid"); if(!grid) return;
  /* real installs, measured 15 October 2026 (latest versions; see the note under
     the section). "req" is what the command asked for; the rest came with it.
     Re-measure when the versions move, and update the date in the note. */
  var DEPS = {
    python: {
      them: { title: "flask-app", cmd: "pip install flask", req: ["flask"],
              pkgs: ["flask", "blinker", "click", "itsdangerous", "jinja2", "markupsafe", "werkzeug"] },
      us:   { title: "tina4-app", cmd: "pip install tina4-python", req: ["tina4-python"], pkgs: ["tina4-python"] } },
    php: {
      them: { title: "slim-app", cmd: "composer require slim/slim slim/psr7", req: ["slim/slim", "slim/psr7"],
              pkgs: ["slim/slim", "slim/psr7", "fig/http-message-util", "nikic/fast-route", "psr/container",
                     "psr/http-factory", "psr/http-message", "psr/http-server-handler",
                     "psr/http-server-middleware", "psr/log", "ralouphie/getallheaders"] },
      us:   { title: "tina4-app", cmd: "composer require tina4stack/tina4php", req: ["tina4stack/tina4php"],
              pkgs: ["tina4stack/tina4php"] } },
    ruby: {
      them: { title: "sinatra-app", cmd: "gem install sinatra", req: ["sinatra"],
              pkgs: ["sinatra", "base64", "logger", "mustermann", "rack", "rack-protection", "rack-session", "tilt"] },
      us:   { title: "tina4-app", cmd: "gem install tina4ruby", req: ["tina4ruby"], pkgs: ["tina4ruby"] } },
    nodejs: {
      them: { title: "express-app", cmd: "npm install express", req: ["express"],
              pkgs: ["express", "accepts", "body-parser", "bytes", "call-bind-apply-helpers", "call-bound",
                     "content-disposition", "content-type", "cookie", "cookie-signature", "debug", "depd",
                     "dunder-proto", "ee-first", "encodeurl", "es-define-property", "es-errors", "es-object-atoms",
                     "escape-html", "etag", "finalhandler", "forwarded", "fresh", "function-bind", "get-intrinsic",
                     "get-proto", "gopd", "has-symbols", "hasown", "http-errors", "iconv-lite", "inherits",
                     "ipaddr.js", "is-promise", "math-intrinsics", "media-typer", "merge-descriptors", "mime-db",
                     "mime-types", "ms", "negotiator", "object-inspect", "on-finished", "once", "parseurl",
                     "path-to-regexp", "proxy-addr", "qs", "range-parser", "raw-body", "router", "safer-buffer",
                     "send", "serve-static", "setprototypeof", "side-channel", "side-channel-list",
                     "side-channel-map", "side-channel-weakmap", "statuses", "toidentifier", "type-is", "unpipe",
                     "vary", "wrappy"] },
      us:   { title: "tina4-app", cmd: "npm install tina4-nodejs", req: ["tina4-nodejs"], pkgs: ["tina4-nodejs"] } }
  };
  var wins = {}, timers = [], lang = T4LANG.get(), seen = false;
  Array.prototype.forEach.call(grid.querySelectorAll(".dep-side"), function(w){
    wins[w.getAttribute("data-side")] = { cmd: w.querySelector(".dep-cmd-t"),
      list: w.querySelector(".dep-pkgs"), n: w.querySelector(".dep-n"), l: w.querySelector(".dep-l") };
  });
  function clear(){ timers.forEach(clearTimeout); timers = []; }
  function fill(side, d, animate){
    var w = wins[side], deps = d.pkgs.length - d.req.length;
    w.cmd.textContent = d.cmd; w.list.textContent = "";
    w.n.textContent = animate ? "0" : String(deps);
    w.l.innerHTML = "<b>" + (deps === 1 ? "dependency" : "dependencies") + "</b><br>" + d.pkgs.length + (d.pkgs.length === 1 ? " package" : " packages") + " installed";
    /* the box has a fixed height: once a chip would not fit, the rest are counted
       into a last "+N more" chip (which takes a visible chip's place if it has to) */
    var more = null, shown = 0;
    function fits(el){ return el.offsetTop + el.offsetHeight <= w.list.clientHeight; }
    d.pkgs.forEach(function(p, i){
      function add(){
        if(animate) w.n.textContent = String(Math.max(0, i + 1 - d.req.length));
        if(more){ more.textContent = "+" + (i + 1 - shown) + " more"; return; }
        var li = document.createElement("li"); li.textContent = p;
        if(d.req.indexOf(p) >= 0) li.className = "req";
        w.list.appendChild(li);
        if(fits(li)) return;
        /* sized for its final number first, so it never outgrows its row */
        w.list.removeChild(li);
        more = document.createElement("li"); more.className = "more"; w.list.appendChild(more);
        shown = w.list.children.length - 1;
        more.textContent = "+" + (d.pkgs.length - shown) + " more";
        while(!fits(more) && more.previousSibling){ w.list.removeChild(more.previousSibling); shown--; more.textContent = "+" + (d.pkgs.length - shown) + " more"; }
        more.style.minWidth = more.offsetWidth + "px";
        more.textContent = "+" + (i + 1 - shown) + " more";
      }
      /* the dependencies land one after another, so the count visibly climbs */
      if(animate) timers.push(setTimeout(add, 250 + i*45)); else add();
    });
  }
  function show(l, animate){
    clear(); lang = l;
    fill("them", DEPS[l].them, animate); fill("us", DEPS[l].us, animate);
  }
  var tabs = document.querySelectorAll(".dep-tab");
  function mark(l){
    Array.prototype.forEach.call(tabs, function(o){ var on = o.getAttribute("data-lang") === l; o.classList.toggle("active", on); o.setAttribute("aria-selected", on ? "true" : "false"); });
  }
  Array.prototype.forEach.call(tabs, function(t){
    t.addEventListener("click", function(){
      var l = t.getAttribute("data-lang"); mark(l); show(l, !REDUCE); T4LANG.set(l);
    });
  });
  /* another section changed the language: follow it without replaying the install */
  T4LANG.on(function(l){ if(l !== lang){ mark(l); show(l, false); } });
  mark(lang);
  show(lang, false);
  /* how many chips fit depends on the width: lay them out again after a resize */
  var rz; window.addEventListener("resize", function(){ clearTimeout(rz); rz = setTimeout(function(){ show(lang, false); }, 200); });
  if(REDUCE || !("IntersectionObserver" in window)) return;
  /* play the install once, the first time the section comes into view */
  new IntersectionObserver(function(es, io){
    if(es[0].isIntersecting && !seen){ seen = true; io.disconnect(); show(lang, true); }
  }, { threshold: .35 }).observe(grid);
})();

/* ---------- C: language tabs + the self-building terminal ---------- */
(function(){
  var LANG = {
    python: { init: "tina4 init python my-app", port: 7146 },
    php:    { init: "tina4 init php my-app",    port: 7145 },
    ruby:   { init: "tina4 init ruby my-app",   port: 7147 },
    nodejs: { init: "tina4 init nodejs my-app", port: 7148 }
  };
  var tabs = document.querySelectorAll(".proof-tab");
  var variants = document.querySelectorAll(".proof-body .code-variant");
  var initCmd = document.getElementById("init-cmd");
  var serveCmd = document.getElementById("serve-cmd");
  var curlCmd = document.getElementById("curl-cmd");
  var curlJson = document.getElementById("curl-json");
  var docLinks = document.querySelectorAll(".proof-gets .doc-link");
  var replay = document.getElementById("replay");
  var proof = document.querySelector(".proof");
  var current = T4LANG.get(), run = 0, touched = false;

  /* drop stray whitespace nodes, then wrap each code line so it can be revealed */
  var body = document.querySelector(".proof-body");
  Array.prototype.slice.call(body.childNodes).forEach(function(n){ if(n.nodeType === 3) body.removeChild(n); });
  variants.forEach(function(v){
    v.innerHTML = v.innerHTML.split("\n").map(function(l){ return '<span class="ln">' + (l || " ") + "</span>"; }).join("\n");
  });

  function cmdFor(lang){ return "curl localhost:" + LANG[lang].port + "/api/hello/Ada"; }
  function setFull(lang){
    initCmd.textContent = LANG[lang].init; serveCmd.textContent = "tina4 serve"; curlCmd.textContent = cmdFor(lang);
    [initCmd, serveCmd, curlCmd].forEach(function(e){ e.classList.remove("typing"); });
    variants.forEach(function(v){ v.classList.remove("building"); });
    curlJson.classList.remove("hide");
  }
  function select(lang){
    current = lang; run++;
    tabs.forEach(function(t){ var on = t.dataset.lang === lang; t.classList.toggle("active", on); t.setAttribute("aria-selected", on ? "true" : "false"); });
    variants.forEach(function(v){ v.classList.toggle("active", v.dataset.lang === lang); });
    docLinks.forEach(function(a){ a.setAttribute("href", "/" + lang + "/" + a.dataset.doc + "/"); });
    setFull(lang);
  }
  function sleep(ms){ return new Promise(function(r){ setTimeout(r, ms); }); }
  async function type(el, text, id, speed){
    el.textContent = ""; el.classList.add("typing");
    for(var i=1;i<=text.length;i++){
      if(id !== run) return false;
      el.textContent = text.slice(0, i); await sleep(speed);
    }
    el.classList.remove("typing"); return true;
  }
  function blank(v){
    initCmd.textContent = ""; serveCmd.textContent = ""; curlCmd.textContent = "";
    v.classList.add("building"); v.querySelectorAll(".ln").forEach(function(l){ l.classList.remove("on"); });
    curlJson.classList.add("hide");
  }
  async function play(){
    if(REDUCE){ setFull(current); return; }
    var id = ++run, L = LANG[current];
    var v = document.querySelector('.proof-body .code-variant[data-lang="' + current + '"]'), lines = v.querySelectorAll(".ln");
    blank(v);
    await sleep(250);
    if(!await type(initCmd, L.init, id, 38)) return;
    await sleep(320); if(id !== run) return;
    if(!await type(serveCmd, "tina4 serve", id, 45)) return;
    await sleep(380);
    for(var i=0;i<lines.length;i++){ if(id !== run) return; lines[i].classList.add("on"); await sleep(110); }
    await sleep(350); if(id !== run) return;
    if(!await type(curlCmd, cmdFor(current), id, 28)) return;
    await sleep(300); if(id !== run) return;
    curlJson.classList.remove("hide"); v.classList.remove("building");
  }

  tabs.forEach(function(t){ t.addEventListener("click", function(){ touched = true; select(t.dataset.lang); T4LANG.set(t.dataset.lang); }); });
  replay.addEventListener("click", function(){ touched = true; play(); });
  /* another section changed the language: follow it quietly */
  T4LANG.on(function(l){ if(l !== current) select(l); });
  if(current !== "python") select(current);

  if(!REDUCE && "IntersectionObserver" in window){
    blank(document.querySelector('.proof-body .code-variant[data-lang="' + current + '"]'));
    var io = new IntersectionObserver(function(es){
      if(es[0].isIntersecting){ io.disconnect(); if(!touched) play(); }
    }, { threshold: .35 });
    io.observe(proof);
  } else {
    setFull(current);
  }
})();

/* ---------- give your AI 30 seconds: prompt tabs ---------- */
(function(){
  var L = {
    python: { name: "Python",  init: "tina4 init python todo-api", port: 7146 },
    php:    { name: "PHP",     init: "tina4 init php todo-api",    port: 7145 },
    ruby:   { name: "Ruby",    init: "tina4 init ruby todo-api",   port: 7147 },
    nodejs: { name: "Node.js", init: "tina4 init nodejs todo-api", port: 7148 }
  };
  var tabs = document.querySelectorAll(".ai-tab"); if(!tabs.length) return;
  var lang = document.getElementById("ai-lang"), init = document.getElementById("ai-init"), sw = document.getElementById("ai-swagger");
  function apply(k){
    tabs.forEach(function(o){ var on = o.dataset.lang === k; o.classList.toggle("active", on); o.setAttribute("aria-selected", on ? "true" : "false"); });
    lang.textContent = L[k].name; init.textContent = L[k].init;
    sw.textContent = "Swagger at localhost:" + L[k].port + "/swagger";
  }
  tabs.forEach(function(t){ t.addEventListener("click", function(){ apply(t.dataset.lang); T4LANG.set(t.dataset.lang); }); });
  T4LANG.on(apply);
  apply(T4LANG.get());
})();

/* ---------- easter egg: Tina pops up from the bottom when you go still ---------- */
(function(){
  if(REDUCE) return;
  var IDLE = 8000, HOLD = 7000, GAP = 30000, MAX = 2;
  var peek = document.createElement("div");
  peek.className = "peek"; peek.setAttribute("aria-hidden", "true");
  peek.innerHTML = '<div class="peek-bot"></div><span class="peek-say">Psst. There&#39;s more below<svg class="i" aria-hidden="true"><use href="#i-arrow-down"/></svg></span>';
  document.body.appendChild(peek);
  var bot = peek.querySelector(".peek-bot"), ready = null;

  /* her own copy of the robot at rest, rings and all (her rings stay behind her in
     every pose, DESIGN.md s16), with every id renamed so her clip paths never pick
     up the hero robot's live, turning ones.
     Fetched once, quietly after the page has loaded, so she never arrives empty */
  function load(){
    if(ready) return ready;
    ready = new Promise(function(done){
      var fall = function(){ bot.innerHTML = '<img src="' + ASSET + 'tina4-logo-correct.svg" alt="">'; done(); };
      if(!window.fetch || !window.DOMParser){ fall(); return; }
      fetch(ASSET + "tina4-robot.svg").then(function(r){ return r.ok ? r.text() : Promise.reject(); }).then(function(t){
        t = t.replace(/\sid="([^"]+)"/g, ' id="pk-$1"').replace(/url\(#([^)]+)\)/g, "url(#pk-$1)").replace(/href="#([^"]+)"/g, 'href="#pk-$1"');
        var doc = new DOMParser().parseFromString(t, "image/svg+xml"), svg = doc.documentElement;
        if(svg.nodeName.toLowerCase() !== "svg"){ fall(); return; }
        bot.appendChild(document.importNode(svg, true)); done();
      }).catch(fall);
    });
    return ready;
  }

  var out = false, shown = 0, lastAt = -1e9, idle = null, hold = null;
  function moreBelow(){
    var d = document.documentElement;
    return window.scrollY + window.innerHeight < d.scrollHeight - 300;
  }
  function show(){
    if(out || shown >= MAX || document.hidden || !moreBelow()) return;
    var chat = document.querySelector(".tp-chat-panel"); if(chat && !chat.hidden) return;   /* not while the chat is open */
    if(performance.now() - lastAt < GAP) return;
    if(!bot.firstChild){ load().then(function(){ arm(); }); return; }
    out = true; shown++; lastAt = performance.now();
    peek.classList.add("in");
    hold = setTimeout(hide, HOLD);
  }
  function hide(){
    if(!out) return;
    out = false; peek.classList.remove("in"); clearTimeout(hold);
  }
  /* any sign of life: she ducks, and the stillness clock starts again */
  function arm(){
    clearTimeout(idle);
    if(shown < MAX) idle = setTimeout(show, IDLE);
  }
  function stir(){ hide(); arm(); }
  ["mousemove", "scroll", "keydown", "wheel", "touchstart", "pointerdown"].forEach(function(ev){
    window.addEventListener(ev, function(e){ if(out && e.type === "pointerdown" && peek.contains(e.target)) return; stir(); }, { passive: true });
  });
  peek.addEventListener("click", function(){
    hide();
    window.scrollBy({ top: Math.round(window.innerHeight*.85), behavior: "smooth" });
  });
  window.addEventListener("load", function(){ setTimeout(load, 2000); });
  arm();
})();

/* ---------- Ask Tina4 steps aside while the hero buttons are in view (phones) ---------- */
(function(){
  var cta = document.querySelector(".hero-cta");
  if(!cta || !("IntersectionObserver" in window) || !window.matchMedia) return;
  var phone = matchMedia("(max-width: 600px)"), seen = false;
  function apply(){ document.body.classList.toggle("cta-visible", phone.matches && seen); }
  new IntersectionObserver(function(es){ seen = es[0].isIntersecting; apply(); }, { threshold: .01 }).observe(cta);
  if(phone.addEventListener) phone.addEventListener("change", apply);
})();

/* ---------- anything marked data-open-chat opens the Ask Tina4 chat ----------
   .tp-chat-btn toggles the panel, so click it only while the panel is closed */
(function(){
  function openChat(){
    var native = document.querySelector(".tp-chat-btn"), panel = document.querySelector(".tp-chat-panel");
    if(native){ if(!panel || panel.hidden) native.click(); else { var i = panel.querySelector(".tp-chat-input"); if(i) i.focus(); } return; }
  }
  Array.prototype.forEach.call(document.querySelectorAll("[data-open-chat]"), function(b){ b.addEventListener("click", openChat); });
})();

/* ---------- Ask Tina4 ----------
   tina4press's chat markup, restyled, asking the same hosted RAG as the docs
   widget. The endpoint comes from themeConfig.chat in tina4press.config.mjs:
   scripts/build-home.mjs writes it into data-api on .tp-chat, so the two never
   drift. The request and the reply are the ones tina4press's client.js uses:
   POST {api}/v1/ask { query, language, k, stream:false } -> { answer, sources[] }.
   The language is the one picked on this page (T4LANG). stream:false because
   the streamed reply carries no sources, and the citations are the point. */
(function(){
  var wrap = document.querySelector(".tp-chat"); if(!wrap) return;
  var btn = wrap.querySelector(".tp-chat-btn"), panel = wrap.querySelector(".tp-chat-panel");
  var log = wrap.querySelector(".tp-chat-log"), form = wrap.querySelector(".tp-chat-form");
  var input = wrap.querySelector(".tp-chat-input"), closeBtn = wrap.querySelector(".tp-chat-close");
  var API = (wrap.getAttribute("data-api") || "https://rag.tina4.com").replace(/\/+$/, "");
  var ASK_PATH = wrap.getAttribute("data-ask-path") || "/v1/ask";
  var NAMES = { python: "Python", php: "PHP", ruby: "Ruby", nodejs: "Node.js" };
  var ASK = ["How do I define a route?", "How do I connect a database?", "How do I add JWT auth?", "How do I run a background job?"];
  var ERROR = "Sorry, the assistant is unreachable right now. The docs have the answer too: try the search on any docs page.";
  function lang(){ return (window.T4LANG && T4LANG.get()) || "python"; }

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
    var box = add("tp-chat-suggest", "");
    ASK.forEach(function(q){
      var c = document.createElement("button"); c.type = "button"; c.className = "tp-chat-chip"; c.textContent = q;
      c.addEventListener("click", function(){ box.parentNode && box.parentNode.removeChild(box); ask(q); }); box.appendChild(c);
    });
  }
  /* the structured sources[] become citations: always real URLs, unlike a link an
     answer might mangle. One per URL, without the "(path)" the service appends */
  function sources(list){
    var seen = {}, items = "";
    (list || []).forEach(function(s){
      var u = s && s.url && safeUrl(esc(s.url)); if(!u || seen[u]) return; seen[u] = 1;
      items += '<a class="tp-chat-src" href="' + u + '"' + linkAttrs(u) + ">" + esc((s.title || s.url).replace(/\s*\([^)]*\)\s*$/, "")) + "</a>";
    });
    if(items) add("tp-chat-sources", '<div class="tp-chat-sources-label">Sources</div>' + items);
  }
  function ask(q){
    q = q.trim(); if(!q) return;
    add("tp-chat-msg tp-chat-you", esc(q));
    var thinking = add("tp-chat-msg tp-chat-bot", '<span class="tp-chat-thinking" role="img" aria-label="Thinking"><span></span><span></span><span></span></span>');
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
        add("tp-chat-msg tp-chat-bot", md("Hi, I'm Tina. Ask me how to do something in Tina4. I'll answer for **" + NAMES[lang()] + "**, the language picked on this page."));
        suggest();
      }
      setTimeout(function(){ input.focus(); }, 30);
    } else btn.focus();
  }
  btn.addEventListener("click", function(){ setOpen(panel.hidden); });
  closeBtn.addEventListener("click", function(){ setOpen(false); });
  var expand = wrap.querySelector(".tp-chat-expand");
  if(expand) expand.addEventListener("click", function(){ var w = wrap.classList.toggle("wide"); expand.setAttribute("aria-pressed", w ? "true" : "false"); expand.setAttribute("aria-label", w ? "Narrower panel" : "Wider panel"); });

  document.addEventListener("keydown", function(e){ if(e.key === "Escape" && !panel.hidden) setOpen(false); });
  form.addEventListener("submit", function(e){ e.preventDefault(); var q = input.value; input.value = ""; ask(q); });
})();

/* ---------- copy buttons ---------- */
(function(){
  function copy(text, btn){
    /* a tick while it is copied, then the button comes back as it was */
    var label = btn.dataset.label || (btn.dataset.label = btn.innerHTML);
    function done(){ btn.innerHTML = '<svg class="i" aria-hidden="true"><use href="#i-check"/></svg>' + (btn.dataset.doneText || ""); btn.classList.add("done");
      setTimeout(function(){ btn.innerHTML = label; btn.classList.remove("done"); }, 1600); }
    if(navigator.clipboard && window.isSecureContext){ navigator.clipboard.writeText(text).then(done, function(){}); return; }
    var ta = document.createElement("textarea"); ta.value = text; ta.style.position = "fixed"; ta.style.opacity = "0";
    document.body.appendChild(ta); ta.select();
    try{ document.execCommand("copy"); done(); }catch(e){}
    document.body.removeChild(ta);
  }
  document.querySelectorAll(".copy-btn").forEach(function(b){
    b.addEventListener("click", function(){
      var src = b.dataset.copyFrom ? document.getElementById(b.dataset.copyFrom).textContent : b.dataset.copy;
      copy(src, b);
    });
  });
})();

/* ---------- reveal rows top to bottom when a block scrolls into view ---------- */
(function(){
  if(REDUCE || !("IntersectionObserver" in window)) return;   /* otherwise everything simply shows */
  document.querySelectorAll("[data-reveal]").forEach(function(block){
    var rows = block.querySelectorAll(".row, .box-row"); if(!rows.length) return;
    block.classList.add("pending");
    var io = new IntersectionObserver(function(es){
      if(!es[0].isIntersecting) return; io.disconnect();
      rows.forEach(function(r, i){ setTimeout(function(){ r.classList.add("on"); }, 90*i); });
      setTimeout(function(){ block.classList.remove("pending"); }, 90*rows.length + 450);
    }, { threshold: .2 });
    io.observe(block);
  });
})();

/* ---------- closing band: Tina's rings, without Tina ----------
   The page opens with Tina inside her rings and closes with only the rings, as
   if she stepped out. They are the rig's own five halo rings (ids renamed so they
   never touch the hero robot's), each turning on a slow CSS spin at its own
   speed, two the other way. Reduced motion stops them (the global rule). */
(function(){
  var host = document.querySelector(".closing-rings");
  if(!host || !window.fetch || !window.DOMParser) return;
  /* seconds per turn, inner to outer; negative turns the other way */
  var TURN = [80, -52, 36, -64, 120];
  fetch(ASSET + "tina4-robot.svg").then(function(r){ return r.ok ? r.text() : Promise.reject(); }).then(function(t){
    t = t.replace(/\sid="([^"]+)"/g, ' id="cr-$1"').replace(/url\(#([^)]+)\)/g, "url(#cr-$1)").replace(/href="#([^"]+)"/g, 'href="#cr-$1"');
    var svg = new DOMParser().parseFromString(t, "image/svg+xml").documentElement;
    if(svg.nodeName.toLowerCase() !== "svg") return;
    var bot = svg.querySelector('[data-rig="robot"]'); if(bot) bot.parentNode.removeChild(bot);
    Array.prototype.forEach.call(svg.querySelectorAll('[data-rig="ring"]'), function(g){
      var s = TURN[+g.getAttribute("data-ring")] || 90;
      g.setAttribute("class", "cring");
      g.style.animationDuration = Math.abs(s) + "s";
      if(s < 0) g.style.animationDirection = "reverse";
    });
    host.appendChild(document.importNode(svg, true));
  }).catch(function(){ /* no rings: the band still reads fine */ });
})();

/* dark-mode toggle: the same attribute and storage key as tina4press's own toggle
   (data-theme on <html>, localStorage "tp-theme"), so the choice carries across the site */
(function(){
  var btn = document.getElementById("theme-toggle");
  if(!btn) return;
  btn.addEventListener("click", function(){
    var cur = document.documentElement.getAttribute("data-theme") === "dark" ? "dark" : "light";
    var next = cur === "dark" ? "light" : "dark";
    document.documentElement.setAttribute("data-theme", next);
    try{ localStorage.setItem("tp-theme", next); }catch(e){}
  });
})();

/* ---------- the phone and tablet menu ----------
   Below 960px the header nav hides behind the menu button; the menu panel gets a
   copy of the same links, so there is one list to keep (and the build fills it) */
(function(){
  var toggle = document.getElementById("nav-toggle"), menu = document.getElementById("mobile-nav");
  var nav = document.querySelector(".site-nav");
  if(!toggle || !menu || !nav) return;
  Array.prototype.forEach.call(nav.querySelectorAll("a"), function(a){ menu.appendChild(a.cloneNode(true)); });
  function setOpen(on){
    menu.hidden = !on; toggle.setAttribute("aria-expanded", on ? "true" : "false");
    toggle.setAttribute("aria-label", on ? "Close menu" : "Menu");
  }
  toggle.addEventListener("click", function(){ setOpen(menu.hidden); });
  menu.addEventListener("click", function(e){ if(e.target.closest("a")) setOpen(false); });
  document.addEventListener("keydown", function(e){ if(e.key === "Escape" && !menu.hidden){ setOpen(false); toggle.focus(); } });
  /* back on a wide screen the panel has no button to close it, so close it */
  if(window.matchMedia){
    var wide = matchMedia("(min-width: 961px)");
    var shut = function(){ if(wide.matches) setOpen(false); };
    if(wide.addEventListener) wide.addEventListener("change", shut); else if(wide.addListener) wide.addListener(shut);
  }
})();

/* ---------- recent releases: the notes in the language picked on the page ----------
   The build gives each release link its anchor in all four languages' notes
   (data-<lang>="/<lang>/36-releases/#..."), since each language words its
   headings its own way */
(function(){
  var links = document.querySelectorAll(".rel-link, .rel-notes"); if(!links.length) return;
  function apply(l){
    Array.prototype.forEach.call(links, function(a){
      var h = a.getAttribute("data-" + l);
      a.setAttribute("href", h || "/" + l + "/36-releases/");
    });
  }
  T4LANG.on(apply);
  apply(T4LANG.get());
})();
