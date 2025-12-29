<#
PowerShell script to build the Flutter APK and install on Fire TV (ADB over network) and Android Tablet (USB).
Usage examples:
  # Build and install to Firestick IP
  .\install_to_devices.ps1 -FireIp 192.168.1.50

  # Build and install to USB device
  .\install_to_devices.ps1 -UsbDeviceId 0123456789

  # Build and install to both
  .\install_to_devices.ps1 -FireIp 192.168.1.50 -UsbDeviceId 0123456789

Requirements:
- Flutter and ADB must be in PATH.
- Run PowerShell as Administrator if needed to access devices.
#>
param(
  [string]$FireIp,
  [string]$UsbDeviceId,
  [switch]$SplitPerAbi
)

function Write-Info($s){ Write-Host $s -ForegroundColor Cyan }
function Write-ErrorAndExit($s){ Write-Host $s -ForegroundColor Red; exit 1 }

# Ensure we're in project root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $scriptDir

if (!(Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-ErrorAndExit "flutter not found in PATH. Install Flutter and add to PATH."
}
if (!(Get-Command adb -ErrorAction SilentlyContinue)) {
  Write-ErrorAndExit "adb not found in PATH. Install Android Platform Tools and add adb to PATH."
}

Write-Info "Starting build (clean + pub get)..."
flutter clean
flutter pub get

if ($SplitPerAbi) {
  Write-Info "Building split-per-ABI APKs..."
  flutter build apk --split-per-abi
  # pick arm64 variant if exists
  $apkPath64 = "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
  $apkPath32 = "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk"
  if (Test-Path $apkPath64) { $apkToUse = $apkPath64 } elseif (Test-Path $apkPath32) { $apkToUse = $apkPath32 } else { Write-ErrorAndExit "APK not found after build." }
} else {
  Write-Info "Building single APK (universal)..."
  flutter build apk --release --target-platform android-arm,android-arm64
  $apkToUse = "build\app\outputs\flutter-apk\app-release.apk"
  if (-not (Test-Path $apkToUse)) { Write-ErrorAndExit "APK not found at $apkToUse" }
}

Write-Info "APK built: $apkToUse"

# Install to Fire TV (ADB over network)
if ($FireIp) {
  Write-Info "Installing to Fire TV at $FireIp..."
  $connectOut = & adb connect "$FireIp`:5555"
  Write-Host $connectOut
  Start-Sleep -Seconds 1
  $devices = (& adb devices) -join "`n"
  Write-Host $devices
  $target = "$FireIp`:5555"
  Write-Info "Installing APK..."
  $res = & adb -s $target install -r "$apkToUse" 2>&1
  Write-Host $res
  if ($res -match "Success") { Write-Info "Installed on Fire TV ($target)" } else { Write-Host "Install output did not report Success. Check device, enable ADB, and run adb devices." -ForegroundColor Yellow }
}

# Install to USB-connected device
if ($UsbDeviceId) {
  Write-Info "Installing to USB device $UsbDeviceId..."
  $devices = (& adb devices) -join "`n"
  Write-Host $devices
  $res = & adb -s $UsbDeviceId install -r "$apkToUse" 2>&1
  Write-Host $res
  if ($res -match "Success") { Write-Info "Installed on USB device ($UsbDeviceId)" } else { Write-Host "Install may have failed. Check device and run adb devices." -ForegroundColor Yellow }
}

Write-Info "Done. If installed, open the app on the device or use adb to start the main activity." 
Write-Info "To start via adb: adb -s <device> shell monkey -p <package.name> 1"

# End of script
