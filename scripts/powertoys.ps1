<#
.SYNOPSIS
  Save or restore PowerToys settings (general + every module's settings.json).

.DESCRIPTION
  -Export copies this machine's settings into windows\powertoys\ in the repo.
  -Import copies them back onto a machine. It stops PowerToys first, because PowerToys
  rewrites its settings files when it exits, and then starts it again.

  Runtime/state files are skipped: FancyZones applied-layouts.json (tied to this machine's
  monitor IDs), color history, PowerRename last-run data, update/telemetry/OOBE state.
  The NewPlus template folder path is stored as {{LOCALAPPDATA}} and filled in on import.

    powershell -ExecutionPolicy Bypass -File .\scripts\powertoys.ps1 -Export
    powershell -ExecutionPolicy Bypass -File .\scripts\powertoys.ps1 -Import
#>
param(
    [switch]$Export,
    [switch]$Import,
    [string]$Target = (Join-Path $env:LOCALAPPDATA 'Microsoft\PowerToys')
)

$ErrorActionPreference = 'Stop'
if ($Export -eq $Import) { throw 'Pass exactly one of -Export or -Import.' }

$Repo = Join-Path (Split-Path $PSScriptRoot -Parent) 'windows\powertoys'
$enc = New-Object Text.UTF8Encoding $false
$Skip = 'applied-layouts.json', 'colorHistory.json', 'power-rename-last-run-data.json',
        'last_version_run.json', 'oobe_settings.json', 'settings-placement.json',
        'settings-telemetry.json', 'UpdateState.json', 'log_settings.json'

# JSON-escaped form of %LOCALAPPDATA% (backslashes doubled), as it appears inside the files.
$LocalAppDataJson = $env:LOCALAPPDATA.Replace('\', '\\')

if ($Export) {
    if (-not (Test-Path $Target)) { throw "PowerToys settings not found at $Target" }
    if (Test-Path $Repo) { Remove-Item $Repo -Recurse -Force }
    Get-ChildItem $Target -Recurse -File -Filter *.json |
        Where-Object { $_.FullName -notmatch '\\(Logs|Updates)\\' -and $Skip -notcontains $_.Name } |
        ForEach-Object {
            $rel = $_.FullName.Substring($Target.Length + 1)
            $dest = Join-Path $Repo $rel
            New-Item -ItemType Directory -Force (Split-Path $dest -Parent) | Out-Null
            $t = [IO.File]::ReadAllText($_.FullName).Replace($LocalAppDataJson, '{{LOCALAPPDATA}}')
            [IO.File]::WriteAllText($dest, $t, $enc)
            Write-Host "  $rel"
        }
    Write-Host "Exported to $Repo. Review with git diff, then commit."
    return
}

# --- Import -------------------------------------------------------------------
if (-not (Test-Path $Repo)) { throw "Nothing to import: $Repo not found" }

# Only stop/restart PowerToys when writing to its real settings folder.
$live = $Target -eq (Join-Path $env:LOCALAPPDATA 'Microsoft\PowerToys')
$procs = if ($live) { Get-Process -Name 'PowerToys*' -ErrorAction SilentlyContinue }
$exe = ($procs | Where-Object Name -eq 'PowerToys' | Select-Object -First 1).Path
if ($procs) {
    Write-Host '  stopping PowerToys'
    $procs | Stop-Process -Force
    Start-Sleep -Seconds 2
}

$backup = Join-Path $Target ("backup-dev-setup-" + (Get-Date -Format 'yyyyMMddHHmmss'))
Get-ChildItem $Repo -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($Repo.Length + 1)
    $dest = Join-Path $Target $rel
    New-Item -ItemType Directory -Force (Split-Path $dest -Parent) | Out-Null
    if (Test-Path $dest) {
        $b = Join-Path $backup $rel
        New-Item -ItemType Directory -Force (Split-Path $b -Parent) | Out-Null
        Copy-Item $dest $b
    }
    $t = [IO.File]::ReadAllText($_.FullName).Replace('{{LOCALAPPDATA}}', $LocalAppDataJson)
    [IO.File]::WriteAllText($dest, $t, $enc)
    Write-Host "  $rel"
}
if (Test-Path $backup) { Write-Host "  previous files backed up to $backup" }

if (-not $live) { return }
if (-not $exe) {
    $exe = @("$env:LOCALAPPDATA\PowerToys\PowerToys.exe", "$env:ProgramFiles\PowerToys\PowerToys.exe") |
        Where-Object { Test-Path $_ } | Select-Object -First 1
}
if ($exe) { Start-Process $exe; Write-Host "  started PowerToys" }
else { Write-Host '  PowerToys not found to restart. Launch it once and the settings apply.' }
