#!/bin/bash
#
# Manifest — launcher (double-click me to start the app).
# Keep this window open while you use Manifest. To stop: close the window.
#
clear
echo "======================================================"
echo "            Starting  M A N I F E S T"
echo "======================================================"

HERE="$(cd "$(dirname "$0")" && pwd)"

# --- auto-update Manifest itself ------------------------------------------------
# If this is a git clone on the main branch, pull the latest released code.
# (Mac/ sits at the repo root, so the repo is one level up.)
REPO_ROOT="$(cd "$HERE/.." 2>/dev/null && pwd)"
if [ -n "$REPO_ROOT" ] && [ -d "$REPO_ROOT/.git" ] && \
   [ "$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)" = "main" ]; then
  echo "==> Updating Manifest (git)..."
  git -C "$REPO_ROOT" pull --ff-only 2>/dev/null || true
fi
# For everyone (incl. ZIP downloads): check the latest GitHub release and notify.
LOCAL_VER="$(cat "$HERE/.engine/VERSION" 2>/dev/null || echo 0)"
LATEST_VER="$(curl -fsSL --max-time 4 https://api.github.com/repos/Slasher1v/Manifest/releases/latest 2>/dev/null \
  | grep '"tag_name"' | head -1 | sed -E 's/.*"v?([^"]+)".*/\1/')"
if [ -n "$LATEST_VER" ] && [ "$LATEST_VER" != "$LOCAL_VER" ]; then
  echo "  🔔 A new version ($LATEST_VER) is available!"
  echo "     Download: https://github.com/Slasher1v/Manifest/releases/latest"
fi

cd "$HERE/.engine" || { echo "Could not find the app files."; read -r -p "Press Return to close." _; exit 1; }

# shellcheck disable=SC1091
source ./setup.sh

# Self-heal: if anything is missing or a previous install half-finished, fix it.
if ! manifest_is_ready; then
  echo "==> First-time setup / repair needed. This may take a few minutes..."
  if ! manifest_setup; then
    echo
    echo "Setup couldn't complete. Please double-click 'Install Manifest.command'"
    echo "and watch for any errors."
    read -r -p "Press Return to close." _
    exit 1
  fi
fi

# Keep yt-dlp fresh (sites change often); quiet + never fatal.
echo "==> Checking for updates..."
uv pip install --python venv/bin/python -U "yt-dlp[default]" >/dev/null 2>&1 || true

# Start the YouTube token server if it isn't already running.
if ! curl -s -o /dev/null --max-time 2 http://127.0.0.1:4416/ping; then
  echo "==> Starting token server..."
  node pot-provider/server/build/main.js >/tmp/manifest-pot.log 2>&1 &
  POT_PID=$!
  trap 'kill $POT_PID 2>/dev/null' EXIT   # stop it when this window closes
  sleep 1
fi

# Open the app in the browser shortly after the server boots.
( sleep 2; open http://127.0.0.1:8000 ) &

echo
echo "  Manifest is running at:  http://127.0.0.1:8000"
echo "  (your browser should open automatically)"
echo
echo "  >> To STOP Manifest, just close this window. <<"
echo "======================================================"
echo
exec ./venv/bin/python app.py
