#!/bin/bash
#
# Manifest — launcher (double-click me to start the app).
# Keep this window open while you use Manifest. To stop: close the window.
#
clear
echo "======================================================"
echo "            Starting  M A N I F E S T"
echo "======================================================"

cd "$(dirname "$0")/app" || { echo "Could not find the app folder."; read -r -p "Press Return to close." _; exit 1; }

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
