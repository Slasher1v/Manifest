@echo off
REM Manifest - Windows launcher (double-click me). DRAFT: needs testing on Windows.
title Manifest
cd /d "%~dp0app"

echo ==> Preparing Manifest (first run may take a few minutes)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0app\setup.ps1"
if not %ERRORLEVEL%==0 (
  echo.
  echo Setup is incomplete. Please run "Install Manifest.bat" and watch for errors.
  echo.
  pause
  exit /b 1
)

echo ==> Starting token server...
start "Manifest token server" /min cmd /c "node pot-provider\server\build\main.js > %TEMP%\manifest-pot.log 2>&1"
timeout /t 2 >nul

REM open the app in the default browser
start "" http://127.0.0.1:8000

echo.
echo   Manifest is running at:  http://127.0.0.1:8000
echo   (your browser should open automatically)
echo.
echo   ^>^> To STOP Manifest, close this window. ^<^<
echo ======================================================
echo.
venv\Scripts\python.exe app.py
