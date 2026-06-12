#!/bin/bash
#
# Manifest.app launcher (Contents/MacOS/Manifest).
#
# The app bundle stays read-only; the actual engine (code + venv + token helper)
# lives in ~/Library/Application Support/Manifest/engine so it can self-update and
# so /Applications doesn't need to be writable. First run shows a Terminal for the
# one-time setup; after that the app runs quietly (Dock icon — Cmd-Q to quit).

APPSUP="$HOME/Library/Application Support/Manifest"
ENGINE="$APPSUP/engine"
RES="$(cd "$(dirname "$0")/../Resources/engine" 2>/dev/null && pwd)"
APP_BUNDLE="$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)"

mkdir -p "$APPSUP"
# Seed the engine code from inside the bundle on first run.
if [ ! -d "$ENGINE" ] && [ -n "$RES" ]; then
  cp -R "$RES" "$ENGINE"
fi

# Make Homebrew + uv tools visible.
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
[ -x /usr/local/bin/brew ]   && eval "$(/usr/local/bin/brew shellenv)"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

cd "$ENGINE" 2>/dev/null || exit 1

_ready() {
  [ -x venv/bin/python ] && ./venv/bin/python -c "import flask, yt_dlp" >/dev/null 2>&1 \
    && [ -f pot-provider/server/build/main.js ]
}

# Already running? Just bring the UI up.
if curl -s -o /dev/null --max-time 2 "http://127.0.0.1:8000/"; then
  open "http://127.0.0.1:8000"
  exit 0
fi

# First-time setup / repair: show progress in Terminal, then relaunch the app.
if ! _ready; then
  /usr/bin/osascript <<OSA
tell application "Terminal"
  activate
  do script "clear; echo 'Setting up Manifest (one-time, a few minutes)...'; echo; cd '$ENGINE'; source ./setup.sh; if manifest_setup; then echo; echo 'Done. Launching Manifest...'; open '$APP_BUNDLE'; echo 'You can close this window.'; else echo; echo 'Setup did not finish - scroll up for the error, then try again.'; fi"
end tell
OSA
  exit 0
fi

# Ready -> run quietly as a Dock app (Cmd-Q to stop).
# shellcheck disable=SC1091
source ./setup.sh 2>/dev/null
type manifest_self_update >/dev/null 2>&1 && manifest_self_update

if ! curl -s -o /dev/null --max-time 2 "http://127.0.0.1:4416/ping"; then
  node pot-provider/server/build/main.js >/tmp/manifest-pot.log 2>&1 &
  POT_PID=$!
fi
_cleanup() { [ -n "$POT_PID" ] && kill "$POT_PID" 2>/dev/null; }
trap _cleanup EXIT INT TERM

( sleep 2; open "http://127.0.0.1:8000" ) &
exec ./venv/bin/python app.py
