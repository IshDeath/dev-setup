<#
.SYNOPSIS
  Rebuild my Windows developer environment on a new machine.

.DESCRIPTION
  Installs apps with winget, installs the MesloLGS NF fonts, VS Code extensions and settings,
  Windows Terminal settings, global Python packages, and git defaults.
  Safe to re-run: winget skips installed apps, and existing config files are backed up before
  they're replaced.

  Run from a normal (non-admin) PowerShell. Some installers will raise a UAC prompt.

    powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1
    powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1 -Work

.PARAMETER Work
  Also install work-only tools (Java 8 JRE, XAMPP, Exchange Online / Microsoft Graph modules).

.PARAMETER SkipApps
  Skip the winget installs (only apply config).

.PARAMETER SkipConfig
  Skip copying VS Code / Windows Terminal config.

.PARAMETER SkipClaudeConfig
  Skip cloning the private claude-config + maddenco-docs repos and installing the Claude Code config.

.PARAMETER SkipSysmon
  Skip installing Sysmon (SwiftOnSecurity config). It asks for admin (UAC) when it runs.
#>
param(
    [switch]$Work,
    [switch]$SkipApps,
    [switch]$SkipConfig,
    [switch]$SkipClaudeConfig,
    [switch]$SkipSysmon
)

$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot -Parent
$Stamp = Get-Date -Format 'yyyyMMddHHmmss'

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

function Install-WingetPackage([string]$Id) {
    winget list --id $Id -e --accept-source-agreements --disable-interactivity *> $null
    if ($LASTEXITCODE -eq 0) { Write-Host "  [skip] $Id"; return }
    Write-Host "  [install] $Id"
    winget install --id $Id -e --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { Write-Warning "winget failed for $Id (exit $LASTEXITCODE)" }
}

function Copy-WithBackup([string]$Source, [string]$Dest) {
    New-Item -ItemType Directory -Force (Split-Path $Dest -Parent) | Out-Null
    if (Test-Path $Dest) { Copy-Item $Dest "$Dest.bak.$Stamp" }
    Copy-Item $Source $Dest -Force
    Write-Host "  $Dest"
}

function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

# --- Apps --------------------------------------------------------------------
$Core = @(
    # Shell / terminal
    'Microsoft.WindowsTerminal'
    'Microsoft.PowerShell'
    'Microsoft.WSL'
    # Source control
    'Git.Git'
    'GitHub.cli'
    # Editors / AI
    'Microsoft.VisualStudioCode'
    'Anthropic.ClaudeCode'
    'Anthropic.Claude'
    # Languages / runtimes
    'Python.Python.3.12'
    'OpenJS.NodeJS.LTS'
    'EclipseAdoptium.Temurin.21.JDK'
    'PHP.PHP.8.4'
    # CLI tools
    'BurntSushi.ripgrep.MSVC'
    # Database
    'DBeaver.DBeaver.Community'
    # Remote access / transfer
    'PuTTY.PuTTY'
    'WinSCP.WinSCP'
    'mRemoteNG.mRemoteNG'
    # Network
    'Insecure.Nmap'
    'WiresharkFoundation.Wireshark'
    # Utilities
    'Microsoft.PowerToys'
)

$WorkApps = @(
    'Oracle.JavaRuntimeEnvironment'   # Java 8, for legacy IBM tooling
    'ApacheFriends.Xampp.8.2'
)

if (-not $SkipApps) {
    Step 'winget packages'
    $Core | ForEach-Object { Install-WingetPackage $_ }
    if ($Work) { $WorkApps | ForEach-Object { Install-WingetPackage $_ } }
    Update-SessionPath
}

# --- Fonts -------------------------------------------------------------------
Step 'Fonts (MesloLGS NF)'
& (Join-Path $PSScriptRoot 'install-fonts.ps1')

# --- Git ---------------------------------------------------------------------
Step 'Git defaults'
if (Get-Command git -ErrorAction SilentlyContinue) {
    git config --global core.editor 'code --wait'
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    if (-not (git config --global user.name))  { git config --global user.name  (Read-Host '  git user.name') }
    if (-not (git config --global user.email)) { git config --global user.email (Read-Host '  git user.email') }
} else {
    Write-Warning 'git not on PATH yet. Open a new terminal and re-run with -SkipApps.'
}

# --- VS Code -----------------------------------------------------------------
if (-not $SkipConfig) {
    Step 'VS Code settings + keybindings'
    $codeUser = Join-Path $env:APPDATA 'Code\User'
    Copy-WithBackup (Join-Path $Repo 'vscode\settings.json')    (Join-Path $codeUser 'settings.json')
    Copy-WithBackup (Join-Path $Repo 'vscode\keybindings.json') (Join-Path $codeUser 'keybindings.json')
}

Step 'VS Code extensions'
if (Get-Command code -ErrorAction SilentlyContinue) {
    $installed = code --list-extensions
    Get-Content (Join-Path $Repo 'vscode\extensions.txt') |
        Where-Object { $_ -and $installed -notcontains $_ } |
        ForEach-Object { Write-Host "  [install] $_"; code --install-extension $_ --force | Out-Null }
} else {
    Write-Warning 'code not on PATH yet. Open a new terminal and re-run with -SkipApps.'
}

# --- Windows Terminal --------------------------------------------------------
if (-not $SkipConfig) {
    Step 'Windows Terminal settings'
    $wtDir = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Directory -Filter 'Microsoft.WindowsTerminal_*' -ErrorAction SilentlyContinue |
             Select-Object -First 1
    if ($wtDir) {
        Copy-WithBackup (Join-Path $Repo 'windows\terminal-settings.json') (Join-Path $wtDir.FullName 'LocalState\settings.json')
    } else {
        Write-Warning 'Windows Terminal not found. Launch it once, then re-run with -SkipApps.'
    }
}

# --- PowerToys ---------------------------------------------------------------
if (-not $SkipConfig) {
    Step 'PowerToys settings'
    & (Join-Path $PSScriptRoot 'powertoys.ps1') -Import
}

# --- Sysmon ------------------------------------------------------------------
if (-not $SkipSysmon) {
    Step 'Sysmon (SwiftOnSecurity config, needs admin)'
    try { & (Join-Path $PSScriptRoot 'install-sysmon.ps1') }
    catch { Write-Warning "Sysmon step failed: $($_.Exception.Message). Re-run scripts\install-sysmon.ps1 later." }
}

# --- Python ------------------------------------------------------------------
Step 'Python packages (user)'
if (Get-Command py -ErrorAction SilentlyContinue) {
    py -3.12 -m pip install --user --upgrade pip
    py -3.12 -m pip install --user -r (Join-Path $Repo 'windows\requirements.txt')
} else {
    Write-Warning 'py launcher not on PATH yet. Open a new terminal and re-run with -SkipApps.'
}

# --- Claude Code config (private repos) --------------------------------------
if (-not $SkipClaudeConfig) {
    Step 'Claude Code config (IshDeath/claude-config + maddenco-docs, private)'
    if (Get-Command git -ErrorAction SilentlyContinue) {
        # The IshDeath@ prefix makes Git Credential Manager use the personal GitHub login
        # (a browser sign-in prompt the first time).
        foreach ($name in 'claude-config', 'maddenco-docs') {
            $dest = Join-Path $HOME $name
            if (Test-Path (Join-Path $dest '.git')) { Write-Host "  [skip] $dest exists"; continue }
            git clone "https://IshDeath@github.com/IshDeath/$name.git" $dest
            if ($LASTEXITCODE -ne 0) { Write-Warning "clone of $name failed; re-run later with -SkipApps" }
        }
        $cc = Join-Path $HOME 'claude-config\install.ps1'
        if (Test-Path $cc) { & $cc -MaddenCoDocs (Join-Path $HOME 'maddenco-docs') }
    } else {
        Write-Warning 'git not on PATH yet. Open a new terminal and re-run with -SkipApps.'
    }
}

# --- Work extras -------------------------------------------------------------
if ($Work) {
    Step 'PowerShell modules (work)'
    foreach ($m in 'ExchangeOnlineManagement', 'Microsoft.Graph.Authentication') {
        if (-not (Get-InstalledModule $m -ErrorAction SilentlyContinue)) {
            Install-Module $m -Scope CurrentUser -Force -AllowClobber
        }
    }

    # AS400: JTOpen jar, IBM i Access ODBC + ACS, DBeaver connections
    & (Join-Path $PSScriptRoot 'install-work.ps1')
}

Write-Host @"

Done. Still manual (see README):
  - wsl --install -d Debian   (admin PowerShell, then reboot), then run scripts/install.sh inside Debian
  - Sign in: gh auth login, Claude Code (claude), VS Code Settings Sync if you use it
$(if ($Work) { '  - Work: IBM Data Server Client + php_ibm_db2, Xshell (not on winget)' })
"@
