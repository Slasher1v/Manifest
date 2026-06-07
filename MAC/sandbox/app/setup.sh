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
  echo "==> Ensuring tools (uv, deno, node, ffmpeg)..."
  brew install uv deno node ffmpeg
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
