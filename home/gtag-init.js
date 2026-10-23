/* The site's Google Analytics setup: what tina4press writes inline on every
   docs page, as a file, so the home page needs no inline script under its CSP.
   scripts/build-home.mjs writes the measurement ID (themeConfig.analytics in
   tina4press.config.mjs) into this script tag's data-ga attribute. */
(function(){
  var tag = document.currentScript, id = tag && tag.getAttribute("data-ga");
  if(!id) return;
  window.dataLayer = window.dataLayer || [];
  window.gtag = function(){ window.dataLayer.push(arguments); };
  window.gtag("js", new Date());
  window.gtag("config", id);
})();
