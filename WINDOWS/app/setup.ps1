# Shared, idempotent environment setup for Manifest on Windows.
# Dot-sourced by install.ps1 and launch.ps1. Safe to run repeatedly.
#
# Python is provisioned with `uv`, which downloads a self-contained CPython
# under %USERPROFILE%\.local - no admin, no system-Python conflicts.
# ffmpeg / Node.js / Deno are installed via winget at USER scope.

$ErrorActionPreference = 'Stop'

$ManifestAppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ManifestAppDir

# ------------------------------------------------------------------ helpers

function Refresh-Path {
    $machine = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $extra   = @(
        "$env:USERPROFILE\.local\bin",
        "$env:USERPROFILE\.deno\bin",
        "$env:LOCALAPPDATA\Programs\deno"
    ) -join ';'
    $env:Path = "$extra;$machine;$user"
}

function Have-Command([string]$Name) {
    [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-VenvPython {
    Join-Path $ManifestAppDir 'venv\Scripts\python.exe'
}

function Test-VenvPackages {
    # Filesystem check instead of `python -c "import ..."` because PS 5.1 wraps
    # any native-command stderr (e.g. Python's import traceback) as a
    # NativeCommandError that can bubble up as a terminating exception even
    # under ErrorActionPreference='Continue'.
    $sp = Join-Path $ManifestAppDir 'venv\Lib\site-packages'
    if (-not (Test-Path (Join-Path $sp 'flask\__init__.py'))) { return $false }
    if (-not (Test-Path (Join-Path $sp 'yt_dlp\__init__.py'))) { return $false }
    return $true
}

# True if the venv is complete and the token helper is built.
function Test-ManifestReady {
    if (-not (Test-Path (Get-VenvPython))) { return $false }
    if (-not (Test-VenvPackages))           { return $false }
    if (-not (Test-Path (Join-Path $ManifestAppDir 'pot-provider\server\build\main.js'))) { return $false }
    return $true
}

# ------------------------------------------------------------------ steps

function Test-Winget {
    if (Have-Command 'winget') { return $true }
    Write-Host ""
    Write-Host "ERROR: 'winget' (Windows Package Manager) is not available."
    Write-Host "Install 'App Installer' from the Microsoft Store, then run this again."
    Write-Host "  https://apps.microsoft.com/detail/9NBLGGH4NNS1"
    return $false
}

function Install-WingetPackage([string]$Id, [string]$Probe) {
    Refresh-Path
    if (Have-Command $Probe) { return $true }
    Write-Host "==> Installing $Id (user scope)..."
    # --scope user keeps it admin-free; --silent avoids GUI prompts; -e exact id match.
    winget install -e --id $Id --scope user --silent --accept-source-agreements --accept-package-agreements | Out-Host
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
        # -1978335189 = already installed; treat as success.
        Write-Host "    winget returned $LASTEXITCODE; retrying without --scope user..."
        winget install -e --id $Id --silent --accept-source-agreements --accept-package-agreements | Out-Host
    }
    Refresh-Path
    return (Have-Command $Probe)
}

function Find-Python313 {
    # Direct filesystem probe of python.org install locations (don't trust
    # `python` on PATH - it might be the Microsoft Store alias stub which
    # is just a shim that launches the Store, not a real interpreter).
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe",
        "$env:PROGRAMFILES\Python\Python313\python.exe",
        "${env:PROGRAMFILES(x86)}\Python\Python313\python.exe"
    )
    foreach ($p in $candidates) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    # Fall back to the Python launcher, which python.org installs by default.
    if (Get-Command 'py' -ErrorAction SilentlyContinue) {
        try {
            $exe = & py -3.13 -c "import sys; print(sys.executable)" 2>$null
            if ($exe -and (Test-Path $exe)) { return $exe }
        } catch { }
    }
    return $null
}

function Install-Tools {
    Write-Host "==> Ensuring tools (Python, Node.js, Deno, ffmpeg)..."
    $ok = $true
    # Python 3.13 first. We install it via winget rather than letting uv
    # download a managed copy, because uv 0.11.x has a Windows-specific
    # registry-desync bug ("Missing expected target directory for Python
    # minor version link") that bricks future `uv venv` calls. A real
    # system Python from python.org sidesteps it entirely. We probe with
    # Find-Python313 (not just `python` on PATH) because Windows ships a
    # Store-alias stub at WindowsApps\python.exe that hijacks the name.
    if (-not (Find-Python313)) {
        if (-not (Install-WingetPackage 'Python.Python.3.13' '__force__')) { $ok = $false }
        Refresh-Path
    }
    if (-not (Install-WingetPackage 'OpenJS.NodeJS.LTS' 'node'))   { $ok = $false }
    if (-not (Install-WingetPackage 'DenoLand.Deno'     'deno'))   { $ok = $false }
    if (-not (Install-WingetPackage 'Gyan.FFmpeg'       'ffmpeg')) { $ok = $false }
    if (-not (Find-Python313)) {
        Write-Host "ERROR: Python 3.13 was not found after install. winget output above should have a clue."
        $ok = $false
    }
    return $ok
}

function Install-Uv {
    Refresh-Path
    if (Have-Command 'uv') { return $true }
    Write-Host "==> Installing uv (Python manager)..."
    # Official installer; user-scope, no admin.
    powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr https://astral.sh/uv/install.ps1 -UseBasicParsing | iex" | Out-Host
    Refresh-Path
    return (Have-Command 'uv')
}

function Install-Venv {
    $py = Get-VenvPython

    # Rebuild a venv missing the python.exe binary (rare; usually means an
    # interrupted previous install).
    if ((Test-Path (Join-Path $ManifestAppDir 'venv')) -and -not (Test-Path $py)) {
        Write-Host "==> Existing Python environment is incomplete; rebuilding it..."
        Remove-Item -Recurse -Force (Join-Path $ManifestAppDir 'venv')
    }

    if (-not (Test-Path $py)) {
        # Workaround for a uv-on-Windows quirk: an interrupted or partial managed-
        # Python install leaves the patch-version dir but desyncs uv's registry,
        # and every later `uv venv` fails with "Missing expected target directory
        # for Python minor version link". Cleaning stale entries lets uv recover.
        $uvPy = Join-Path $env:APPDATA 'uv\python'
        if (Test-Path $uvPy) {
            Get-ChildItem $uvPy -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                if (-not (Test-Path (Join-Path $_.FullName 'python.exe'))) {
                    Remove-Item -Recurse -Force $_.FullName -ErrorAction SilentlyContinue
                }
            }
        }

        Write-Host "==> Creating a self-contained Python environment (via uv)..."
        if (Test-Path (Join-Path $ManifestAppDir 'venv')) {
            Remove-Item -Recurse -Force (Join-Path $ManifestAppDir 'venv')
        }
        # Resolve the python.org Python's absolute path and pass it to uv directly.
        # This sidesteps two failure modes on Windows: (a) uv's managed-Python
        # download has a registry-desync bug in 0.11.x, and (b) uv's PEP 514
        # registry probe sometimes misses freshly-installed Python in a child
        # shell. An absolute path is unambiguous.
        $sysPy = Find-Python313
        if (-not $sysPy) {
            Write-Host "ERROR: Could not locate Python 3.13 on disk after install."
            return $false
        }
        uv venv venv --python $sysPy --seed | Out-Host
        if ($LASTEXITCODE -ne 0) { return $false }
    }

    if (-not (Test-VenvPackages)) {
        Write-Host "==> Installing Python libraries (flask, yt-dlp, ...)..."
        uv pip install --python $py -r (Join-Path $ManifestAppDir 'requirements.txt') | Out-Host
        if ($LASTEXITCODE -ne 0) { return $false }
    }
    return $true
}

# Fetch the bgutil PO-token helper source. GPL, kept out of this repo on purpose.
# Pinned to 1.3.1 to match requirements.txt's bgutil-ytdlp-pot-provider pin.
function Install-PotSource {
    $potDir = Join-Path $ManifestAppDir 'pot-provider'
    if (Test-Path (Join-Path $potDir 'server\package.json')) { return $true }
    Write-Host "==> Fetching the YouTube token helper (bgutil)..."
    if (Test-Path $potDir) { Remove-Item -Recurse -Force $potDir }

    $zip = Join-Path $env:TEMP 'manifest-bgutil-1.3.1.zip'
    $extract = Join-Path $env:TEMP 'manifest-bgutil-extract'
    if (Test-Path $extract) { Remove-Item -Recurse -Force $extract }

    Invoke-WebRequest -UseBasicParsing `
        -Uri 'https://github.com/Brainicism/bgutil-ytdlp-pot-provider/archive/refs/tags/1.3.1.zip' `
        -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    Move-Item (Join-Path $extract 'bgutil-ytdlp-pot-provider-1.3.1') $potDir
    Remove-Item -Recurse -Force $extract
    Remove-Item $zip
    return (Test-Path (Join-Path $potDir 'server\package.json'))
}

function Build-Pot {
    $built = Join-Path $ManifestAppDir 'pot-provider\server\build\main.js'
    if (Test-Path $built) { return $true }
    Write-Host "==> Building the YouTube token helper..."
    Push-Location (Join-Path $ManifestAppDir 'pot-provider\server')
    try {
        Remove-Item -ErrorAction SilentlyContinue 'tsconfig.tsbuildinfo'
        npm install --no-audit --no-fund --loglevel=error | Out-Host
        if ($LASTEXITCODE -ne 0) { return $false }
        npx --yes tsc | Out-Host
        if ($LASTEXITCODE -ne 0) { return $false }
    } finally {
        Pop-Location
    }
    return (Test-Path $built)
}

# Full setup. Returns $true only if everything is genuinely ready.
function Install-Manifest {
    if (-not (Test-Winget))        { return $false }
    if (-not (Install-Tools))      { return $false }
    if (-not (Install-Uv))         { return $false }
    if (-not (Install-Venv))       { return $false }
    if (-not (Install-PotSource))  { return $false }
    if (-not (Build-Pot))          { return $false }
    if (-not (Test-ManifestReady)) {
        Write-Host "ERROR: setup finished but the environment is still incomplete."
        return $false
    }
    return $true
}

Refresh-Path
