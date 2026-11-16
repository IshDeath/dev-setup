# Installs the MesloLGS NF fonts in ../fonts for the current Windows user (no admin needed).
# Run from PowerShell:  powershell -ExecutionPolicy Bypass -File .\scripts\install-fonts.ps1

$ErrorActionPreference = 'Stop'
$fontDir = Join-Path $PSScriptRoot '..\fonts'
$userFonts = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$regPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

New-Item -ItemType Directory -Force $userFonts | Out-Null

Get-ChildItem $fontDir -Filter *.ttf | ForEach-Object {
    $dest = Join-Path $userFonts $_.Name
    Copy-Item $_.FullName $dest -Force
    New-ItemProperty -Path $regPath -Name "$($_.BaseName) (TrueType)" -Value $dest -PropertyType String -Force | Out-Null
    Write-Host "Installed $($_.Name)"
}

Write-Host "`nNow set Windows Terminal > Settings > Defaults (or the Debian profile) > Appearance > Font face = 'MesloLGS NF'. Restart Terminal if it isn't listed yet."
