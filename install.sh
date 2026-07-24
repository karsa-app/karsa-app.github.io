#!/usr/bin/env bash
#
# Karsa install bootstrap (spec_01KWAH5K2Q9X §15).
#
# Usage:
#   curl -fsSL https://karsa.app/install.sh | bash
#
# This script is intentionally tiny: it downloads ONLY the `karsa` CLI binary
# for this platform (sha256-verified against the release's .sha256 sidecar),
# lands it on PATH, then hands off to `karsa install` — which reads
# registry.json and installs everything else (karsa-server, web UI, docs).
#
# Env vars (all passed through to `karsa install`):
#   KARSA_VERSION            Pin a release tag (default: latest)
#   KARSA_REPO               GitHub repo (default: karsa-app/karsa)
#   KARSA_INSTALL_DIR        Where binaries land (default: ~/.local/bin)
#   KARSA_HOME               Karsa home (default: ~/.karsa)
#   KARSA_INSTALL_WEB        Install the web UI bundle (default: 1)
#   KARSA_INSTALL_BASE_URL   Override the asset base URL — the CLI, its
#                            .sha256, and (inside `karsa install`) the registry
#                            + every asset are fetched as ${BASE}/<name>.
#                            file:// works, so a locally staged release works.
#

set -euo pipefail

VERSION="${KARSA_VERSION:-latest}"
INSTALL_DIR="${KARSA_INSTALL_DIR:-$HOME/.local/bin}"
REPO="${KARSA_REPO:-karsa-app/karsa}"

red()    { printf "\033[31m%s\033[0m" "$*"; }
green()  { printf "\033[32m%s\033[0m" "$*"; }
yellow() { printf "\033[33m%s\033[0m" "$*"; }
dim()    { printf "\033[2m%s\033[0m"  "$*"; }

die() { red "error: "; echo "$*" >&2; exit 1; }

# --- Detect platform -------------------------------------------------------

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$OS" in
  darwin|linux) ;;
  *) die "unsupported OS: $OS (only darwin and linux are supported)" ;;
esac

case "$ARCH" in
  arm64|aarch64) ARCH=arm64 ;;
  x86_64|amd64)  ARCH=x86_64 ;;
  *) die "unsupported architecture: $ARCH (only arm64 and x86_64 are supported)" ;;
esac

PLATFORM="${OS}-${ARCH}"
CLI_ASSET="karsa-${PLATFORM}"
echo "Platform: $(green "$PLATFORM")"

# --- Resolve asset URLs ----------------------------------------------------

asset_url() {
  # $1 = asset basename (e.g. karsa-darwin-arm64, karsa-darwin-arm64.sha256)
  if [ -n "${KARSA_INSTALL_BASE_URL:-}" ]; then
    echo "${KARSA_INSTALL_BASE_URL%/}/$1"
  elif [ "$VERSION" = "latest" ]; then
    echo "https://github.com/${REPO}/releases/latest/download/$1"
  else
    echo "https://github.com/${REPO}/releases/download/${VERSION}/$1"
  fi
}

file_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# --- Fetch + verify + land the CLI ----------------------------------------

mkdir -p "$INSTALL_DIR"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

URL=$(asset_url "$CLI_ASSET")
echo "Downloading $(dim "$URL")"
curl -fsSL "$URL" -o "$TMP/karsa" || die "download failed: $URL — is the release published?"

# Integrity: the release publishes a .sha256 sidecar per asset.
SHA_URL=$(asset_url "${CLI_ASSET}.sha256")
if curl -fsSL "$SHA_URL" -o "$TMP/karsa.sha256" 2>/dev/null; then
  EXPECTED=$(awk '{print $1}' "$TMP/karsa.sha256")
  ACTUAL=$(file_sha256 "$TMP/karsa")
  [ "$ACTUAL" = "$EXPECTED" ] || die "checksum mismatch for $CLI_ASSET (expected $EXPECTED, got $ACTUAL)"
else
  yellow "→"; echo " no .sha256 sidecar at $SHA_URL; skipping integrity check"
fi

chmod +x "$TMP/karsa"
[ -e "$INSTALL_DIR/karsa" ] && echo "Replacing existing $(dim "$INSTALL_DIR/karsa")"
mv "$TMP/karsa" "$INSTALL_DIR/karsa"
green "✓"; echo " Installed karsa → $INSTALL_DIR/karsa"

# --- Hand off to `karsa install` for everything else -----------------------

echo
echo "Running $(green "karsa install") $(dim "(karsa-server, web UI, docs — from registry.json)")"
echo
"$INSTALL_DIR/karsa" install || die "karsa install failed"

# --- PATH check ------------------------------------------------------------

case ":$PATH:" in
  *":$INSTALL_DIR:"*)
    ;;
  *)
    echo
    yellow "→"; echo " Add $INSTALL_DIR to PATH:"
    echo "    echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.zshrc"
    echo "    # or ~/.bashrc, etc."
    ;;
esac
