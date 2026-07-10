#!/usr/bin/env bash
# Tina4 AI skills installer for macOS / Linux
# Usage: curl -fsSL https://raw.githubusercontent.com/tina4stack/tina4/main/install-skills.sh | sh
#
# Installs the tina4 AI skills into ~/.claude/skills so Claude Desktop / Claude Code
# use Tina4 conventions out of the box. As of 3.13.66 the developer skill is split
# per language (each owned by its framework repo); tina4-js + tina4-maintainer are shared.
# Stopgap until `tina4 skills install` ships embedded in the CLI binary.
set -euo pipefail

# Pin skills to a released tag, not a moving branch, so an install is reproducible.
# Bump this when the skills change in a new release. Override with TINA4_SKILLS_REF.
ref="${TINA4_SKILLS_REF:-3.13.66}"
dest="$HOME/.claude/skills"

# install_skill <repo> <skill> <reference.md ...>
install_skill() {
  repo="$1"; skill="$2"; shift 2
  base="https://raw.githubusercontent.com/tina4stack/${repo}/${ref}/.claude/skills"
  mkdir -p "$dest/$skill/references"
  curl -fsSL "$base/$skill/SKILL.md" -o "$dest/$skill/SKILL.md"
  for r in "$@"; do
    curl -fsSL "$base/$skill/references/$r" -o "$dest/$skill/references/$r"
  done
  echo "  + $skill  ($repo)"
}

DEV_REFS="auth-and-services.md data-and-orm.md deployment.md routes-and-api.md templates-and-frontend.md realtime.md"

echo ""
echo "  Tina4 Skills Installer"
echo "  Installing to: $dest  (ref: $ref)"
echo ""

# Per-language developer skills (each from its own framework repo)
install_skill tina4-python  tina4-developer-python  $DEV_REFS
install_skill tina4-php     tina4-developer-php     $DEV_REFS
install_skill tina4-ruby    tina4-developer-ruby    $DEV_REFS
install_skill tina4-nodejs  tina4-developer-nodejs  $DEV_REFS
# Shared skills (canonical copy served from tina4-python)
install_skill tina4-python  tina4-js          html-and-components.md signals-and-reactivity.md persistence.md rtc.md
install_skill tina4-python  tina4-maintainer  cli-and-deployment.md frond-and-frontend.md routing-and-orm.md subsystems.md

echo ""
echo "  Done — six skills installed. Restart Claude (Desktop/Code) to pick them up."
echo ""
