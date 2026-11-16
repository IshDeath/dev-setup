<#
.SYNOPSIS
  Install Sysinternals Sysmon with windows\sysmon\sysmonconfig.xml, or update the config
  on an existing install.

.DESCRIPTION
  Needs admin. Run from a normal shell and it relaunches itself elevated (UAC prompt).
  - Not installed: winget installs Microsoft.Sysinternals.Sysmon, then `Sysmon64 -accepteula -i <config>`.
  - Already installed: `Sysmon64 -c <config>` (applies the config in place, no reinstall).
  Also sets the Sysmon/Operational event log to -LogSizeMB (default 64 MB).

    powershell -ExecutionPolicy Bypass -File .\scripts\install-sysmon.ps1
#>
param(
    [string]$Config = (Join-Path (Split-Path $PSScriptRoot -Parent) 'windows\sysmon\sysmonconfig.xml'),
    [int]$LogSizeMB = 64
)

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'Sysmon needs admin. Relaunching elevated...'
    $p = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"",
        '-Config', "`"$Config`"", '-LogSizeMB', $LogSizeMB)
    if ($p.ExitCode -ne 0) { throw "Elevated Sysmon install exited with code $($p.ExitCode)" }
    return
}

if (-not (Test-Path $Config)) { throw "Config not found: $Config" }
$null = [xml](Get-Content $Config -Raw)   # fail early on malformed XML

$svc = Get-Service Sysmon64 -ErrorAction SilentlyContinue
if ($svc) {
    $exe = (Get-CimInstance Win32_Service -Filter "Name='Sysmon64'").PathName.Trim('"')
    Write-Host "Sysmon already installed ($exe). Updating config..."
    & $exe -c $Config
} else {
    winget install --id Microsoft.Sysinternals.Sysmon -e --accept-package-agreements --accept-source-agreements --disable-interactivity
    $exe = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages", "$env:ProgramFiles\WinGet\Packages" `
               -Recurse -Filter Sysmon64.exe -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (-not $exe) { throw 'Sysmon64.exe not found after winget install.' }
    Write-Host "Installing Sysmon from $exe ..."
    & $exe -accepteula -i $Config
}
if ($LASTEXITCODE -ne 0) { throw "Sysmon exited with code $LASTEXITCODE" }

wevtutil sl 'Microsoft-Windows-Sysmon/Operational' /ms:$($LogSizeMB * 1MB)
Write-Host "Sysmon running with $(Split-Path $Config -Leaf); Operational log max size $LogSizeMB MB."
Get-Service Sysmon64, SysmonDrv | Format-Table Name, Status, StartType -AutoSize
