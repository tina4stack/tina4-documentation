#!/usr/bin/env bash
# Tina4 documentation installer entry point.
# The installer implementation lives in tina4stack/tina4 so the published
# documentation and the Tina4 client always use the same target selection.
#
# Examples:
#   curl -fsSL https://tina4.com/install-skills.sh | TINA4_SKILLS_TARGET=claude sh
#   curl -fsSL https://tina4.com/install-skills.sh | TINA4_SKILLS_TARGET=codex sh
set -euo pipefail
curl -fsSL https://raw.githubusercontent.com/tina4stack/tina4/main/install-skills.sh | sh
