/* The theme before first paint, with tina4press's own attribute and key
   (data-theme on <html>, localStorage "tp-theme"), so a choice made here or on
   any docs page carries across the whole site. Loaded as a blocking script in
   <head>, not inline, so the page needs no inline script under its CSP. */
(function(){try{var t=localStorage.getItem("tp-theme");var d=t?t==="dark":matchMedia("(prefers-color-scheme:dark)").matches;document.documentElement.setAttribute("data-theme",d?"dark":"light");}catch(e){}})();
