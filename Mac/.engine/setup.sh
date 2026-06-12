#!/bin/bash
# Shared, idempotent environment setup for Manifest.
# Sourced by both "Install Manifest.command" and "Manifest.command".
# Safe to run repeatedly; only does work that's actually missing.
#
# Python is provisioned with `uv`, which downloads a SELF-CONTAINED CPython.
# That avoids relying on the Mac's system/Homebrew Python (which is broken on
# some machines, e.g. a libexpat/pyexpat symbol mismatch).

# Run from the app folder (where this script lives).
MANIFEST_APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$MANIFEST_APP_DIR" || return 1

# Make Homebrew tools (uv, deno, node, ffmpeg) visible (Apple Silicon or Intel).
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
[ -x /usr/local/bin/brew ]   && eval "$(/usr/local/bin/brew shellenv)"
# uv may also live in the user-local bin if installed via its own script.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# --- self-update (ZIP installs) ------------------------------------------------
# Pull the latest app code from the repo's `main` and apply it in place, keeping
# the user's venv / token helper / downloads. This is how UI & code changes you
# push reach every user automatically — no re-download. Cloners are updated by the
# launcher's `git pull` instead; set MANIFEST_NO_UPDATE=1 to disable.
MANIFEST_REPO="Slasher1v/Manifest"
MANIFEST_PLATFORM="Mac"   # the repo's top-level folder that holds this build

manifest_self_update() {
  [ -n "$MANIFEST_NO_UPDATE" ] && return 0
  local local_sha latest_sha
  local_sha="$(cat .commit 2>/dev/null)"
  latest_sha="$(curl -fsSL --max-time 5 "https://api.github.com/repos/$MANIFEST_REPO/commits/main" 2>/dev/null \
    | grep -m1 '"sha"' | sed -E 's/.*"sha"[: ]+"([0-9a-f]+)".*/\1/')"
  [ -z "$latest_sha" ] && return 0            # offline / rate-limited → keep current code
  [ "$latest_sha" = "$local_sha" ] && return 0 # already up to date
  echo "==> Updating Manifest to the latest version..."
  local tmp; tmp="$(mktemp -d)" || return 0
  if curl -fsSL --max-time 90 "https://github.com/$MANIFEST_REPO/archive/$latest_sha.tar.gz" -o "$tmp/m.tgz" 2>/dev/null \
     && tar -xzf "$tmp/m.tgz" -C "$tmp" 2>/dev/null; then
    local src="$tmp/Manifest-$latest_sha/$MANIFEST_PLATFORM/.engine"
    if [ -d "$src" ] && [ -f "$src/app.py" ]; then
      # Only code files — never venv / pot-provider / downloads / user data.
      cp -f "$src/app.py" ./app.py 2>/dev/null
      cp -f "$src/requirements.txt" ./requirements.txt 2>/dev/null
      cp -f "$src/setup.sh" ./setup.sh 2>/dev/null
      [ -f "$src/VERSION" ] && cp -f "$src/VERSION" ./VERSION 2>/dev/null
      mkdir -p templates && cp -f "$src/templates/"* templates/ 2>/dev/null
      echo "$latest_sha" > .commit
      # pick up any new Python deps from the refreshed requirements
      [ -x venv/bin/python ] && uv pip install --python venv/bin/python -r requirements.txt >/dev/null 2>&1 || true
      echo "   ✓ updated."
    fi
  fi
  rm -rf "$tmp"
}

# True if the venv is complete (libraries importable) and the token helper is built.
manifest_is_ready() {
  [ -x venv/bin/python ] || return 1
  ./venv/bin/python -c "import flask, yt_dlp, pyexpat" >/dev/null 2>&1 || return 1
  [ -f pot-provider/server/build/main.js ] || return 1
  return 0
}

_ensure_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "==> Installing Homebrew (you may be asked for your Mac password)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1
    [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
    [ -x /usr/local/bin/brew ]   && eval "$(/usr/local/bin/brew shellenv)"
  fi
}

_ensure_tools() {
  # Only install what's actually missing — never force-upgrade already-working
  # tools (that's slow and a single transient download error would abort setup).
  local need=()
  for t in uv deno node ffmpeg; do
    command -v "$t" >/dev/null 2>&1 || need+=("$t")
  done
  if [ ${#need[@]} -gt 0 ]; then
    echo "==> Installing tools: ${need[*]}..."
    brew install "${need[@]}"
  fi
}

_ensure_uv() {
  command -v uv >/dev/null 2>&1 && return 0
  echo "==> Installing uv (Python manager)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh || return 1
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
  command -v uv >/dev/null 2>&1
}

_ensure_venv() {
  # Rebuild if an existing venv's Python is broken (e.g. system-Python expat bug).
  if [ -x venv/bin/python ] && ! ./venv/bin/python -c "import pyexpat" >/dev/null 2>&1; then
    echo "==> Existing Python environment is broken; rebuilding it..."
    rm -rf venv
  fi
  if [ ! -x venv/bin/python ]; then
    echo "==> Creating a self-contained Python environment (via uv)..."
    rm -rf venv
    # --python-preference only-managed => download uv's own CPython, ignore the
    #   Mac's (possibly broken) Python. --seed => include pip in the venv.
    uv venv venv --python 3.13 --python-preference only-managed --seed || return 1
  fi
  if ! ./venv/bin/python -c "import flask, yt_dlp" >/dev/null 2>&1; then
    echo "==> Installing Python libraries (flask, yt-dlp, ...)..."
    uv pip install --python venv/bin/python -r requirements.txt || return 1
  fi
}

# The token helper is third-party (GPL); we fetch it on demand instead of
# bundling it, so this repo stays small and license-clean.
_ensure_pot_source() {
  [ -f pot-provider/server/package.json ] && return 0
  echo "==> Fetching the YouTube token helper (bgutil)..."
  rm -rf pot-provider
  git clone --depth 1 --branch 1.3.1 \
    https://github.com/Brainicism/bgutil-ytdlp-pot-provider.git pot-provider || return 1
}

_ensure_pot() {
  if [ ! -f pot-provider/server/build/main.js ]; then
    echo "==> Building the YouTube token helper..."
    ( cd pot-provider/server \
        && rm -f tsconfig.tsbuildinfo \
        && npm install >/dev/null 2>&1 \
        && npx tsc ) || return 1
  fi
}

# Full setup. Returns 0 only if everything is genuinely ready.
manifest_setup() {
  _ensure_brew        || return 1
  _ensure_tools       || return 1
  _ensure_uv          || return 1
  _ensure_venv        || return 1
  _ensure_pot_source  || return 1
  _ensure_pot         || return 1
  if ! manifest_is_ready; then
    echo "ERROR: setup finished but the environment is still incomplete."
    return 1
  fi
  return 0
}
