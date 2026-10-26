#!/bin/sh
# Copyright (c) 2026 Code Infinity
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Tina4 CLI installer — https://tina4.com
# Usage: curl -fsSL https://raw.githubusercontent.com/tina4stack/tina4/main/install.sh | sh
#    or: wget -qO- https://raw.githubusercontent.com/tina4stack/tina4/main/install.sh | sh
set -e

REPO="tina4stack/tina4"
INSTALL_DIR="${TINA4_INSTALL_DIR:-/usr/local/bin}"
MUSL_ONLY=""

# Detect OS and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Darwin)  PLATFORM="darwin" ;;
  Linux)   PLATFORM="linux" ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
  *) echo "Error: Unsupported OS: $OS" >&2; exit 1 ;;
esac

# Android (Termux) reports itself as Linux, but it has no glibc: the libc is
# Bionic, so the glibc build fails to exec with "GLIBC_x.y not found" or a
# misleading "No such file or directory" (its loader is missing). The static
# musl build is no way out either: Termux's termux-exec runs binaries through
# /system/bin/linker64, which rejects a non-PIE static binary ("unexpected
# e_type: 2"), and musl's resolver finds no /etc/resolv.conf there. Only the
# native Android build (tina4-android-*) runs. Termux also has no
# /usr/local/bin - its binaries live in $PREFIX/bin.
ANDROID=""
if [ "$PLATFORM" = "linux" ] && { [ "$(uname -o 2>/dev/null)" = "Android" ] || [ -n "${TERMUX_VERSION:-}" ]; }; then
  ANDROID="1"
  if [ -z "${TINA4_INSTALL_DIR:-}" ] && [ -n "${PREFIX:-}" ]; then
    INSTALL_DIR="${PREFIX}/bin"
  fi
fi

case "$ARCH" in
  x86_64|amd64)  ARCH_NAME="amd64" ;;
  arm64|aarch64)  ARCH_NAME="arm64" ;;
  # 32-bit x86 is what iSH (Linux shell on iPhone/iPad) emulates. Only a static
  # musl build is published for it, so it always takes the musl path below.
  i386|i486|i586|i686)  ARCH_NAME="386"; MUSL_ONLY="1" ;;
  *)
    echo "Error: Unsupported architecture: $ARCH" >&2
    echo "  Prebuilt binaries cover x86_64 and arm64. Build from source with:" >&2
    echo "    cargo install tina4   (needs Rust - https://rustup.rs)" >&2
    exit 1 ;;
esac

# Helper: download a URL to stdout
fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$1"
  else
    echo "Error: curl or wget is required" >&2
    exit 1
  fi
}

# Helper: download a URL to a file
fetch_to() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  else
    wget -q "$1" -O "$2"
  fi
}

# Helper: does a URL exist (HTTP 2xx, following redirects)?  Used to pick the
# right release asset by probing its download URL rather than reading the API's
# asset list - so asset selection stays off api.github.com too.
url_exists() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsL -I -o /dev/null "$1" >/dev/null 2>&1
  else
    wget -q --spider "$1" >/dev/null 2>&1
  fi
}

# Latest release tag from GitHub's releases/latest redirect, NOT the atom feed
# and NOT the REST API. api.github.com's unauthenticated limit is 60 requests/
# hour per IP, so an install from a shared or NAT'd IP (an office, a CI runner)
# would fail with a rate-limit body. The atom feed lists every pushed TAG,
# including one whose release is still an unpublished DRAFT during a sign-and-
# publish window - installing against it 404s on the assets. releases/latest is
# served from github.com (no rate limit) and GitHub excludes drafts AND
# prereleases from it, so the redirect lands on the latest PUBLISHED release's
# page. `fetch` follows the 302; the canonical og:url meta carries the tag. The
# [A-Za-z0-9] guard skips the /releases/tag/*name placeholder the "Draft a new
# release" form emits, which a naive first-match would otherwise return.
PAGE=$(fetch "https://github.com/${REPO}/releases/latest")
LATEST=$(printf '%s' "$PAGE" \
  | grep -oE 'og:url[^>]*content="[^"]*/releases/tag/[A-Za-z0-9][^"]*"' \
  | head -1 | sed 's#.*/releases/tag/##; s#".*##')
[ -z "$LATEST" ] && LATEST=$(printf '%s' "$PAGE" \
  | grep -oE '/releases/tag/[A-Za-z0-9][^"<&]*' | head -1 | sed 's#.*/releases/tag/##')

if [ -z "$LATEST" ]; then
  echo "Error: Could not determine latest release" >&2
  exit 1
fi

# Match the correct binary. Releases may use varying names (amd64 vs x86_64,
# darwin vs macos), so build the candidate list for this platform and pick the
# first whose download URL actually exists (probed, not read from the API).
if [ "$PLATFORM" = "windows" ]; then
  CANDIDATES="tina4-windows-${ARCH_NAME}.exe tina4-windows-$([ "$ARCH_NAME" = "amd64" ] && echo x86_64 || echo "$ARCH_NAME").exe"
elif [ -n "$ANDROID" ]; then
  # Android (Termux) can only run the native Android build, and 32-bit x86
  # (iSH on iOS) only the static musl build, so each is the ONLY candidate
  # there - any fallback would install a binary that cannot exec.
  CANDIDATES="tina4-android-${ARCH_NAME}"
elif [ -n "$MUSL_ONLY" ]; then
  CANDIDATES="tina4-linux-musl-${ARCH_NAME}"
else
  CANDIDATES="tina4-${PLATFORM}-${ARCH_NAME} \
    tina4-${PLATFORM}-$([ "$ARCH_NAME" = "amd64" ] && echo x86_64 || echo "$ARCH_NAME") \
    tina4-$([ "$PLATFORM" = "darwin" ] && echo macos || echo "$PLATFORM")-${ARCH_NAME} \
    tina4-$([ "$PLATFORM" = "darwin" ] && echo macos || echo "$PLATFORM")-$([ "$ARCH_NAME" = "amd64" ] && echo x86_64 || echo "$ARCH_NAME")"
fi

BINARY=""
for CANDIDATE in $CANDIDATES; do
  if url_exists "https://github.com/${REPO}/releases/download/${LATEST}/${CANDIDATE}"; then
    BINARY="$CANDIDATE"
    break
  fi
done

if [ -z "$BINARY" ]; then
  echo "Error: No matching binary found for ${PLATFORM}/${ARCH_NAME} in release ${LATEST}" >&2
  echo "Tried: ${CANDIDATES}" >&2
  echo "See https://github.com/${REPO}/releases/tag/${LATEST}" >&2
  exit 1
fi

URL="https://github.com/${REPO}/releases/download/${LATEST}/${BINARY}"

echo ""
echo "  Tina4 CLI Installer"
echo "  ==================="
echo "  Version:      ${LATEST}"
echo "  Platform:     ${PLATFORM}/${ARCH_NAME}${ANDROID:+ (Android/Termux) - native Android build}${MUSL_ONLY:+ - static musl build}"
echo "  Install to:   ${INSTALL_DIR}/tina4"
echo ""

TMP=$(mktemp)
echo "Downloading ${BINARY}..."
fetch_to "$URL" "$TMP"

# Verify integrity against the release SHA256SUMS before trusting the binary.
# SHA256SUMS is mandatory; missing or mismatched integrity data aborts installation.
SUMS_TMP=$(mktemp)
if fetch_to "https://github.com/${REPO}/releases/download/${LATEST}/SHA256SUMS" "$SUMS_TMP" 2>/dev/null && [ -s "$SUMS_TMP" ]; then
  EXPECTED=$(grep -E "[[:space:]]\*?${BINARY}\$" "$SUMS_TMP" | awk '{print $1}' | head -1)
  if [ -z "$EXPECTED" ]; then
    echo "Error: ${BINARY} is not listed in SHA256SUMS for ${LATEST}" >&2
    rm -f "$TMP" "$SUMS_TMP"; exit 1
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    ACTUAL=$(sha256sum "$TMP" | awk '{print $1}')
  elif command -v shasum >/dev/null 2>&1; then
    ACTUAL=$(shasum -a 256 "$TMP" | awk '{print $1}')
  else
    echo "Error: no sha256 tool (sha256sum or shasum) available to verify the download" >&2
    rm -f "$TMP" "$SUMS_TMP"; exit 1
  fi
  if [ "$EXPECTED" != "$ACTUAL" ]; then
    echo "Error: checksum mismatch for ${BINARY} - refusing to install" >&2
    echo "  expected: ${EXPECTED}" >&2
    echo "  actual:   ${ACTUAL}" >&2
    rm -f "$TMP" "$SUMS_TMP"; exit 1
  fi
  echo "Checksum verified (sha256)."
else
  # Fail closed: a missing SHA256SUMS means we cannot prove the download is the
  # published binary, so we do NOT install it. (Every release from 3.8.53 on
  # publishes SHA256SUMS; a build old enough to lack it can be installed by
  # pinning an explicit older asset by hand.)
  echo "Error: SHA256SUMS is not available for ${LATEST} - refusing to install an unverified binary." >&2
  rm -f "$TMP" "$SUMS_TMP"; exit 1
fi
rm -f "$SUMS_TMP"

chmod +x "$TMP"

# Install. The target directory may not exist yet: a clean macOS has no
# /usr/local/bin (it was historically created by Homebrew), so a bare `mv` there
# fails with "No such file or directory". Create the directory first, then move
# without sudo when we can and escalate only when the location needs root.
if [ -d "$INSTALL_DIR" ] && [ -w "$INSTALL_DIR" ]; then
  mv "$TMP" "${INSTALL_DIR}/tina4"
elif mkdir -p "$INSTALL_DIR" 2>/dev/null && [ -w "$INSTALL_DIR" ]; then
  mv "$TMP" "${INSTALL_DIR}/tina4"
else
  echo "Need sudo to install to ${INSTALL_DIR}"
  sudo mkdir -p "$INSTALL_DIR"
  sudo mv "$TMP" "${INSTALL_DIR}/tina4"
fi

echo ""
echo "✓ tina4 ${LATEST} installed successfully"
echo ""

# Always print the command list FIRST, so that if setup is interrupted or
# crashes the user still has `tina4 setup` on screen to run again.
echo "Get started (these work any time):"
echo "  tina4 setup    — Guided onboarding: language + AI tool + first project"
echo "  tina4 doctor   — Check your environment"
echo "  tina4 serve    — Start the dev server"
echo ""

# Launch guided setup now. `curl | sh` leaves stdin attached to the pipe (not
# the keyboard), so read the answers from the controlling terminal. With no tty
# (CI / non-interactive) we skip the launch — the commands above already tell
# the user how to run it. A non-zero exit prints a clear retry hint.
# `[ -r /dev/tty ]` alone is NOT enough: it is a permission/stat test, and it
# passes on a headless host where /dev/tty exists but the process has NO
# controlling terminal. The open then fails and every such install ends on
# "cannot open /dev/tty: No such device or address" -- verified on a real
# headless box (sudo over ssh). Actually TRY the open in a subshell; only launch
# the interactive wizard if that succeeds. Docker / CI / provisioning runs now
# finish clean on the "run tina4 setup" hint already printed above.
if [ -r /dev/tty ] && (exec < /dev/tty) 2>/dev/null; then
  echo "  Starting setup..."
  echo ""
  if ! "${INSTALL_DIR}/tina4" setup < /dev/tty; then
    echo ""
    echo "  Setup didn't finish. Run it again any time with: tina4 setup"
  fi
fi
