# Script para Limpar Instalação Anterior e Reinstalar Limpo
# Remove completamente o app e reinstala do zero

$TABLET_IP = "192.168.3.159"
$PORT = "5555"
$PACKAGE = "com.clickeatenda.clickchannel"
$APK_PATH = "build\app\outputs\flutter-apk\app-release.apk"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║     🗑️  LIMPEZA COMPLETA E REINSTALAÇÃO LIMPA           ║" -ForegroundColor Red
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Red
Write-Host ""
Write-Host "⚠️  ATENÇÃO: Isso vai remover TODOS os dados do app!" -ForegroundColor Yellow
Write-Host ""

# Verificar se APK existe
if (!(Test-Path $APK_PATH)) {
    Write-Host "❌ APK não encontrado!" -ForegroundColor Red
    Write-Host "   Execute primeiro: .\build_clean.ps1" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Passo 1: Conectar ao tablet
Write-Host "📱 [1/4] Conectando ao tablet..." -ForegroundColor Yellow
adb connect "$($TABLET_IP):$PORT" | Out-Null

$devices = adb devices | Select-String "$($TABLET_IP):$PORT"
if ($devices) {
    Write-Host "   ✅ Tablet conectado ($TABLET_IP)" -ForegroundColor Green
} else {
    Write-Host "   ❌ Não foi possível conectar ao tablet" -ForegroundColor Red
    Write-Host "   Verifique se o tablet está:" -ForegroundColor Yellow
    Write-Host "      • Ligado" -ForegroundColor White
    Write-Host "      • Na mesma rede Wi-Fi" -ForegroundColor White
    Write-Host "      • Com ADB habilitado" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host ""

# Passo 2: Desinstalar completamente (remove app + dados)
Write-Host "🗑️  [2/4] Removendo instalação anterior..." -ForegroundColor Yellow
$uninstallResult = adb -s "$($TABLET_IP):$PORT" uninstall $PACKAGE 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ App removido completamente (incluindo dados)" -ForegroundColor Green
    Write-Host "   ℹ️  Cache, preferências e playlists foram deletados" -ForegroundColor Gray
} else {
    if ($uninstallResult -match "not installed") {
        Write-Host "   ℹ️  App não estava instalado (ok)" -ForegroundColor Gray
    } else {
        Write-Host "   ⚠️  Erro ao desinstalar: $uninstallResult" -ForegroundColor Yellow
    }
}

Write-Host ""

# Passo 3: Limpar cache adicional (força limpeza do sistema)
Write-Host "🧹 [3/4] Limpando cache do sistema..." -ForegroundColor Yellow
adb -s "$($TABLET_IP):$PORT" shell "rm -rf /sdcard/Android/data/$PACKAGE" 2>&1 | Out-Null
adb -s "$($TABLET_IP):$PORT" shell "rm -rf /data/data/$PACKAGE" 2>&1 | Out-Null
Write-Host "   ✅ Cache do sistema limpo" -ForegroundColor Green

Write-Host ""

# Passo 4: Instalar versão limpa
Write-Host "📲 [4/4] Instalando versão LIMPA do app..." -ForegroundColor Yellow
Write-Host "   Aguarde..." -ForegroundColor Gray

$installResult = adb -s "$($TABLET_IP):$PORT" install $APK_PATH 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ App instalado com sucesso!" -ForegroundColor Green
} else {
    Write-Host "   ❌ Erro na instalação: $installResult" -ForegroundColor Red
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║        ✅ REINSTALAÇÃO LIMPA CONCLUÍDA!                  ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "📱 Tablet: $TABLET_IP" -ForegroundColor Cyan
Write-Host ""
Write-Host "✨ O que foi feito:" -ForegroundColor Yellow
Write-Host "   ✅ App anterior removido completamente" -ForegroundColor Green
Write-Host "   ✅ Todos os dados e cache limpos" -ForegroundColor Green
Write-Host "   ✅ Playlists antigas deletadas" -ForegroundColor Green
Write-Host "   ✅ App novo instalado do zero" -ForegroundColor Green
Write-Host ""
Write-Host "🎯 Próximo passo:" -ForegroundColor Cyan
Write-Host "   1. Abra o app no tablet" -ForegroundColor White
Write-Host "   2. Deve mostrar a SETUP SCREEN (sem playlist)" -ForegroundColor White
Write-Host "   3. Configure sua playlist atual" -ForegroundColor White
Write-Host ""
Write-Host "💡 Se ainda aparecer lista antiga:" -ForegroundColor Yellow
Write-Host "   O problema está no APK (build com cache)" -ForegroundColor White
Write-Host "   Execute: .\build_clean.ps1" -ForegroundColor White
Write-Host "   Depois: .\limpar_e_reinstalar.ps1" -ForegroundColor White
Write-Host ""
