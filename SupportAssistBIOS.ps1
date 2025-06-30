# Relaunch as admin if needed
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Restarting as Administrator..."
    Start-Process powershell -Verb runAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# ----- BIOS PASSWORD VERIFICATION -----
$storedPassword = Import-Clixml -Path "$PSScriptRoot\Secure_pwd.xml"
$enteredPassword = Read-Host "Enter BIOS Setup Password to Continue" -AsSecureString

$storedPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($storedPassword))
$enteredPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($enteredPassword))

if ($storedPlain -ne $enteredPlain) {
    Write-Host "`n[ERROR] Incorrect password. Access denied." -ForegroundColor Red
    exit 1
}

# ----- TOOL PATHS -----
$dcuCLIPath = "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe"
$dcuInstaller = "$PSScriptRoot\Dell-Command-Update-Application.exe"
$logFile = "$PSScriptRoot\dcu_update_log.txt"

# ----- STEP 1: Install DCU if missing -----
if (-not (Test-Path $dcuCLIPath)) {
    Write-Host "`n[INFO] Dell Command | Update CLI not found. Installing..."
    if (Test-Path $dcuInstaller) {
        Start-Process -FilePath $dcuInstaller -ArgumentList "/s" -Wait
        Start-Sleep -Seconds 5
    } else {
        Write-Host "[ERROR] Dell Command | Update installer not found at: $dcuInstaller"
        exit 1
    }
}

# ----- STEP 2: Capture BIOS Version Before -----
$biosBefore = (Get-WmiObject Win32_BIOS).SMBIOSBIOSVersion
Write-Host "`n[INFO] Current BIOS version: $biosBefore"

# ----- STEP 3: Run DCU with BIOS Password -----
Write-Host "`n[INFO] Running Dell Command | Update..."
$proc = Start-Process -FilePath $dcuCLIPath `
    -ArgumentList "/applyUpdates", "/silent", "/reboot=disable", "/valsetuppwd=$enteredPlain", "/outputLog=$logFile" `
    -Wait -PassThru

# ----- STEP 4: Capture BIOS Version After -----
$biosAfter = (Get-WmiObject Win32_BIOS).SMBIOSBIOSVersion
Write-Host "`n[INFO] BIOS version after update: $biosAfter"

# ----- STEP 5: Check Exit Code and Log -----
Write-Host "`n[INFO] DCU Exit Code: $($proc.ExitCode)"
if (Test-Path $logFile) {
    Write-Host "`n[INFO] Log file saved to: $logFile"
} else {
    Write-Host "[WARNING] No log file generated."
}

Read-Host "`n[INFO] Script completed. Press Enter to close."
