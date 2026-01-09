<#
PowerShell script to build APK, uninstall from devices, and reinstall.
Usage: .\build_and_install_all.ps1
#>

param(
  [string]$FireIp = "192.168.3.110",
  [string]$TabletEndpoint = "192.168.3.155:39453"
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "✓ $msg" -ForegroundColor Cyan }
function Write-Error2($msg) { Write-Host "✗ $msg" -ForegroundColor Red }
function Write-Success($msg) { Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Warning2($msg) { Write-Host "⚠️  $msg" -ForegroundColor Yellow }

# Detect package name from AndroidManifest.xml
function Get-PackageName {
  try {
    $manifestPath = "android/app/src/main/AndroidManifest.xml"
    if (-not (Test-Path $manifestPath)) {
      Write-Warning2 "AndroidManifest.xml not found at $manifestPath"
      return $null
    }
    
    $content = Get-Content $manifestPath -Raw
    # Try to extract package from manifest tag
    if ($content -match 'package\s*=\s*["\']([^"\']+)["\']') {
      return $Matches[1]
    }
    
    # If not found in manifest, use a default pattern
    # For Flutter apps without explicit package, try to infer from pubspec.yaml
    if (Test-Path "pubspec.yaml") {
      $pubspec = Get-Content pubspec.yaml -Raw
      if ($pubspec -match 'name:\s*(\w+)') {
        $appName = $Matches[1]
        return "com.$appName"
      }
    }
    
    Write-Warning2 "Could not determine package name; will skip uninstall"
    return $null
  } catch {
    Write-Warning2 "Error detecting package name: $_"
    return $null
  }
}

Write-Info "Starting build, uninstall, and reinstall process..."
Write-Info "Fire TV IP: $FireIp"
Write-Info "Tablet endpoint: $TabletEndpoint"

# Step 1: Build APK
Write-Info "Building release APK..."
flutter clean
if ($LASTEXITCODE -ne 0) { throw "flutter clean failed" }

flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

Write-Info "Compiling APK (this may take a few minutes)..."
flutter build apk --release --target-platform android-arm,android-arm64
if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed" }

$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apkPath)) {
  throw "APK not found at $apkPath"
}

Write-Success "APK built: $apkPath"

# Get package name
$packageName = Get-PackageName
if (-not $packageName) {
  Write-Warning2 "Package name not found; defaulting to 'com.click_channel'"
  $packageName = "com.click_channel"
}
Write-Info "Package name: $packageName"

# Step 2: Connect devices
Write-Info "Connecting to devices..."
adb connect "$FireIp`:5555" | Out-Null
Start-Sleep -Seconds 2
adb devices

# Step 3: Uninstall from Fire TV
Write-Info "Uninstalling from Fire TV ($FireIp:5555)..."
try {
  adb -s "$FireIp`:5555" uninstall "$packageName" | Out-Null
  Write-Success "Uninstalled from Fire TV"
} catch {
  Write-Warning2 "Could not uninstall from Fire TV: $_"
}

# Step 4: Install on Fire TV
Write-Info "Installing APK on Fire TV..."
$fireInstall = & adb -s "$FireIp`:5555" install -r "$apkPath" 2>&1
Write-Host $fireInstall
if ($fireInstall -match "Success") {
  Write-Success "Installed on Fire TV ($FireIp:5555)"
} else {
  Write-Error2 "Fire TV install may have failed. Output: $fireInstall"
}

# Step 5: Uninstall from Tablet
Write-Info "Uninstalling from Tablet ($TabletEndpoint)..."
try {
  adb -s "$TabletEndpoint" uninstall "$packageName" | Out-Null
  Write-Success "Uninstalled from Tablet"
} catch {
  Write-Warning2 "Could not uninstall from Tablet: $_"
}

# Step 6: Install on Tablet
Write-Info "Installing APK on Tablet..."
$tabletInstall = & adb -s "$TabletEndpoint" install -r "$apkPath" 2>&1
Write-Host $tabletInstall
if ($tabletInstall -match "Success") {
  Write-Success "Installed on Tablet ($TabletEndpoint)"
} else {
  Write-Error2 "Tablet install may have failed. Output: $tabletInstall"
}

Write-Success "Done! App should now be installed on both devices."
Write-Info "You can open the app from the device menu or run:"
Write-Info "  adb -s $FireIp:5555 shell monkey -p $packageName 1     (Fire TV)"
Write-Info "  adb -s $TabletEndpoint shell monkey -p $packageName 1  (Tablet)"
