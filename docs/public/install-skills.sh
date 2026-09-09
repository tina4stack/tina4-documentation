#!/bin/sh
# Tina4 documentation installer entry point.
# The installer implementation lives in tina4stack/tina4 so the published
# documentation and the Tina4 client always use the same target selection.
#
# Examples:
#   curl -fsSL https://tina4.com/install-skills.sh | TINA4_SKILLS_TARGET=claude sh
#   curl -fsSL https://tina4.com/install-skills.sh | TINA4_SKILLS_TARGET=codex sh
#   curl -fsSL https://tina4.com/install-skills.sh | TINA4_SKILLS_TARGET=cursor sh
#
# POSIX sh ONLY. Every documented invocation pipes into `sh`, and on
# Debian/Ubuntu that is dash. This file used `set -euo pipefail`, so the
# documented command died on its first real line with
#
#     sh: 9: set: Illegal option -o pipefail
#
# and installed nothing. It passed on macOS, where /bin/sh is bash in POSIX
# mode and accepts pipefail, which is why it went unnoticed here while Linux
# users reported a broken install.
set -eu

# The skills release this bootstrap installs. One pin, honoured as an override,
# used to build all three source URLs below. `tina4 doctor` reads this default to
# report skills currency, and scripts/bump-skills-ref.sh bumps it at release.
# Keep this assignment the FIRST place the override name appears in the file: the
# doctor takes the first occurrence, so a comment must not spell out the token.
ref="${TINA4_SKILLS_REF:-3.13.135}"

# Fetch the inner installer from tina4.com FIRST (Tina4's own infra, Jenkins-
# deployed), then jsDelivr, then raw.githubusercontent as fallbacks. GitHub raw
# 503s during incidents, so leading with tina4.com keeps the common path off
# GitHub; the fallbacks keep the install working if tina4.com is ever down.
tina4_url="https://tina4.com/skills/${ref}/install-skills.sh"
jsdelivr_url="https://cdn.jsdelivr.net/gh/tina4stack/tina4@${ref}/install-skills.sh"
raw_url="https://raw.githubusercontent.com/tina4stack/tina4/${ref}/install-skills.sh"

# Download to a file and CHECK it, rather than `curl ... | sh`.
#
# Without pipefail, a piped `curl | sh` reports the exit status of SH, not of
# curl. A network failure or a 404 then feeds an EMPTY script into sh, which
# exits 0 -- a silent no-op indistinguishable from a successful install. Since
# a silent no-op is the very complaint being fixed, the fix must not reintroduce
# it by another route.
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT INT TERM

if ! curl -fsSL --retry 3 --retry-delay 2 "$tina4_url" -o "$tmp" &&
   ! curl -fsSL --retry 3 --retry-delay 2 "$jsdelivr_url" -o "$tmp" &&
   ! curl -fsSL --retry 3 --retry-delay 2 "$raw_url" -o "$tmp"; then
  echo "error: could not download the Tina4 skills installer from any source" >&2
  exit 1
fi

if [ ! -s "$tmp" ]; then
  echo "error: the Tina4 skills installer downloaded an empty response" >&2
  exit 1
fi

sh "$tmp"
