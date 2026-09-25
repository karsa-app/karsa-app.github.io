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
#   KARSA_REPO               GitHub repo (default: karsa-app/packages)
#   KARSA_INSTALL_DIR        Where binaries land (default: ~/.local/bin)
#   KARSA_HOME               Karsa home (default: ~/.karsa)
#   KARSA_INSTALL_WEB        Install the web UI bundle (default: 1)
#   KARSA_INSTALL_BASE_URL   Override the asset base URL — the CLI, its
#                            .sha256, and (inside `karsa install`) the registry
#                            + every asset are fetched as ${BASE}/<name>.
#                            file:// works, so a locally staged release works.
#                            (Setting it also skips the private-beta gate.)
#   KARSA_BETA_EMAIL         Your email for the private-beta invite check, for
#                            runs with no terminal to ask on (agents, CI).
#

set -eu
# `curl | sh` runs dash on Debian/Ubuntu, which rejects `set -o pipefail` and
# would kill the script on this line — enable it only where the shell has it.
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi

# --- Deployer-stamped env defaults (spec_01KZ03W7JYA4 §4.1) -----------------
# All empty in source (= prod: GitHub Releases, ~/.local/bin, ~/.karsa). A
# non-prod deploy serves a copy with these set to ITS env's site + install
# layout, so a bare `curl | sh` from a dev site lands in the dev sandbox and
# never touches the machine's real Karsa. Explicit KARSA_* env vars always
# win; stamped values are exported so `karsa install` inherits them.
KARSA_STAMPED_ENV=""
KARSA_STAMPED_BASE_URL=""
KARSA_STAMPED_INSTALL_DIR=""
KARSA_STAMPED_HOME=""
KARSA_STAMPED_PORT=""
if [ -n "$KARSA_STAMPED_BASE_URL" ] && [ -z "${KARSA_INSTALL_BASE_URL:-}" ]; then
  KARSA_INSTALL_BASE_URL="$KARSA_STAMPED_BASE_URL"; export KARSA_INSTALL_BASE_URL
fi
if [ -n "$KARSA_STAMPED_INSTALL_DIR" ] && [ -z "${KARSA_INSTALL_DIR:-}" ]; then
  KARSA_INSTALL_DIR="$KARSA_STAMPED_INSTALL_DIR"; export KARSA_INSTALL_DIR
fi
if [ -n "$KARSA_STAMPED_HOME" ] && [ -z "${KARSA_HOME:-}" ]; then
  KARSA_HOME="$KARSA_STAMPED_HOME"; export KARSA_HOME
fi
if [ -n "$KARSA_STAMPED_PORT" ] && [ -z "${KARSA_PORT:-}" ]; then
  KARSA_PORT="$KARSA_STAMPED_PORT"; export KARSA_PORT
fi

VERSION="${KARSA_VERSION:-latest}"
INSTALL_DIR="${KARSA_INSTALL_DIR:-$HOME/.local/bin}"
REPO="${KARSA_REPO:-karsa-app/packages}"

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

# --- Private-beta gate (spec_01KVE4X4BM2A §6.7) ------------------------------
# Build-stamped by install/build.ts from install/beta.json (empty in source):
# the invite list as salted sha256 hashes (this file is public — never plain
# addresses) and the keyless form endpoint that records every email. A
# courtesy gate, not access control: it sets expectations and keeps the
# waitlist. Only a prod install from the public release is gated — any
# KARSA_INSTALL_BASE_URL (stamped dev sites, file:// test releases) skips it.
BETA_INVITES=""
BETA_FORM_URL=""
BETA_FORM_EMAIL_FIELD=""
BETA_FORM_STATUS_FIELD=""

# beta_hash <email>: must match install/beta.ts `betaHash` exactly.
beta_hash() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "karsa-beta:$1" | sha256sum | awk '{print $1}'
  else
    printf '%s' "karsa-beta:$1" | shasum -a 256 | awk '{print $1}'
  fi
}

# beta_record <email> <invited|waitlist>: best effort, 10s cap. Fails when no
# sink is configured or the POST does not go through.
beta_record() {
  [ -n "$BETA_FORM_URL" ] && [ -n "$BETA_FORM_EMAIL_FIELD" ] || return 1
  if [ -n "$BETA_FORM_STATUS_FIELD" ]; then
    curl -fsS -m 10 -o /dev/null \
      --data-urlencode "$BETA_FORM_EMAIL_FIELD=$1" \
      --data-urlencode "$BETA_FORM_STATUS_FIELD=$2" "$BETA_FORM_URL" 2>/dev/null
  else
    curl -fsS -m 10 -o /dev/null \
      --data-urlencode "$BETA_FORM_EMAIL_FIELD=$1" "$BETA_FORM_URL" 2>/dev/null
  fi
}

beta_gate() {
  echo
  echo "Karsa is in $(yellow "private beta")."
  email="${KARSA_BETA_EMAIL:-}"
  if [ -z "$email" ] && ! (: </dev/tty) 2>/dev/null; then
    echo "The installer needs your email to check your invite, and this shell has"
    echo "no terminal to ask on. Pass it in:"
    echo "    curl -fsSL https://karsa.app/install.sh | KARSA_BETA_EMAIL=you@example.com sh"
    exit 1
  fi
  if [ -z "$email" ] && [ -n "$BETA_FORM_URL" ]; then
    echo "Enter your email. If it's on the invite list, the install continues;"
    echo "if not, you join the waitlist. It goes only to the Karsa team."
  elif [ -z "$email" ]; then
    # No sink stamped: the email is only checked, never sent — say so.
    echo "Enter your email. If it's on the invite list, the install continues."
  fi
  tries=0
  while :; do
    if [ -z "$email" ]; then
      printf "Email: "
      read -r email </dev/tty || email=""
    fi
    email=$(printf '%s' "$email" | tr -d '[:space:]' | tr 'A-Z' 'a-z')
    case "$email" in
      ?*@?*.?*) break ;;
    esac
    tries=$((tries + 1))
    if [ -n "${KARSA_BETA_EMAIL:-}" ] || [ "$tries" -ge 3 ]; then
      die "that doesn't look like an email: '${email}'"
    fi
    echo "That doesn't look like an email. Try again."
    email=""
  done

  hash=$(beta_hash "$email")
  case " $BETA_INVITES " in
    *" $hash "*)
      beta_record "$email" invited || true
      green "✓"; echo " $email is invited. Installing."
      echo
      return 0
      ;;
  esac

  echo
  if beta_record "$email" waitlist; then
    yellow "→"; echo " $email isn't on the invite list yet. You're on the waitlist,"
    echo "  and we'll email you when a spot opens."
  elif [ -n "$BETA_FORM_URL" ]; then
    yellow "→"; echo " $email isn't on the invite list yet, and the waitlist couldn't be"
    echo "  reached just now. Try again later, or ask whoever shared Karsa with you."
  else
    yellow "→"; echo " $email isn't on the invite list yet. Ask whoever shared Karsa with"
    echo "  you for an invite."
  fi
  echo "  Invited under another email? Run the installer again and enter that one."
  exit 1
}

if [ -z "${KARSA_INSTALL_BASE_URL:-}" ]; then
  beta_gate
fi

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

# --- Fetch + verify + land a binary ----------------------------------------

mkdir -p "$INSTALL_DIR"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# fetch_verify_land <asset-basename> <dest-name>: download, sha256-verify against
# the release's sidecar, chmod +x, land on PATH.
fetch_verify_land() {
  asset="$1"; dest="$2"
  url=$(asset_url "$asset")
  echo "Downloading $(dim "$url")"
  curl -fsSL "$url" -o "$TMP/$dest" || die "download failed: $url — is the release published?"
  sha_url=$(asset_url "${asset}.sha256")
  if curl -fsSL "$sha_url" -o "$TMP/$dest.sha256" 2>/dev/null; then
    expected=$(awk '{print $1}' "$TMP/$dest.sha256")
    actual=$(file_sha256 "$TMP/$dest")
    [ "$actual" = "$expected" ] || die "checksum mismatch for $asset (expected $expected, got $actual)"
  else
    yellow "→"; echo " no .sha256 sidecar at $sha_url; skipping integrity check"
  fi
  chmod +x "$TMP/$dest"
  [ -e "$INSTALL_DIR/$dest" ] && echo "Replacing existing $(dim "$INSTALL_DIR/$dest")"
  mv "$TMP/$dest" "$INSTALL_DIR/$dest"
  green "✓"; echo " Installed $dest → $INSTALL_DIR/$dest"
}

# The bootstrap lands BOTH binaries (spec_01KYWJVEVA02): the launcher `karsa` and
# the daemon `karsa-server`. The CLI is a thin client of the daemon, so the daemon
# must not be provisioned BY the CLI — the two binaries you need to run a daemon
# come straight from the release.
fetch_verify_land "$CLI_ASSET" "karsa"
fetch_verify_land "karsa-server-${PLATFORM}" "karsa-server"

# --- Hand off to `karsa install` for the rest (web UI, docs) ---------------

echo
echo "Running $(green "karsa install") $(dim "(web UI, docs — from registry.json; the daemon is already landed)")"
echo
"$INSTALL_DIR/karsa" install || die "karsa install failed"

# --- Non-prod launcher -----------------------------------------------------
# A stamped non-prod install generates `karsa-<env>` beside the binaries: it
# pins this env's KARSA_HOME (+ port) so later shells don't need the env vars,
# and its distinct name can't hijack a real `karsa` (the .karsa-dev pattern).

if [ -n "$KARSA_STAMPED_ENV" ] && [ "$KARSA_STAMPED_ENV" != "prod" ] && [ -n "${KARSA_HOME:-}" ]; then
  LNAME="karsa-$KARSA_STAMPED_ENV"
  LAUNCHER="$INSTALL_DIR/$LNAME"
  {
    echo "#!/usr/bin/env bash"
    echo "# Generated by install.sh (env: $KARSA_STAMPED_ENV). Runs karsa against this env's home."
    if [ -n "${KARSA_PORT:-}" ]; then
      echo "exec env KARSA_HOME='$KARSA_HOME' KARSA_PORT='$KARSA_PORT' '$INSTALL_DIR/karsa' \"\$@\""
    else
      echo "exec env KARSA_HOME='$KARSA_HOME' '$INSTALL_DIR/karsa' \"\$@\""
    fi
  } > "$LAUNCHER"
  chmod +x "$LAUNCHER"
  echo
  green "✓"; echo " Launcher: $LAUNCHER"
  echo
  echo "Alias it (safe: distinct name — no PATH change, can't shadow a real karsa):"
  echo "    alias $LNAME='$LAUNCHER'"
  echo
  echo "Then:"
  echo "    $LNAME start      $(dim "# start the $KARSA_STAMPED_ENV daemon (home: $KARSA_HOME)")"
  echo "    $LNAME            $(dim "# status dashboard")"
  echo "    $LNAME doctor     $(dim "# resolved services (provenance) + tools")"
  echo "    $LNAME stop       $(dim "# stop the $KARSA_STAMPED_ENV daemon")"
else
  # --- PATH check (prod installs only — a sandbox bin must NOT go on PATH) --
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
fi
