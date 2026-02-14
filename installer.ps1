#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs moveTorrentsToFTP as a Windows service.
.DESCRIPTION
    Sets up Python venv, installs dependencies, prompts for configuration,
    and registers the script as a Windows service using NSSM.
#>

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VenvDir = Join-Path $ProjectDir ".venv"
$NssmExe = Join-Path $ProjectDir "utilities\nssm-2.24-101-g897c7ad\win64\nssm.exe"
$ServiceName = "moveTorrentsToFTP"
$UninstallRegKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$ServiceName"

Write-Host "=== moveTorrentsToFTP Installer ===" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Check for Python ---
Write-Host "[1/6] Checking for Python..." -ForegroundColor Yellow
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Host "ERROR: Python not found in PATH. Install Python 3.10+ and try again." -ForegroundColor Red
    exit 1
}
$pyVersion = & python --version 2>&1
Write-Host "  Found: $pyVersion"

# --- Step 2: Create virtual environment ---
Write-Host "[2/6] Creating virtual environment..." -ForegroundColor Yellow
if (Test-Path $VenvDir) {
    Write-Host "  .venv already exists, skipping creation."
} else {
    & python -m venv $VenvDir
    Write-Host "  Created .venv"
}

# --- Step 3: Install dependencies ---
Write-Host "[3/6] Installing dependencies..." -ForegroundColor Yellow
$pipExe = Join-Path $VenvDir "Scripts\pip.exe"
& $pipExe install -r (Join-Path $ProjectDir "requirements.txt")
Write-Host "  Dependencies installed."

# --- Step 4: Configure .env ---
Write-Host "[4/6] Configuring environment..." -ForegroundColor Yellow
$envFile = Join-Path $ProjectDir ".env"

if (Test-Path $envFile) {
    $overwrite = Read-Host "  .env already exists. Overwrite? (y/N)"
    if ($overwrite -ne "y") {
        Write-Host "  Keeping existing .env"
        $skipEnv = $true
    }
}

if (-not $skipEnv) {
    Write-Host ""
    $ftpUsername = Read-Host "  FTP Username"
    $ftpPassword = Read-Host "  FTP Password"
    $ftpLocalIp = Read-Host "  FTP Server IP"
    $ftpDestDir = Read-Host "  FTP Destination Dir (default: /opt/qbittorrent/loadDir/)"
    if ([string]::IsNullOrWhiteSpace($ftpDestDir)) { $ftpDestDir = "/opt/qbittorrent/loadDir/" }
    $watchDir = Read-Host "  Watch Directory (default: C:\Users\$env:USERNAME\Downloads)"
    if ([string]::IsNullOrWhiteSpace($watchDir)) { $watchDir = "C:\Users\$env:USERNAME\Downloads" }

    @"
FTP_USERNAME=$ftpUsername
FTP_PASSWORD=$ftpPassword
FTP_LOCALIP=$ftpLocalIp
FTP_DEST_DIR=$ftpDestDir
WATCH_DIR=$watchDir
"@ | Set-Content -Path $envFile -Encoding UTF8

    Write-Host "  .env written."
}

# --- Step 5: Install Windows service via NSSM ---
Write-Host "[5/6] Installing Windows service..." -ForegroundColor Yellow

if (-not (Test-Path $NssmExe)) {
    Write-Host "ERROR: NSSM not found at $NssmExe" -ForegroundColor Red
    exit 1
}

# Remove existing service if present
$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "  Removing existing service..."
    & $NssmExe stop $ServiceName 2>$null
    & $NssmExe remove $ServiceName confirm
}

$pythonExe = Join-Path $VenvDir "Scripts\python.exe"
$mainPy = Join-Path $ProjectDir "main.py"

& $NssmExe install $ServiceName $pythonExe $mainPy
& $NssmExe set $ServiceName AppDirectory $ProjectDir
& $NssmExe set $ServiceName DisplayName "Move Torrents to FTP"
& $NssmExe set $ServiceName Description "Watches for .torrent files and uploads them via FTP"
& $NssmExe set $ServiceName Start SERVICE_AUTO_START
& $NssmExe set $ServiceName AppStdout (Join-Path $ProjectDir "service_stdout.log")
& $NssmExe set $ServiceName AppStderr (Join-Path $ProjectDir "service_stderr.log")

# --- Step 6: Register in Add/Remove Programs ---
Write-Host "[6/6] Registering in Add/Remove Programs..." -ForegroundColor Yellow
$uninstallCmd = "powershell.exe -ExecutionPolicy Bypass -File `"$(Join-Path $ProjectDir 'uninstaller.ps1')`""

if (-not (Test-Path $UninstallRegKey)) {
    New-Item -Path $UninstallRegKey -Force | Out-Null
}
Set-ItemProperty -Path $UninstallRegKey -Name "DisplayName" -Value "Move Torrents to FTP"
Set-ItemProperty -Path $UninstallRegKey -Name "UninstallString" -Value $uninstallCmd
Set-ItemProperty -Path $UninstallRegKey -Name "InstallLocation" -Value $ProjectDir
Set-ItemProperty -Path $UninstallRegKey -Name "Publisher" -Value "moveTorrentsToFTP"
Set-ItemProperty -Path $UninstallRegKey -Name "DisplayVersion" -Value "1.0.0"
Set-ItemProperty -Path $UninstallRegKey -Name "NoModify" -Value 1 -Type DWord
Set-ItemProperty -Path $UninstallRegKey -Name "NoRepair" -Value 1 -Type DWord
Write-Host "  Registered in Add/Remove Programs."

Write-Host ""
Write-Host "Service '$ServiceName' installed successfully." -ForegroundColor Green
Write-Host ""
Write-Host "Manage the service with:" -ForegroundColor Cyan
Write-Host "  Start:   nssm start $ServiceName"
Write-Host "  Stop:    nssm stop $ServiceName"
Write-Host "  Uninstall: via Add/Remove Programs or run uninstaller.ps1 as admin"
Write-Host ""

$startNow = Read-Host "Start the service now? (Y/n)"
if ($startNow -ne "n") {
    & $NssmExe start $ServiceName
    Write-Host "Service started." -ForegroundColor Green
}
