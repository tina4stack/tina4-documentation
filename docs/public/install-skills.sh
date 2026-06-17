#!/usr/bin/env bash
# Tina4 AI skills installer for macOS / Linux
# Usage: curl -fsSL https://raw.githubusercontent.com/tina4stack/tina4/main/install-skills.sh | sh
#
# Installs the tina4 AI skills (tina4-developer, tina4-js) into ~/.claude/skills
# so Claude Desktop / Claude Code use Tina4 conventions out of the box.
# Stopgap until `tina4 skills install` ships embedded in the CLI binary.
set -euo pipefail

base="https://raw.githubusercontent.com/tina4stack/tina4-python/v3/.claude/skills"
dest="$HOME/.claude/skills"

install_skill() {
  skill="$1"; shift
  mkdir -p "$dest/$skill/references"
  curl -fsSL "$base/$skill/SKILL.md" -o "$dest/$skill/SKILL.md"
  for ref in "$@"; do
    curl -fsSL "$base/$skill/references/$ref" -o "$dest/$skill/references/$ref"
  done
  echo "  + $skill"
}

echo ""
echo "  Tina4 Skills Installer"
echo "  Installing to: $dest"
echo ""

install_skill tina4-developer auth-and-services.md data-and-orm.md deployment.md routes-and-api.md templates-and-frontend.md
install_skill tina4-js html-and-components.md signals-and-reactivity.md

echo ""
echo "  Done. Restart Claude (Desktop/Code) to pick up the skills."
echo ""
