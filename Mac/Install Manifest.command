#!/bin/bash
#
# Manifest — one-time installer (double-click me).
#
clear
echo "======================================================"
echo "            Installing  M A N I F E S T"
echo "======================================================"
echo
echo "This sets up the video downloader on your Mac."
echo "It needs internet and a few minutes. You may be asked"
echo "for your Mac password once (for Homebrew) — type it"
echo "and press Return (the characters stay hidden)."
echo

cd "$(dirname "$0")/.engine" || { echo "Could not find the app files."; read -r -p "Press Return to close." _; exit 1; }

# shellcheck disable=SC1091
source ./setup.sh

if manifest_setup; then
  echo
  echo "======================================================"
  echo "  ✅  Done!  Manifest is installed and verified."
  echo
  echo "  To use it: double-click  >>  Manifest.command"
  echo "======================================================"
else
  echo
  echo "======================================================"
  echo "  ❌  Setup did not finish."
  echo
  echo "  Scroll up to read the error. Common fixes:"
  echo "   • Check your internet connection."
  echo "   • If asked for a password, it's your Mac login one."
  echo "   • Then just double-click this installer again."
  echo "======================================================"
fi
echo
read -r -p "Press Return to close this window." _
