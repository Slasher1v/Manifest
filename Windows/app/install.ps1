# Manifest - one-time installer (called by "Install Manifest.bat").

# Use Continue (not Stop) because setup.ps1's functions probe native commands
# whose stderr would otherwise be wrapped as ErrorRecord and terminate the
# script (PS 5.1 quirk). The functions return $true/$false explicitly, and
# the try/catch around Install-Manifest still surfaces real exceptions.
$ErrorActionPreference = 'Continue'

Clear-Host
Write-Host "======================================================"
Write-Host "            Installing  M A N I F E S T"
Write-Host "======================================================"
Write-Host ""
Write-Host "This sets up the video downloader on your PC."
Write-Host "It needs internet and a few minutes. Everything installs"
Write-Host "to your user folder - no admin / UAC required."
Write-Host ""

. (Join-Path $PSScriptRoot 'setup.ps1')

$ok = $false
try { $ok = Install-Manifest } catch { Write-Host "ERROR: $($_.Exception.Message)" }

Write-Host ""
if ($ok) {
    Write-Host "======================================================"
    Write-Host "  Done!  Manifest is installed and verified."
    Write-Host ""
    Write-Host "  To use it: double-click  >>  Manifest.bat"
    Write-Host "======================================================"
} else {
    Write-Host "======================================================"
    Write-Host "  Setup did not finish."
    Write-Host ""
    Write-Host "  Scroll up to read the error. Common fixes:"
    Write-Host "   - Check your internet connection."
    Write-Host "   - Install 'App Installer' from the Microsoft Store"
    Write-Host "     if winget is missing, then run this installer again."
    Write-Host "======================================================"
}
Write-Host ""
Read-Host "Press Enter to close this window"
