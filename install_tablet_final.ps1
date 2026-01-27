$adb = "C:\Users\joaov\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$deviceIp = "192.168.3.155"
$port = "45487"

Write-Host "Target Device: ${deviceIp}:${port}"

& $adb connect "${deviceIp}:${port}"

Write-Host "Uninstalling old version..."
& $adb -s "${deviceIp}:${port}" uninstall com.example.clickflix

Write-Host "Installing new version..."
if (Test-Path "build/app/outputs/flutter-apk/app-release.apk") {
    Write-Host "Found Release APK. Installing..."
    & $adb -s "${deviceIp}:${port}" install -r build/app/outputs/flutter-apk/app-release.apk
}
elseif (Test-Path "build/app/outputs/flutter-apk/app-debug.apk") {
    Write-Host "Found Debug APK. Installing..."
    & $adb -s "${deviceIp}:${port}" install -r build/app/outputs/flutter-apk/app-debug.apk
}
else {
    Write-Host "❌ No APK found (Release or Debug). Build failed?"
    exit 1
}

Write-Host "Success"
