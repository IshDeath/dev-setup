<#
.SYNOPSIS
  Work-laptop extras: AS400 / IBM i connectivity (JTOpen jar, IBM i Access ODBC driver,
  IBM i Access Client Solutions) and DBeaver connections.

.DESCRIPTION
  - Downloads the JTOpen JDBC jar (jt400) from Maven Central, verifies its SHA1, and sets the
    user env var AS400_JAR to it.
  - Installs the IBM i Access ODBC driver and ACS from the zips you downloaded from IBM.
    The IBM installers are licensed, so they are not stored in this repo. If you don't pass
    the zips, the script prints where to download them.
  - Writes DBeaver's connection list from work\dbeaver\data-sources.template.json, filling in
    the hosts you give it. Passwords are never stored. DBeaver asks on first connect.

  Called by install-windows.ps1 -Work, or run it on its own:

    powershell -ExecutionPolicy Bypass -File .\scripts\install-work.ps1 `
        -OdbcZip  "$HOME\Downloads\IBMiAccess_v1r1_WindowsAP_English.zip" `
        -AcsZip   "$HOME\Downloads\IBMiAccess_v1r1.zip"
#>
param(
    [string]$OdbcZip,
    [string]$AcsZip,
    [string]$As400Host,
    [string]$MysqlHost,
    [string]$MysqlDb,
    [string]$JarDir = 'C:\ITFiles\JTOpen',
    [string]$JtOpenVersion = '21.0.6',
    [string]$JtOpenSha1 = 'de32bf11a56b74d505120cb4e7626b02217bbc86'   # SHA1 for 21.0.6. Update it if you change the version.
)

$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot -Parent
$Stamp = Get-Date -Format 'yyyyMMddHHmmss'
$IbmAcsUrl = 'https://www.ibm.com/support/pages/ibm-i-access-client-solutions'

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

function Expand-ToTemp([string]$Zip) {
    $dest = Join-Path $env:TEMP ("ibm-" + [IO.Path]::GetFileNameWithoutExtension($Zip))
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Expand-Archive $Zip $dest
    return $dest
}

# --- JTOpen (JDBC jar) ---------------------------------------------------------
Step "JTOpen $JtOpenVersion"
$jar = Join-Path $JarDir "jt400-$JtOpenVersion.jar"
if (-not (Test-Path $jar)) {
    New-Item -ItemType Directory -Force $JarDir | Out-Null
    $url = "https://repo1.maven.org/maven2/net/sf/jt400/jt400/$JtOpenVersion/jt400-$JtOpenVersion.jar"
    Invoke-WebRequest $url -OutFile $jar -UseBasicParsing
}
$hash = (Get-FileHash $jar -Algorithm SHA1).Hash.ToLower()
if ($JtOpenSha1 -and $hash -ne $JtOpenSha1.ToLower()) {
    Remove-Item $jar
    throw "SHA1 mismatch for $jar (got $hash, expected $JtOpenSha1)"
}
[Environment]::SetEnvironmentVariable('AS400_JAR', $jar, 'User')
Write-Host "  $jar  (AS400_JAR set for your user)"

# --- IBM i Access ODBC driver -----------------------------------------------------
Step 'IBM i Access ODBC driver'
if (Get-OdbcDriver -Name 'IBM i Access ODBC Driver' -Platform 64-bit -ErrorAction SilentlyContinue) {
    Write-Host '  [skip] already installed'
} elseif ($OdbcZip) {
    $dir = Expand-ToTemp $OdbcZip
    $msi = Join-Path $dir 'Image64a\cwbinstall.msi'
    if (-not (Test-Path $msi)) { throw "cwbinstall.msi not found in $OdbcZip (expected Image64a\cwbinstall.msi)" }
    Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart" -Verb RunAs -Wait
    Write-Host '  installed (a reboot may be needed before the driver shows up)'
} else {
    Write-Host "  Not installed. Download 'IBM i Access - Windows Application Package' (needs an IBM ID):"
    Write-Host "    $IbmAcsUrl"
    Write-Host '  Then re-run with -OdbcZip <path to IBMiAccess_v1r1_WindowsAP_English.zip>'
}

# --- IBM i Access Client Solutions -----------------------------------------------
Step 'IBM i Access Client Solutions'
$acsHome = 'C:\Users\Public\IBM\ClientSolutions'
if (Test-Path (Join-Path $acsHome 'Start_Programs')) {
    Write-Host "  [skip] already at $acsHome"
} elseif ($AcsZip) {
    $dir = Expand-ToTemp $AcsZip
    $js = Get-ChildItem $dir -Recurse -Filter 'install_acs_64_allusers.js' | Select-Object -First 1
    if (-not $js) { throw "install_acs_64_allusers.js not found in $AcsZip" }
    Start-Process cscript.exe -ArgumentList "//nologo `"$($js.FullName)`"" -Verb RunAs -Wait
    Write-Host '  installed (needs Java, Temurin 21 from install-windows.ps1)'
} else {
    Write-Host "  Not installed. Download 'IBM i Access Client Solutions' (needs an IBM ID):"
    Write-Host "    $IbmAcsUrl"
    Write-Host '  Then re-run with -AcsZip <path to the ACS zip>'
}

# --- DBeaver connections ---------------------------------------------------------
Step 'DBeaver connections'
$dbDir = Join-Path $env:APPDATA 'DBeaverData\workspace6\General\.dbeaver'
$dbFile = Join-Path $dbDir 'data-sources.json'
if (-not $As400Host) { $As400Host = Read-Host '  AS400 host/IP' }
if (-not $MysqlHost) { $MysqlHost = Read-Host '  MySQL host/IP (blank to skip the MySQL connection)' }
if ($MysqlHost -and -not $MysqlDb) { $MysqlDb = Read-Host '  MySQL database' }

$json = Get-Content (Join-Path $Repo 'work\dbeaver\data-sources.template.json') -Raw
$json = $json.Replace('{{AS400_HOST}}', $As400Host).Replace('{{MYSQL_HOST}}', $MysqlHost).Replace('{{MYSQL_DB}}', $MysqlDb)
$cfg = $json | ConvertFrom-Json
if (-not $MysqlHost) {
    $cfg.connections.PSObject.Properties.Remove('mysql8-19eb20ef19b-60b5180148ff42f7')
}

New-Item -ItemType Directory -Force $dbDir | Out-Null
if (Test-Path $dbFile) { Copy-Item $dbFile "$dbFile.bak.$Stamp"; Write-Host "  backed up existing data-sources.json" }
[IO.File]::WriteAllText($dbFile, ($cfg | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding $false))   # no BOM
Write-Host "  $dbFile"
Write-Host '  Close DBeaver before running this. Passwords are not stored; DBeaver asks on first connect and downloads the jt400/MySQL drivers itself.'
