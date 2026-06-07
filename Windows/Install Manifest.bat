@echo off
REM Manifest - one-time installer (double-click me).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0.engine\install.ps1"
REM Hide the engine folder so you only see the click-files.
attrib +h "%~dp0.engine" 2>nul
