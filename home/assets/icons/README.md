# Icons

The page's icons are from Lucide (https://lucide.dev), lucide-static v1.57.0,
ISC licence (LUCIDE-LICENSE.txt). They are not a dependency: the shapes of the
few icons used are copied into home/index.html once, as an inline SVG sprite
(`<symbol id="i-...">`), and each use is `<svg class="i"><use href="#i-..."/></svg>`.
No package, no script, no request.

In use: search, command (the search shortcut), menu, rotate-ccw (replay), copy,
check (copied), arrow-right, arrow-down, arrow-up (send a chat question),
x (close), maximize-2 and minimize-2 (widen and narrow the chat), moon, sun.

Not Lucide: `i-tina` in the same sprite is Tina's silhouette from the favicon
(home/assets/favicon/favicon.svg), drawn in currentColor for the chat button, the
chat avatar and the hero's Ask Tina4 link.

Rules: icons only where they do a job (a button, a link's direction, a state).
No decorative icons on headings or feature lists, and no emoji anywhere.
Brand marks (GitHub, the language logos) are not Lucide: see lang/README.md.
