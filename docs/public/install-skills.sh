#!/usr/bin/env bash
# Tina4 AI skills installer for macOS / Linux
# Usage: curl -fsSL https://raw.githubusercontent.com/tina4stack/tina4/main/install-skills.sh | sh
#
# Installs the tina4 AI skills (tina4-developer, tina4-js) into ~/.claude/skills
# so Claude Desktop / Claude Code use Tina4 conventions out of the box.
# Stopgap until `tina4 skills install` ships embedded in the CLI binary.
set -euo pipefail

# Pin skills to a released tag, not a moving branch, so an install is
# reproducible and auditable. Bump this when the skills change in a new
# tina4-python release. Override with TINA4_SKILLS_REF if you need a branch.
ref="${TINA4_SKILLS_REF:-3.13.56}"
base="https://raw.githubusercontent.com/tina4stack/tina4-python/${ref}/.claude/skills"
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
install_skill tina4-js html-and-components.md signals-and-reactivity.md persistence.md

echo ""
echo "  Done. Restart Claude (Desktop/Code) to pick up the skills."
echo ""
