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

# Chrome 127+ uses AppBound cookie encryption on Windows, so yt-dlp can't read
# Chrome cookies (yt-dlp #10927 / #15401). Firefox stores cookies in plain SQLite
# and works fine. If the user hasn't pinned MANIFEST_BROWSER, and Firefox is
# installed with a profile, prefer it over Chrome.
if (-not $env:MANIFEST_BROWSER -and -not $env:MANIFEST_COOKIES_FILE) {
    $ffProfiles = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles'
    if (Test-Path $ffProfiles) {
        $hasCookies = Get-ChildItem -Path $ffProfiles -Filter 'cookies.sqlite' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hasCookies) {
            $env:MANIFEST_BROWSER = 'firefox'
            Write-Host "==> Firefox detected - using its cookies (Chrome 127+ encrypts cookies on Windows)."
        }
    }
    if (-not $env:MANIFEST_BROWSER) {
        Write-Host "==> Note: Chrome cookies on Windows are blocked by AppBound encryption."
        Write-Host "    For YouTube, install Firefox + sign in, OR set MANIFEST_COOKIES_FILE"
        Write-Host "    to a cookies.txt exported from a browser extension."
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
