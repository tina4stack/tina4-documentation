#!/usr/bin/env bash
# Syncs tina4-book chapters into the VitePress docs site.
# Escapes Twig/Vue template syntax for VitePress/Vue compatibility.
# Usage: ./scripts/sync-books.sh [/path/to/tina4-book]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCS_ROOT="$SCRIPT_DIR/../docs"
BOOK_ROOT="${1:-$(cd "$SCRIPT_DIR/.." && pwd)/../tina4-book}"

if [ ! -d "$BOOK_ROOT" ]; then
  echo "ERROR: tina4-book not found at $BOOK_ROOT"
  echo "Usage: $0 /path/to/tina4-book"
  exit 1
fi

echo "Syncing from: $BOOK_ROOT"
echo "Into docs at: $DOCS_ROOT"
echo ""

# Escape Twig/Vue template syntax for VitePress.
#
# VitePress compiles markdown as Vue SFC templates. The {{ }} and {% %}
# syntax used in Twig examples conflicts with Vue's template compiler.
#
# Strategy:
# - OUTSIDE code fences: escape {{ }}, {% %}, {# #} with HTML entities
# - INSIDE html/twig/jinja/unlabeled code fences: escape (Vue parses these)
# - INSIDE other code fences (pascal, javascript, python, etc.): LEAVE ALONE
#   (markdown-it already escapes these into <code> blocks safely)
escape_twig() {
  python3 -c "
import sys

content = sys.stdin.read()
lines = content.split('\n')
result = []
in_fence = False
fence_lang = ''

# All code fences are safe — markdown-it escapes content into <code> elements.
# No languages need entity escaping inside fences.
UNSAFE_LANGS = set()

def escape_line(line):
    \"\"\"Escape template syntax with HTML entities for code fences\"\"\"
    line = line.replace('{{', '&#123;&#123;')
    line = line.replace('}}', '&#125;&#125;')
    line = line.replace('{%', '&#123;%')
    line = line.replace('%}', '%&#125;')
    line = line.replace('{#', '&#123;#')
    line = line.replace('#}', '#&#125;')
    return line

# Process paragraphs: collect consecutive non-blank prose lines containing
# template syntax and wrap each group in <div v-pre>...</div>

i = 0
while i < len(lines):
    stripped = lines[i].strip()

    # Track code fences
    if stripped.startswith('\`\`\`'):
        if not in_fence:
            in_fence = True
            fence_lang = stripped[3:].strip().split()[0].lower() if len(stripped) > 3 else ''
        else:
            in_fence = False
            fence_lang = ''
        result.append(lines[i])
        i += 1
        continue

    has_template = '{{' in lines[i] or '{%' in lines[i] or '{#' in lines[i]

    if has_template:
        if in_fence:
            if fence_lang in UNSAFE_LANGS:
                result.append(escape_line(lines[i]))
            else:
                result.append(lines[i])
        else:
            # Prose line with template syntax: wrap in v-pre div
            # Collect consecutive non-blank lines that are part of this paragraph
            para_lines = []
            while i < len(lines) and lines[i].strip() != '' and not lines[i].strip().startswith('\`\`\`'):
                para_lines.append(lines[i])
                i += 1
            result.append('<div v-pre>')
            result.append('')
            result.extend(para_lines)
            result.append('')
            result.append('</div>')
            continue
    else:
        result.append(lines[i])

    i += 1

print('\n'.join(result), end='')
"
}

sync_book() {
  local book="$1"
  local section="$2"
  local src="$BOOK_ROOT/$book/chapters"
  local dest="$DOCS_ROOT/$section"

  if [ ! -d "$src" ]; then
    echo "  WARN: $src not found, skipping $book"
    return
  fi

  mkdir -p "$dest"

  # Remove old numbered chapter files before syncing (preserves index.md and other non-chapter files)
  rm -f "$dest"/[0-9]*.md

  local count=0
  for chapter in "$src"/[0-9]*.md; do
    [ -f "$chapter" ] || continue
    escape_twig < "$chapter" | sed 's/^```env$/```bash/' > "$dest/$(basename "$chapter")"
    count=$((count + 1))
  done

  echo "  $section/ <- $count chapters from $book"
}

sync_book "book-0-understanding" "general"
sync_book "book-1-python"        "python"
sync_book "book-2-php"           "php"
sync_book "book-3-ruby"          "ruby"
sync_book "book-4-nodejs"        "nodejs"
sync_book "book-5-javascript"    "js"
sync_book "book-6-delphi"        "delphi"

echo ""
echo "Sync complete. Run 'pnpm docs:build' to verify."
