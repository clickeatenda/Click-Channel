# Usage: Update $tabletIp and $firestickIp then run in PowerShell
# Requirements: adb in PATH (Android SDK platform-tools)

# Change these to your device IPs
$tabletIp = '192.168.3.155:39453'   # replace if different
$firestickIp = '192.168.3.110:5555'   # replace with your Firestick IP:port (usually 5555)

$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
$package = 'com.example.clickflix'

# Path to adb (use local sdk if adb not in PATH)
$adbPath = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"

function Install-ToDevice($device) {
    Write-Host "Connecting to $device..."
    & "$adbPath" connect $device
    if ($LASTEXITCODE -ne 0) { Write-Error "Failed to connect to $device"; return }

    Write-Host "Installing APK to $device..."
    & "$adbPath" -s $device install -r $apkPath
    if ($LASTEXITCODE -ne 0) { Write-Error "Failed to install on $device"; return }

    Write-Host "Clearing app data on $device..."
    & "$adbPath" -s $device shell pm clear $package

    Write-Host "Starting app on $device..."
    & "$adbPath" -s $device shell am start -n $package/.MainActivity

    Write-Host "Collecting logcat filtered lines (ContentEnricher/TMDB/MetaChipsWidget)..."
    & "$adbPath" -s $device logcat -d | Select-String -Pattern 'ContentEnricher|TMDB|Tmdb|MetaChipsWidget' > "tmdb_log_$($device -replace ':','_').txt"
    Write-Host "Logs saved to tmdb_log_$($device -replace ':','_').txt"
}

# Run installations
Install-ToDevice $tabletIp
# Uncomment to install to Firestick after updating $firestickIp
# Install-ToDevice $firestickIp

Write-Host 'Done.'
