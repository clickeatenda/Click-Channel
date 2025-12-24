# Instalação via USB no tablet

$env:Path += ";C:\Users\joaov\AppData\Local\Android\Sdk\platform-tools"
$APK_PATH = "build\app\outputs\flutter-apk\app-release.apk"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          📱 INSTALAÇÃO VIA USB - TABLET                  ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "1️⃣  Conecte o tablet ao PC com cabo USB" -ForegroundColor Yellow
Write-Host ""
Write-Host "2️⃣  No tablet, vai aparecer um popup:" -ForegroundColor Yellow
Write-Host "   'Permitir depuração USB deste computador?'" -ForegroundColor White
Write-Host "   Marque: ☑ Sempre permitir deste computador" -ForegroundColor Green
Write-Host "   Toque em: OK" -ForegroundColor Green
Write-Host ""

Read-Host "Pressione ENTER depois de conectar e autorizar"

Write-Host ""
Write-Host "🔍 Verificando dispositivos..." -ForegroundColor Yellow
adb devices

Write-Host ""
Write-Host "Se o tablet aparecer acima (sem 'unauthorized'), vamos instalar!" -ForegroundColor Cyan
Write-Host ""

$devices = adb devices | Select-String "device$" | Where-Object { $_ -notmatch "List of devices" }

if ($devices) {
    Write-Host "✅ Dispositivo detectado!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📲 Instalando APK no tablet..." -ForegroundColor Yellow
    Write-Host "   Aguarde..." -ForegroundColor Gray
    Write-Host ""
    
    # Pega o primeiro device ID
    $deviceId = ($devices[0] -split "\s+")[0]
    
    adb -s $deviceId install -r $APK_PATH
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║        ✅ INSTALADO COM SUCESSO NO TABLET!               ║" -ForegroundColor Green
        Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""
        Write-Host "🎯 Próximos passos:" -ForegroundColor Cyan
        Write-Host "   1. Abra o app no tablet" -ForegroundColor White
        Write-Host "   2. Deve mostrar Setup Screen (SEM lista antiga)" -ForegroundColor White
        Write-Host "   3. Configure sua playlist atual" -ForegroundColor White
        Write-Host ""
        
        # Habilitar ADB via Wi-Fi para próximas vezes
        Write-Host "💡 Quer habilitar instalação via Wi-Fi para próximas vezes? (s/n)" -ForegroundColor Yellow -NoNewline
        $resposta = Read-Host " "
        
        if ($resposta -eq "s") {
            Write-Host ""
            Write-Host "Habilitando ADB via Wi-Fi..." -ForegroundColor Yellow
            adb -s $deviceId tcpip 5555
            Write-Host ""
            Write-Host "✅ Pronto! Da próxima vez você pode usar:" -ForegroundColor Green
            Write-Host "   adb connect 192.168.3.129:5555" -ForegroundColor Cyan
            Write-Host ""
        }
    } else {
        Write-Host ""
        Write-Host "❌ Erro na instalação" -ForegroundColor Red
        Write-Host ""
    }
} else {
    Write-Host "❌ Nenhum dispositivo detectado" -ForegroundColor Red
    Write-Host ""
    Write-Host "Verifique:" -ForegroundColor Yellow
    Write-Host "  • Cabo USB está conectado?" -ForegroundColor White
    Write-Host "  • Autorizou a depuração USB no tablet?" -ForegroundColor White
    Write-Host "  • Tablet tem 'Depuração USB' ativada?" -ForegroundColor White
    Write-Host ""
}

