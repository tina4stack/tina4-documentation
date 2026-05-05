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
  *) echo "Error: Unsupported architecture: $ARCH" >&2; exit 1 ;;
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
echo "Get started:"
echo "  tina4 doctor   — Check your environment"
echo "  tina4 init     — Create a new project"
echo "  tina4 serve    — Start development server"
echo ""
