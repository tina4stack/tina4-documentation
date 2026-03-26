#!/usr/bin/env bash
# Syncs tina4-book chapters into the VitePress docs site.
# Escapes all Twig/template syntax for VitePress/Vue compatibility.
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

# Escape all Twig/Vue template syntax for VitePress.
# VitePress compiles markdown as Vue SFC templates, so we must escape
# {{ }}, {% %}, {# #} everywhere to prevent Vue compiler errors.
escape_twig() {
  python3 -c "
import sys

content = sys.stdin.read()
lines = content.split('\n')
result = []
in_fence = False

for line in lines:
    stripped = line.strip()
    if stripped.startswith('\`\`\`'):
        in_fence = not in_fence
        result.append(line)
        continue

    # Escape ALL template syntax everywhere (inside and outside code fences)
    # Use HTML entities so they render correctly in the browser
    if '{{' in line or '{%' in line or '{#' in line:
        line = line.replace('{{', '&#123;&#123;')
        line = line.replace('}}', '&#125;&#125;')
        line = line.replace('{%', '&#123;%')
        line = line.replace('%}', '%&#125;')
        line = line.replace('{#', '&#123;#')
        line = line.replace('#}', '#&#125;')

    result.append(line)

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

  local count=0
  for chapter in "$src"/[0-9]*.md; do
    [ -f "$chapter" ] || continue
    escape_twig < "$chapter" > "$dest/$(basename "$chapter")"
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
