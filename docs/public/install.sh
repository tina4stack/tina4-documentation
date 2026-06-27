#!/bin/sh
# Tina4 CLI installer — https://tina4.com
# Usage: curl -fsSL https://raw.githubusercontent.com/tina4stack/tina4/main/install.sh | sh
#    or: wget -qO- https://raw.githubusercontent.com/tina4stack/tina4/main/install.sh | sh
set -e

REPO="tina4stack/tina4"
INSTALL_DIR="${TINA4_INSTALL_DIR:-/usr/local/bin}"

# Detect OS and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Darwin)  PLATFORM="darwin" ;;
  Linux)   PLATFORM="linux" ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
  *) echo "Error: Unsupported OS: $OS" >&2; exit 1 ;;
esac

case "$ARCH" in
  x86_64|amd64)  ARCH_NAME="amd64" ;;
  arm64|aarch64)  ARCH_NAME="arm64" ;;
  i386|i486|i586|i686)
    echo "Error: 32-bit x86 ($ARCH) is not supported - tina4 ships 64-bit builds only." >&2
    echo "  Build from source on this machine with: cargo install tina4" >&2
    echo "  (needs the Rust toolchain - https://rustup.rs), or use a 64-bit OS." >&2
    exit 1 ;;
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

# Get latest release metadata (tag + asset list)
RELEASE_JSON=$(fetch "https://api.github.com/repos/${REPO}/releases/latest")

LATEST=$(echo "$RELEASE_JSON" | grep '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')

if [ -z "$LATEST" ]; then
  echo "Error: Could not determine latest release" >&2
  exit 1
fi

# Match the correct binary from release assets.
# Releases may use varying names (e.g. amd64 vs x86_64, darwin vs macos).
if [ "$PLATFORM" = "windows" ]; then
  BINARY=$(echo "$RELEASE_JSON" | grep -oE '"name": *"tina4-windows-[^"]+\.exe"' | head -1 | sed -E 's/"name": *"([^"]+)"/\1/')
else
  # Try the canonical name first (tina4-linux-amd64), then common alternatives
  for CANDIDATE in \
    "tina4-${PLATFORM}-${ARCH_NAME}" \
    "tina4-${PLATFORM}-$([ "$ARCH_NAME" = "amd64" ] && echo x86_64 || echo "$ARCH_NAME")" \
    "tina4-$([ "$PLATFORM" = "darwin" ] && echo macos || echo "$PLATFORM")-${ARCH_NAME}" \
    "tina4-$([ "$PLATFORM" = "darwin" ] && echo macos || echo "$PLATFORM")-$([ "$ARCH_NAME" = "amd64" ] && echo x86_64 || echo "$ARCH_NAME")"
  do
    if echo "$RELEASE_JSON" | grep -q "\"name\": *\"${CANDIDATE}\""; then
      BINARY="$CANDIDATE"
      break
    fi
  done
fi

if [ -z "$BINARY" ]; then
  echo "Error: No matching binary found for ${PLATFORM}/${ARCH_NAME} in release ${LATEST}" >&2
  echo "Available assets:" >&2
  echo "$RELEASE_JSON" | grep '"name"' | sed -E 's/.*"name": *"([^"]+)".*/  \1/' >&2
  exit 1
fi

URL="https://github.com/${REPO}/releases/download/${LATEST}/${BINARY}"

echo ""
echo "  Tina4 CLI Installer"
echo "  ==================="
echo "  Version:      ${LATEST}"
echo "  Platform:     ${PLATFORM}/${ARCH_NAME}"
echo "  Install to:   ${INSTALL_DIR}/tina4"
echo ""

TMP=$(mktemp)
echo "Downloading ${BINARY}..."
fetch_to "$URL" "$TMP"

# Verify integrity against the release SHA256SUMS before trusting the binary.
# Releases from 3.8.53 publish SHA256SUMS; when it is present we verify strictly
# and abort on any mismatch. Older releases predate it, so we warn and continue
# (a pinned older install still works).
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
  echo "Note: no SHA256SUMS published for ${LATEST} - skipping integrity check (older release)." >&2
fi
rm -f "$SUMS_TMP"

chmod +x "$TMP"

# Install — try without sudo first
if [ -w "$INSTALL_DIR" ]; then
  mv "$TMP" "${INSTALL_DIR}/tina4"
else
  echo "Need sudo to install to ${INSTALL_DIR}"
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
if [ -r /dev/tty ]; then
  echo "  Starting setup..."
  echo ""
  if ! "${INSTALL_DIR}/tina4" setup < /dev/tty; then
    echo ""
    echo "  Setup didn't finish. Run it again any time with: tina4 setup"
  fi
fi
