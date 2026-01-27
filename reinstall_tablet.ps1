# Script para REINSTALAR (Desinstalar + Instalar) no tablet
# Adiciona platform-tools ao path para garantir que adb funcione

$env:Path += ";C:\Users\joaov\AppData\Local\Android\Sdk\platform-tools"
$APK_PATH = "build\app\outputs\flutter-apk\app-release.apk"
$PACKAGE_NAME = "com.example.clickflix"
$PORT = "5555"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       🔄 REINSTALAÇÃO LIMPA NO TABLET                    ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# IPs comuns para tentar
$possibleIPs = @("192.168.3.155", "192.168.3.159", "192.168.3.129", "192.168.1.159", "192.168.0.159")

Write-Host "🔍 Conectando ao tablet..." -ForegroundColor Yellow

$connected = $false
$connectedIP = ""

foreach ($ip in $possibleIPs) {
    Write-Host "   Tentando: $ip..." -ForegroundColor Gray -NoNewline
    
    # Tenta conectar
    adb connect "$($ip):$PORT" | Out-Null
    
    # Verifica se conectou
    $devices = adb devices
    $pattern = "$($ip):$PORT\s+device"
    
    if ($devices -match $pattern) {
        Write-Host " ✅ CONECTADO!" -ForegroundColor Green
        $connected = $true
        $connectedIP = $ip
        break
    }
    else {
        Write-Host " ❌ Falhou" -ForegroundColor Red
    }
}

Write-Host ""

if ($connected) {
    Write-Host "🗑️  Desinstalando versão anterior..." -ForegroundColor Yellow
    # Redireciomanento de erro para null, pois falha se não instalado
    adb -s "$($connectedIP):$PORT" uninstall $PACKAGE_NAME 2>$null
    Write-Host "   (Desinstalação concluída ou app não existia)" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "📲 Instalando NOVA VERSÃO..." -ForegroundColor Yellow
    Write-Host "   Isso pode levar alguns segundos..." -ForegroundColor Gray
    
    adb -s "$($connectedIP):$PORT" install -r $APK_PATH
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host "   ✅ REINSTALAÇÃO CONCLUÍDA COM SUCESSO!" -ForegroundColor Green
        Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host ""
        Write-Host "🚀 Abra o app e verifique em Settings > Jellyfin Integration" -ForegroundColor White
        
        # Tenta abrir o app automaticamente
        Write-Host "   Tentando abrir o app..." -ForegroundColor Gray
        adb -s "$($connectedIP):$PORT" shell monkey -p $PACKAGE_NAME -c android.intent.category.LAUNCHER 1
    }
    else {
        Write-Host ""
        Write-Host "❌ Erro na instalação. Verifique se o APK existe em:" -ForegroundColor Red
        Write-Host "   $APK_PATH" -ForegroundColor White
    }
    
}
else {
    Write-Host "❌ Não foi possível conectar ao tablet." -ForegroundColor Red
    Write-Host "   Verifique se o IP está correto e a depuração USB/Sem fio ativada." -ForegroundColor Red
}
Write-Host ""
