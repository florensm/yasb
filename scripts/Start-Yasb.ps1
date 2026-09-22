<#
.SYNOPSIS
    Runs this YASB checkout from source, replacing any YASB already running.

.DESCRIPTION
    The installed C:\Program Files\YASB\yasb.exe is a frozen build and does
    not contain anything in this working tree, so testing a branch means
    running from source. This stops whichever YASB is up -- the installed
    binary or a previous source run -- and starts this checkout instead.

    Launched with pythonw.exe rather than python.exe so no console window
    is left behind, and detached so it outlives the shell that started it.

.PARAMETER Install
    Create the virtualenv and install dependencies first. Implied when
    .venv does not exist yet. Pass it explicitly after pulling changes that
    touch pyproject.toml.

.PARAMETER Stop
    Stop any running YASB and exit without starting anything.

.PARAMETER Console
    Use python.exe and keep a console window, so tracebacks and log output
    are visible. Useful when the bar dies on startup.

.EXAMPLE
    .\scripts\Start-Yasb.ps1
    .\scripts\Start-Yasb.ps1 -Install
    .\scripts\Start-Yasb.ps1 -Console
    .\scripts\Start-Yasb.ps1 -Stop
#>
[CmdletBinding()]
param(
    [switch]$Install,
    [switch]$Stop,
    [switch]$Console
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$venvDir  = Join-Path $repoRoot ".venv"
$entry    = Join-Path $repoRoot "src\main.py"

if (-not (Test-Path $entry)) {
    throw "No src\main.py under $repoRoot - run this from the scripts folder of a YASB checkout."
}

# --- stop whatever is running --------------------------------------------
# Two shapes to catch: the installed frozen binary, and a previous source
# run, which shows up as python/pythonw with main.py on its command line.
$stopped = 0
Get-Process -Name "yasb", "yasb_cloud" -ErrorAction SilentlyContinue | ForEach-Object {
    $_ | Stop-Process -Force
    $stopped++
}
Get-CimInstance Win32_Process -Filter "name='python.exe' OR name='pythonw.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine -match [regex]::Escape($entry) } |
    ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        $stopped++
    }

if ($stopped -gt 0) {
    Write-Host "stopped     $stopped running YASB process(es)"
    # Give the bar a moment to release its named pipe and app-bar slot,
    # otherwise the new instance can fail to reserve screen space.
    Start-Sleep -Milliseconds 800
} else {
    Write-Host "stopped     nothing was running"
}

if ($Stop) { return }

# --- dependencies ----------------------------------------------------------
$py = Join-Path $venvDir "Scripts\python.exe"

if ($Install -or -not (Test-Path $py)) {
    if (-not (Test-Path $py)) {
        Write-Host "creating    virtualenv at .venv"
        $systemPy = (Get-Command python -ErrorAction SilentlyContinue).Source
        if (-not $systemPy) {
            throw "No python on PATH. YASB needs Python 3.14+ (scoop install python)."
        }
        & $systemPy -m venv $venvDir
    }
    Write-Host "installing  dependencies (this takes a few minutes the first time)"
    & $py -m pip install --quiet --upgrade pip
    & $py -m pip install --quiet $repoRoot
    if ($LASTEXITCODE -ne 0) { throw "pip install failed." }
}

# --- launch ----------------------------------------------------------------
$exe = if ($Console) { $py } else { Join-Path $venvDir "Scripts\pythonw.exe" }

$branch = (& git -C $repoRoot rev-parse --abbrev-ref HEAD 2>$null)
$commit = (& git -C $repoRoot rev-parse --short HEAD 2>$null)

$proc = Start-Process -FilePath $exe -ArgumentList $entry `
    -WorkingDirectory $repoRoot -PassThru `
    -WindowStyle $(if ($Console) { "Normal" } else { "Hidden" })

Start-Sleep -Milliseconds 2500
if ($proc.HasExited) {
    throw "YASB exited immediately (code $($proc.ExitCode)). Re-run with -Console to see why."
}

Write-Host "started     pid $($proc.Id) from $branch @ $commit"
Write-Host ""
Write-Host "Logs: $env:USERPROFILE\.config\yasb\yasb.log"
Write-Host "Stop with: .\scripts\Start-Yasb.ps1 -Stop"
