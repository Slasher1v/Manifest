# Manifest - launcher (called by "Manifest.bat").
# Keep this window open while you use Manifest. To stop: close the window.

# Use Continue (not Stop) - see install.ps1 for the rationale.
$ErrorActionPreference = 'Continue'

Clear-Host
Write-Host "======================================================"
Write-Host "            Starting  M A N I F E S T"
Write-Host "======================================================"

. (Join-Path $PSScriptRoot 'setup.ps1')

# Keep Manifest up to date: pull the latest code from main and apply it in place.
Update-ManifestCode

# Pick a browser for yt-dlp to borrow cookies from. Order matters:
#   1. Firefox  - plain SQLite, ALWAYS works on Windows.
#   2. Brave / Edge / Chrome - all Chromium-based, all inherit Chrome 127+'s
#      AppBound cookie encryption (yt-dlp #10927 / #15401). They *may* work
#      depending on the user's specific Chromium version + rollout state, so
#      we try them in user-popularity order if Firefox isn't installed.
# The user can override with `$env:MANIFEST_BROWSER = '...'` or set
# `$env:MANIFEST_COOKIES_FILE = 'C:\path\to\cookies.txt'` (exported via the
# "Get cookies.txt LOCALLY" browser extension, no Firefox required).
if (-not $env:MANIFEST_BROWSER -and -not $env:MANIFEST_COOKIES_FILE) {
    $candidates = @(
        @{ Name = 'firefox';
           Probe = (Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles') }
        @{ Name = 'brave';
           Probe = (Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\User Data\Default\Cookies') }
        @{ Name = 'edge';
           Probe = (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Default\Network\Cookies') }
        @{ Name = 'chrome';
           Probe = (Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Default\Network\Cookies') }
    )
    foreach ($c in $candidates) {
        if (Test-Path $c.Probe) {
            $env:MANIFEST_BROWSER = $c.Name
            if ($c.Name -eq 'firefox') {
                Write-Host "==> Firefox detected - using its cookies (works reliably on Windows)."
            } else {
                Write-Host "==> $($c.Name) detected - using its cookies."
                Write-Host "    Heads-up: Chromium browsers on Windows often hit AppBound encryption."
                Write-Host "    If YouTube fails, install Firefox + sign in there, or export your"
                Write-Host "    cookies to a file and set MANIFEST_COOKIES_FILE - the in-app error"
                Write-Host "    message will spell out both options."
            }
            break
        }
    }
    if (-not $env:MANIFEST_BROWSER) {
        Write-Host "==> No supported browser profile found. For YouTube, install Firefox + sign"
        Write-Host "    in, or set MANIFEST_COOKIES_FILE to a cookies.txt you exported."
    }
}

# Self-heal: if anything is missing or a previous install half-finished, fix it.
if (-not (Test-ManifestReady)) {
    Write-Host "==> First-time setup / repair needed. This may take a few minutes..."
    if (-not (Install-Manifest)) {
        Write-Host ""
        Write-Host "Setup couldn't complete. Please double-click 'Install Manifest.bat'"
        Write-Host "and watch for any errors."
        Read-Host "Press Enter to close"
        exit 1
    }
}

$py = Join-Path $PSScriptRoot 'venv\Scripts\python.exe'

# Keep yt-dlp fresh (sites change often); quiet + never fatal.
Write-Host "==> Checking for updates..."
try { & uv pip install --python $py -U "yt-dlp[default]" *> $null } catch { }

# Start the YouTube token server if it isn't already running.
$potRunning = $false
try {
    Invoke-WebRequest -Uri 'http://127.0.0.1:4416/ping' -TimeoutSec 2 -UseBasicParsing *> $null
    $potRunning = $true
} catch { }

$potProc = $null
if (-not $potRunning) {
    Write-Host "==> Starting token server..."
    $log = Join-Path $env:TEMP 'manifest-pot.log'
    $potDir = Join-Path $PSScriptRoot 'pot-provider\server'
    # Run node from the server dir so require() resolves node_modules siblings.
    $potProc = Start-Process -PassThru -WindowStyle Hidden -FilePath 'node' `
        -ArgumentList 'build\main.js' -WorkingDirectory $potDir `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    Start-Sleep -Seconds 2
}

# Open the app in the browser shortly after the server boots.
Start-Job -ScriptBlock { Start-Sleep -Seconds 2; Start-Process 'http://127.0.0.1:8000' } | Out-Null

Write-Host ""
Write-Host "  Manifest is running at:  http://127.0.0.1:8000"
Write-Host "  (your browser should open automatically)"
Write-Host ""
Write-Host "  >> To STOP Manifest, just close this window. <<"
Write-Host "======================================================"
Write-Host ""

try {
    Set-Location $PSScriptRoot
    # Force UTF-8 for Python stdio so the app's Unicode startup banner doesn't
    # crash on Windows cp1252 when this script runs without an interactive console.
    $env:PYTHONIOENCODING = 'utf-8'
    & $py app.py
} finally {
    if ($potProc -and -not $potProc.HasExited) {
        try { Stop-Process -Id $potProc.Id -Force -ErrorAction SilentlyContinue } catch { }
    }
}
