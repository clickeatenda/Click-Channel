$adb = "C:\Users\joaov\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$apk = "build\app\outputs\flutter-apk\app-release.apk"
$package = "com.example.clickflix"
# Updated with the specific IP provided by the user
$target = "192.168.3.155:39763"

Write-Host "Starting installer for $target..."

Write-Host "Connecting to $target..."
& $adb connect $target

$output = & $adb devices
if ($output -match "$target\s+device") {
    Write-Host "✅ CONNECTED to $target!"
    
    Write-Host "🗑️ Uninstalling old app..."
    & $adb -s $target uninstall $package
    
    Write-Host "📦 Installing APK..."
    & $adb -s $target install -r $apk
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ INSTALLATION SUCCESSFUL!"
        
        Write-Host "🚀 Launching app..."
        & $adb -s $target shell monkey -p $package -c android.intent.category.LAUNCHER 1
        exit 0
    }
    else {
        Write-Host "❌ Installation failed."
        exit 1
    }
}
else {
    Write-Host "❌ Failed to connect to $target. Check IP/Port and ensure Wireless Debugging is active."
    & $adb disconnect $target
    exit 1
}
