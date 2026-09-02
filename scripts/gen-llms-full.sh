#!/usr/bin/env bash
# Generate docs/public/llms-full.txt - the whole Tina4 documentation concatenated
# into one file, for language models and tools that ingest a single text file (the
# llms-full.txt convention). llms.txt is the curated map; this is the full text.
#
# It runs as the first step of `docs:build`, so it is regenerated on every build and
# never drifts from the docs. The output is gitignored: it is a build artifact, not a
# source file, exactly like docs/.vitepress/dist. rag.tina4.com stays the queryable,
# always-current option; this serves tools that cannot call it.
#
#   bash scripts/gen-llms-full.sh
set -eu
here="$(cd "$(dirname "$0")/.." && pwd)"
cd "$here"
out="docs/public/llms-full.txt"

# Every docs markdown file except the built site and the static-asset folder itself.
files="$(find docs -type f -name '*.md' \
  -not -path 'docs/public/*' -not -path 'docs/.vitepress/*' \
  | LC_ALL=C sort)"

{
  echo "# Tina4 Framework - Full Documentation"
  echo ""
  echo "One file with the whole Tina4 documentation, for language models and tools that"
  echo "read a single text file. The curated map is at https://tina4.com/llms.txt. For a"
  echo "queryable, always-current version, ask https://rag.tina4.com/v1/ask. When a Tina4"
  echo "dev server is running, its /__dev/mcp tools are the exact source for API signatures."
  echo ""
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s\n' "$files" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="${f#docs/}"
    echo ""
    echo "================================================================================"
    echo "FILE: $rel"
    echo "================================================================================"
    echo ""
    cat "$f"
    echo ""
  done
} > "$out"

echo "wrote $out ($(printf '%s\n' "$files" | grep -c . ) docs, $(wc -l < "$out" | tr -d ' ') lines, $(wc -c < "$out" | tr -d ' ') bytes)"
