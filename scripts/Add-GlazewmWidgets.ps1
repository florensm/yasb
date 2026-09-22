<#
.SYNOPSIS
    Adds the GlazeWM overview widget and the workspaces urgency block to an
    existing YASB config.

.DESCRIPTION
    Edits config.yaml as text rather than round-tripping it through a YAML
    parser, which would discard every comment in the file. Each edit is
    anchored on a line that is already there and is skipped when its key is
    already present, so running this twice is a no-op.

    Writes a timestamped backup next to the config before touching anything.

.PARAMETER ConfigDir
    YASB config directory. Defaults to $env:USERPROFILE\.config\yasb.

.PARAMETER OverviewKeys
    Hotkey that toggles the overview. Defaults to alt+w.

.PARAMETER GridKeys
    Hotkey that toggles the all-workspaces grid. Defaults to alt+q.

.PARAMETER SkipStyles
    Leave styles.css alone. Without this, the urgent/blink rules are appended
    if they are not already defined.

.EXAMPLE
    .\scripts\Add-GlazewmWidgets.ps1
    .\scripts\Add-GlazewmWidgets.ps1 -OverviewKeys "alt+o" -SkipStyles
#>
[CmdletBinding()]
param(
    [string]$ConfigDir = (Join-Path $env:USERPROFILE ".config\yasb"),
    [string]$OverviewKeys = "alt+w",
    [string]$GridKeys = "alt+q",
    [switch]$SkipStyles
)

$ErrorActionPreference = "Stop"

# Windows PowerShell 5.1 writes a BOM for -Encoding utf8, and a BOM in a
# config file trips up tooling that reads it as plain text. Write through
# .NET with an explicit BOM-less encoder instead.
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Write-TextFile([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

$configPath = Join-Path $ConfigDir "config.yaml"
$stylesPath = Join-Path $ConfigDir "styles.css"

if (-not (Test-Path $configPath)) {
    throw "No config.yaml at $configPath. Pass -ConfigDir if yours lives elsewhere."
}

$stamp  = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = "$configPath.$stamp.bak"
Copy-Item $configPath $backup
Write-Host "backup      $backup"

$text    = Get-Content $configPath -Raw
$changed = $false

# --- 1. the overview widget definition -------------------------------------
# Anchored on the `glazewm_workspaces:` key so the new widget lands beside the
# other GlazeWM ones rather than at the end of an alphabetised list.
if ($text -match '(?m)^\s{2}glazewm_overview:') {
    Write-Host "skip        glazewm_overview widget already defined"
}
elseif ($text -match '(?m)^(\s{2})glazewm_workspaces:') {
    $indent = $Matches[1]
    $widget = @"
${indent}glazewm_overview:
${indent}  type: "glazewm.overview.GlazewmOverviewWidget"
${indent}  options:
${indent}    label: ""
${indent}    monitor_exclusive: true
${indent}    grid_columns: 5
${indent}    close_delay: 0
${indent}    popup:
${indent}      blur: true
${indent}      dark_mode: true
${indent}    callbacks:
${indent}      on_left: "toggle_overview"
${indent}    keybindings:
${indent}      - keys: "$OverviewKeys"
${indent}        action: "toggle_overview"
${indent}        screen: active
${indent}      - keys: "$GridKeys"
${indent}        action: "toggle_overview_grid"
${indent}        screen: active

"@
    $text = $text -replace '(?m)^(\s{2}glazewm_workspaces:)', ($widget + '$1')
    $changed = $true
    Write-Host "added       glazewm_overview widget ($OverviewKeys / $GridKeys)"
}
else {
    Write-Warning "No glazewm_workspaces: key found - add the overview widget by hand."
}

# --- 2. urgency block on the workspaces widget ------------------------------
# Appended after `hide_floating`, the last key of the app_icons block, so it
# lands inside `options:` and not inside `app_icons:`.
if ($text -match '(?m)^\s+urgent:') {
    Write-Host "skip        urgent block already present"
}
elseif ($text -match '(?m)^(\s+)hide_floating:.*$') {
    $iconIndent = $Matches[1]                      # inside app_icons
    $optIndent  = $iconIndent.Substring(2)         # one level out, inside options
    $block = @"
$&
${optIndent}urgent:
${optIndent}  enabled: true
${optIndent}  blink: true
${optIndent}  blink_interval: 500
"@
    $text = [regex]::Replace($text, '(?m)^\s+hide_floating:.*$', $block, 1)
    $changed = $true
    Write-Host "added       urgent block on glazewm_workspaces"
}
else {
    Write-Warning "No app_icons.hide_floating key found - add the urgent block by hand."
}

# --- 3. put the widget on the bar -------------------------------------------
# Only the first bar's left list: guessing at every bar in a multi-bar setup
# is more likely to be wrong than useful.
if ($text -match '(?m)^\s+-\s*glazewm_overview\s*$') {
    Write-Host "skip        glazewm_overview already on a bar"
}
elseif ($text -match '(?m)^(\s+)-\s*glazewm_workspaces\s*$') {
    $listIndent = $Matches[1]
    $text = [regex]::Replace(
        $text,
        '(?m)^(\s+-\s*glazewm_workspaces\s*)$',
        "`$1`n${listIndent}- glazewm_overview",
        1)
    $changed = $true
    Write-Host "added       glazewm_overview next to glazewm_workspaces on the bar"
}
else {
    Write-Warning "glazewm_workspaces is not on any bar - add glazewm_overview by hand."
}

if ($changed) {
    Write-TextFile $configPath $text
    Write-Host "wrote       $configPath"
} else {
    Write-Host "no changes  config already has everything"
}

# --- 4. styling for the urgent classes --------------------------------------
# `urgent` stays applied for as long as the window wants attention; `blink` is
# toggled on and off by the widget. Qt stylesheets have no @keyframes, so the
# animation is these two rules rather than a CSS animation. Drop the `.blink`
# rule for a steady highlight instead of a pulsing one.
if (-not $SkipStyles -and (Test-Path $stylesPath)) {
    $css = Get-Content $stylesPath -Raw
    if ($css -match '\.ws-btn\.urgent') {
        Write-Host "skip        urgent CSS already present"
    } else {
        Copy-Item $stylesPath "$stylesPath.$stamp.bak"
        $rules = @"

/* A workspace holding a window that asked for attention. */
.glazewm-workspaces .ws-btn.urgent {
    background-color: #f38ba8;
    color: #11111b;
}

/* Alternating half of the blink. Delete this rule for a steady highlight. */
.glazewm-workspaces .ws-btn.urgent.blink {
    background-color: transparent;
    color: #f38ba8;
}
"@
        Write-TextFile $stylesPath ($css + $rules)
        Write-Host "added       urgent CSS to styles.css"
    }
}

Write-Host ""
Write-Host "Done. Reload YASB to pick it up. $OverviewKeys toggles the overview."
