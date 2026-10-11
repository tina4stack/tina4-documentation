#!/bin/sh
# Copyright (c) 2026 Code Infinity
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Tina4 local AI server - https://tina4.com
# Downloads the self-contained server from tina4.com and runs it: it installs the
# model dependencies, downloads the model once, and serves it with Tina4 (no
# FastAPI, no Flask) on http://127.0.0.1:11437.
#
# Usage:
#   curl -fsSL https://tina4.com/ai-server.sh | sh
#
# Override:
#   AI_SERVER_DIR=~/my-ai   AI_SERVER_PORT=7788   HARNESS_CUDA=cpu   (env before the pipe)
set -eu

BUNDLE_URL="${AI_SERVER_BUNDLE_URL:-https://tina4.com/ai-server.tar.gz}"
DEST="${AI_SERVER_DIR:-$HOME/.tina4/ai-server}"

echo "> Tina4 local AI server"

# The tina4 client runs Tina4 apps - it must be on PATH.
if ! command -v tina4 >/dev/null 2>&1; then
  echo "  tina4 CLI not found. Install it first: https://tina4.com/cli" >&2
  exit 1
fi

# A downloader - curl or wget, whichever is here.
fetch() {  # fetch <url> <out-file>
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then wget -qO "$2" "$1"
  else echo "  need curl or wget to download the server" >&2; exit 1
  fi
}

mkdir -p "$DEST"
tmp="$(mktemp -t ai-server.XXXXXX.tar.gz)"
trap 'rm -f "$tmp"' EXIT

echo "> downloading the server from $BUNDLE_URL ..."
fetch "$BUNDLE_URL" "$tmp"

echo "> unpacking into $DEST ..."
# The tarball holds one top folder (ai-server/); strip it so files land in $DEST.
tar -xzf "$tmp" -C "$DEST" --strip-components=1

echo "> handing off to the server's own setup ..."
cd "$DEST"
chmod +x setup.sh 2>/dev/null || true
exec sh ./setup.sh
