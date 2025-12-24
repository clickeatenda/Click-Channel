# Script de Deploy - Click Channel
# Compila APK e instala no Fire Stick e Tablet

$APK_PATH = "build\app\outputs\flutter-apk\app-release.apk"
$FIRESTICK_IP = "192.168.3.110"
$FIRESTICK_PORT = "5555"
$TABLET_IP = "192.168.3.159"
$TABLET_PORT = "41697"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        🚀 DEPLOY CLICK CHANNEL - FIRE STICK & TABLET    ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Passo 1: Compilar APK
Write-Host "📦 [1/4] Compilando APK Release..." -ForegroundColor Yellow
Write-Host "      Isso pode levar alguns minutos..." -ForegroundColor Gray
Write-Host ""

flutter build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ Erro na compilação do APK!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ APK compilado com sucesso!" -ForegroundColor Green

# Verificar tamanho do APK
$apkSize = (Get-Item $APK_PATH).Length / 1MB
Write-Host "📊 Tamanho do APK: $([math]::Round($apkSize, 2)) MB" -ForegroundColor Cyan
Write-Host ""

# Passo 2: Conectar dispositivos
Write-Host "🔌 [2/4] Conectando aos dispositivos..." -ForegroundColor Yellow
Write-Host ""

Write-Host "   • Conectando Fire Stick (${FIRESTICK_IP}:${FIRESTICK_PORT})..." -ForegroundColor Gray
adb connect "${FIRESTICK_IP}:${FIRESTICK_PORT}" | Out-Null

Write-Host "   • Conectando Tablet (${TABLET_IP}:${TABLET_PORT})..." -ForegroundColor Gray
adb connect "${TABLET_IP}:${TABLET_PORT}" | Out-Null

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "📱 Dispositivos conectados:" -ForegroundColor Cyan
adb devices
Write-Host ""

# Verificar se dispositivos estão conectados
$devices = adb devices | Select-String -Pattern "device$"
$connectedCount = ($devices | Measure-Object).Count

if ($connectedCount -lt 2) {
    Write-Host "⚠️  Aviso: Apenas $connectedCount dispositivo(s) conectado(s)" -ForegroundColor Yellow
    Write-Host "   Verifique se os dispositivos estão ligados e com ADB habilitado" -ForegroundColor Yellow
    Write-Host ""
    
    $continue = Read-Host "Deseja continuar mesmo assim? (s/N)"
    if ($continue -ne "s" -and $continue -ne "S") {
        Write-Host "Deploy cancelado." -ForegroundColor Red
        exit 1
    }
}

# Passo 3: Instalar no Fire Stick
Write-Host "📲 [3/4] Instalando no Fire Stick..." -ForegroundColor Yellow
Write-Host "      IP: $FIRESTICK_IP" -ForegroundColor Gray
Write-Host ""

$fireResult = adb -s "${FIRESTICK_IP}:${FIRESTICK_PORT}" install -r $APK_PATH 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Instalado com sucesso no Fire Stick!" -ForegroundColor Green
} else {
    Write-Host "❌ Erro ao instalar no Fire Stick" -ForegroundColor Red
    Write-Host "   $fireResult" -ForegroundColor Gray
}
Write-Host ""

# Passo 4: Instalar no Tablet
Write-Host "📲 [4/4] Instalando no Tablet..." -ForegroundColor Yellow
Write-Host "      IP: $TABLET_IP" -ForegroundColor Gray
Write-Host ""

$tabletResult = adb -s "${TABLET_IP}:${TABLET_PORT}" install -r $APK_PATH 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Instalado com sucesso no Tablet!" -ForegroundColor Green
} else {
    Write-Host "❌ Erro ao instalar no Tablet" -ForegroundColor Red
    Write-Host "   $tabletResult" -ForegroundColor Gray
}
Write-Host ""

# Resumo final
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                  🎉 DEPLOY CONCLUÍDO! 🎉                 ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Resumo:" -ForegroundColor Cyan
Write-Host "   • APK compilado: $([math]::Round($apkSize, 2)) MB" -ForegroundColor White
Write-Host "   • Fire Stick ($FIRESTICK_IP): " -NoNewline -ForegroundColor White
if ($fireResult -match "Success") { 
    Write-Host "✅ OK" -ForegroundColor Green 
} else { 
    Write-Host "❌ Erro" -ForegroundColor Red 
}
Write-Host "   • Tablet ($TABLET_IP): " -NoNewline -ForegroundColor White
if ($tabletResult -match "Success") { 
    Write-Host "✅ OK" -ForegroundColor Green 
} else { 
    Write-Host "❌ Erro" -ForegroundColor Red 
}
Write-Host ""
Write-Host "💡 Dica: Abra o app nos dispositivos para testar!" -ForegroundColor Yellow
Write-Host ""

