@echo off
REM Manifest - launcher (double-click me to start the app).
REM Keep this window open while you use Manifest. To stop: close the window.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0.engine\launch.ps1"
