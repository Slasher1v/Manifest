# Manifest - Windows environment setup (idempotent).
#
# DRAFT: authored on macOS, mirrors MAC/app/setup.sh. NEEDS TESTING on a real
# Windows 10/11 machine. Provisions a self-contained Python via uv so it doesn't
# depend on whatever Python the user may or may not have.

$ProgressPreference = "SilentlyContinue"
Set-Location -Path $PSScriptRoot   # WINDOWS\app

function Refresh-Path {
  $machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
  $user    = [System.Environment]::GetEnvironmentVariable("Path", "User")
  $env:Path = "$machine;$user"
}

function Manifest-Ready {
  if (-not (Test-Path "venv\Scripts\python.exe")) { return $false }
  & "venv\Scripts\python.exe" -c "import flask, yt_dlp, pyexpat" 2>$null
  if ($LASTEXITCODE -ne 0) { return $false }
  if (-not (Test-Path "pot-provider\server\build\main.js")) { return $false }
  return $true
}

function Ensure-Tools {
  Write-Host "==> Ensuring tools (uv, deno, node, ffmpeg, git) via winget..."
  $pkgs = @("astral-sh.uv", "DenoLand.Deno", "OpenJS.NodeJS.LTS", "Gyan.FFmpeg", "Git.Git")
  foreach ($p in $pkgs) {
    winget install --id $p -e --accept-source-agreements --accept-package-agreements --silent 2>$null | Out-Null
  }
  Refresh-Path
}

function Ensure-Venv {
  if ((Test-Path "venv\Scripts\python.exe")) {
    & "venv\Scripts\python.exe" -c "import pyexpat" 2>$null
    if ($LASTEXITCODE -ne 0) {
      Write-Host "==> Existing Python environment is broken; rebuilding..."
      Remove-Item -Recurse -Force venv
    }
  }
  if (-not (Test-Path "venv\Scripts\python.exe")) {
    Write-Host "==> Creating a self-contained Python environment (via uv)..."
    if (Test-Path venv) { Remove-Item -Recurse -Force venv }
    uv venv venv --python 3.13 --python-preference only-managed --seed
    if ($LASTEXITCODE -ne 0) { throw "uv venv failed" }
  }
  & "venv\Scripts\python.exe" -c "import flask, yt_dlp" 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "==> Installing Python libraries (flask, yt-dlp, ...)..."
    uv pip install --python "venv\Scripts\python.exe" -r requirements.txt
    if ($LASTEXITCODE -ne 0) { throw "pip install failed" }
  }
}

function Ensure-Pot {
  if (-not (Test-Path "pot-provider\server\package.json")) {
    Write-Host "==> Fetching the YouTube token helper (bgutil)..."
    if (Test-Path pot-provider) { Remove-Item -Recurse -Force pot-provider }
    git clone --depth 1 --branch 1.3.1 https://github.com/Brainicism/bgutil-ytdlp-pot-provider.git pot-provider
  }
  if (-not (Test-Path "pot-provider\server\build\main.js")) {
    Write-Host "==> Building the YouTube token helper..."
    Push-Location "pot-provider\server"
    if (Test-Path tsconfig.tsbuildinfo) { Remove-Item tsconfig.tsbuildinfo }
    npm install 2>$null | Out-Null
    npx tsc
    Pop-Location
  }
}

# --- main -------------------------------------------------------------------
if (Manifest-Ready) { Write-Host "OK: Manifest environment already set up."; exit 0 }

try {
  Ensure-Tools
  Ensure-Venv
  Ensure-Pot
} catch {
  Write-Host "ERROR: $_"
  exit 1
}

if (Manifest-Ready) {
  Write-Host "OK: Manifest environment ready."
  exit 0
} else {
  Write-Host "ERROR: setup finished but environment is still incomplete."
  exit 1
}
