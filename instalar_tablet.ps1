# Script para tentar conectar e instalar no tablet
# Tenta diferentes IPs comuns

$env:Path += ";C:\Users\joaov\AppData\Local\Android\Sdk\platform-tools"
$APK_PATH = "build\app\outputs\flutter-apk\app-release.apk"
$PORT = "5555"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       📱 INSTALAÇÃO NO TABLET - TENTATIVA AUTOMÁTICA    ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# IPs comuns para tentar
$possibleIPs = @("192.168.3.155")
$customPorts = @{ "192.168.3.155" = "45487" }

Write-Host "🔍 Tentando conectar em IPs comuns..." -ForegroundColor Yellow
Write-Host ""

$connected = $false
$connectedIP = ""

foreach ($ip in $possibleIPs) {
    if ($customPorts.ContainsKey($ip)) { 
        $currentPort = $customPorts[$ip] 
    }
    else { 
        $currentPort = $PORT 
    }
    
    $connectString = "{0}:{1}" -f $ip, $currentPort
    Write-Host ("   Tentando: {0}..." -f $connectString) -ForegroundColor Gray -NoNewline
    
    $result = adb connect $connectString 2>&1
    Start-Sleep -Seconds 1
    
    $devices = adb devices | Select-String "$connectString.*device$"
    
    if ($devices) {
        Write-Host " ✅ CONECTADO!" -ForegroundColor Green
        $connected = $true
        $connectedIP = $ip
        $PORT = $currentPort # Update global port for installation
        break
    }
    else {
        Write-Host " ❌ Falhou" -ForegroundColor Red
    }
}

Write-Host ""

if ($connected) {
    $deviceString = "{0}:{1}" -f $connectedIP, $PORT

    Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ("   ✅ TABLET CONECTADO: {0}" -f $deviceString) -ForegroundColor Green
    Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "📲 Instalando APK..." -ForegroundColor Yellow
    Write-Host "   Aguarde..." -ForegroundColor Gray
    Write-Host ""
    
    adb -s $deviceString install -r $APK_PATH
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host "   ✅ INSTALADO COM SUCESSO NO TABLET!" -ForegroundColor Green
        Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host ""
        Write-Host "🎯 Próximo passo:" -ForegroundColor Cyan
        Write-Host "   Abra o app no tablet" -ForegroundColor White
        Write-Host "   Deve mostrar Setup Screen (limpo!)" -ForegroundColor White
        Write-Host ""
    }
    else {
        Write-Host ""
        Write-Host "❌ Erro na instalação" -ForegroundColor Red
        Write-Host ""
    }
    
}
else {
    Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "   ❌ NÃO FOI POSSÍVEL CONECTAR AO TABLET" -ForegroundColor Red
    Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    
    Write-Host "📋 SOLUÇÃO MANUAL:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "NO TABLET:" -ForegroundColor Cyan
    Write-Host "  1. Vá em: Configurações > Sobre o tablet" -ForegroundColor White
    Write-Host "  2. Toque 7x em 'Número da versão'" -ForegroundColor White
    Write-Host "  3. Vá em: Configurações > Opções do desenvolvedor" -ForegroundColor White
    Write-Host "  4. Ative: 'Depuração USB'" -ForegroundColor White
    Write-Host "  5. Ative: 'Depuração sem fio' (se tiver)" -ForegroundColor White
    Write-Host ""
    Write-Host "  6. Vá em: Configurações > Wi-Fi" -ForegroundColor White
    Write-Host "  7. Toque na rede conectada" -ForegroundColor White
    Write-Host "  8. Anote o IP (endereço IP)" -ForegroundColor White
    Write-Host ""
    
    Write-Host "DEPOIS, NO PC:" -ForegroundColor Cyan
    Write-Host "  adb connect SEU_IP:5555" -ForegroundColor Yellow
    Write-Host "  .\instalar_tablet.ps1" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}
