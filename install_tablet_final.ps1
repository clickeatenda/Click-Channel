# Install Script with Absolute Paths
$ADB = "C:\Users\joaov\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$APK = "build\app\outputs\flutter-apk\app-release.apk"
$PKG = "com.click_channel"
# IP descoberto anteriormente
$DEVICE = "192.168.3.155:44229"

Write-Host "Target Device: $DEVICE"

Write-Host "Uninstalling old version..."
& $ADB -s $DEVICE uninstall $PKG

Write-Host "Installing new version..."
& $ADB -s $DEVICE install -r $APK

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ SUCCESS!" -ForegroundColor Green
    
    Write-Host "Launching app..."
    & $ADB -s $DEVICE shell monkey -p $PKG -c android.intent.category.LAUNCHER 1
}
else {
    Write-Host "❌ INSTALL FAILED" -ForegroundColor Red
}
