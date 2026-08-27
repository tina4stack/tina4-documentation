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

primary_url="https://raw.githubusercontent.com/tina4stack/tina4/3.13.120/install-skills.sh"
mirror_url="https://cdn.jsdelivr.net/gh/tina4stack/tina4@3.13.120/install-skills.sh"

# Download to a file and CHECK it, rather than `curl ... | sh`.
#
# Without pipefail, a piped `curl | sh` reports the exit status of SH, not of
# curl. A network failure or a 404 then feeds an EMPTY script into sh, which
# exits 0 -- a silent no-op indistinguishable from a successful install. Since
# a silent no-op is the very complaint being fixed, the fix must not reintroduce
# it by another route.
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT INT TERM

if ! curl -fsSL --retry 3 --retry-delay 2 "$primary_url" -o "$tmp" &&
   ! curl -fsSL --retry 3 --retry-delay 2 "$mirror_url" -o "$tmp"; then
  echo "error: could not download the Tina4 skills installer from either source" >&2
  exit 1
fi

if [ ! -s "$tmp" ]; then
  echo "error: the Tina4 skills installer downloaded an empty response" >&2
  exit 1
fi

sh "$tmp"
