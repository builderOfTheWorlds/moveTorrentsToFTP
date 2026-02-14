#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Uninstalls moveTorrentsToFTP Windows service and removes registry entries.
.DESCRIPTION
    Stops and removes the NSSM service, removes the Add/Remove Programs entry,
    and optionally deletes the virtual environment and .env configuration.
#>

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$NssmExe = Join-Path $ProjectDir "utilities\nssm-2.24-101-g897c7ad\win64\nssm.exe"
$ServiceName = "moveTorrentsToFTP"
$UninstallRegKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$ServiceName"

Write-Host "=== moveTorrentsToFTP Uninstaller ===" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Stop and remove the Windows service ---
Write-Host "[1/3] Removing Windows service..." -ForegroundColor Yellow
$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existingService) {
    & $NssmExe stop $ServiceName 2>$null
    & $NssmExe remove $ServiceName confirm
    Write-Host "  Service removed."
} else {
    Write-Host "  Service not found, skipping."
}

# --- Step 2: Remove Add/Remove Programs registry entry ---
Write-Host "[2/3] Removing registry entry..." -ForegroundColor Yellow
if (Test-Path $UninstallRegKey) {
    Remove-Item -Path $UninstallRegKey -Force
    Write-Host "  Registry entry removed."
} else {
    Write-Host "  Registry entry not found, skipping."
}

# --- Step 3: Optional cleanup ---
Write-Host "[3/3] Optional cleanup..." -ForegroundColor Yellow

$removeVenv = Read-Host "  Delete virtual environment (.venv)? (y/N)"
if ($removeVenv -eq "y") {
    $venvDir = Join-Path $ProjectDir ".venv"
    if (Test-Path $venvDir) {
        Remove-Item -Path $venvDir -Recurse -Force
        Write-Host "  .venv deleted."
    }
}

$removeEnv = Read-Host "  Delete configuration (.env)? (y/N)"
if ($removeEnv -eq "y") {
    $envFile = Join-Path $ProjectDir ".env"
    if (Test-Path $envFile) {
        Remove-Item -Path $envFile -Force
        Write-Host "  .env deleted."
    }
}

$removeLogs = Read-Host "  Delete log files? (y/N)"
if ($removeLogs -eq "y") {
    Get-ChildItem -Path $ProjectDir -Filter "*.log" | Remove-Item -Force
    Write-Host "  Log files deleted."
}

Write-Host ""
Write-Host "moveTorrentsToFTP has been uninstalled." -ForegroundColor Green
Write-Host ""
