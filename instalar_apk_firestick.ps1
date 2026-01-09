# Script para instalar APK no Firestick
$adbPath = "C:\Android\sdk\platform-tools\adb.exe"
$apkPath = ".\build\app\outputs\flutter-apk\app-release.apk"
$packageName = "com.cliqueatenda.clickechannel"
$firestickIp = "192.168.3.110:5555"

Write-Host "🔌 Conectando ao Firestick..." -ForegroundColor Cyan
& $adbPath connect $firestickIp

Write-Host "⏳ Aguardando conexão..." -ForegroundColor Cyan
Start-Sleep -Seconds 2

Write-Host "📱 Listando dispositivos conectados..." -ForegroundColor Cyan
& $adbPath devices

Write-Host "🗑️ Desinstalando versão anterior..." -ForegroundColor Yellow
& $adbPath -s $firestickIp uninstall $packageName

Write-Host "📥 Instalando novo APK..." -ForegroundColor Green
& $adbPath -s $firestickIp install -r $apkPath

Write-Host "✅ Instalação concluída!" -ForegroundColor Green
Write-Host "🚀 Iniciando app..." -ForegroundColor Cyan
& $adbPath -s $firestickIp shell am start -n "$packageName/.MainActivity"

Write-Host "📋 Coletando logs..." -ForegroundColor Cyan
Start-Sleep -Seconds 3
& $adbPath -s $firestickIp logcat -s "flutter:*" "clickechannel:*" "TMDB:*" --pid=$( & $adbPath -s $firestickIp shell pidof $packageName)
