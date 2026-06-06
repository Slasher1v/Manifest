@echo off
REM Manifest - Windows installer (double-click me). DRAFT: needs testing on Windows.
title Installing Manifest
echo ======================================================
echo             Installing  M A N I F E S T  (Windows)
echo ======================================================
echo.
echo This installs everything Manifest needs. It needs internet
echo and a few minutes. If Windows SmartScreen warns you, click
echo "More info" then "Run anyway".
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0app\setup.ps1"
echo.
if %ERRORLEVEL%==0 (
  echo ======================================================
  echo   Done! Manifest is installed.
  echo   To use it: double-click  Manifest.bat
  echo ======================================================
) else (
  echo ======================================================
  echo   Setup did not finish. Scroll up for the error,
  echo   check your internet, then run this installer again.
  echo ======================================================
)
echo.
pause
