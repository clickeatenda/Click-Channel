# Simple Reinstall Script
$env:Path += ";C:\Users\joaov\AppData\Local\Android\Sdk\platform-tools"
$APK = "build\app\outputs\flutter-apk\app-release.apk"
$PKG = "com.click_channel"
$IP = "192.168.3.159"

Write-Host "Connecting to $IP..."
adb connect "$IP`:5555"

Write-Host "Check devices..."
adb devices

Write-Host "Uninstalling..."
adb uninstall $PKG

Write-Host "Installing..."
adb install -r $APK

Write-Host "Done."
