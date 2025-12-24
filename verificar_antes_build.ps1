# Script de Verificação Pré-Build
# Verifica se tudo está correto antes de compilar o APK

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           🔍 VERIFICAÇÃO PRÉ-BUILD                       ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$allOk = $true

# Verificar Flutter
Write-Host "📱 Verificando Flutter..." -ForegroundColor Yellow
$flutterVersion = flutter --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ Flutter instalado e funcionando" -ForegroundColor Green
} else {
    Write-Host "   ❌ Flutter não encontrado ou com erro" -ForegroundColor Red
    $allOk = $false
}

# Verificar ADB
Write-Host ""
Write-Host "🔧 Verificando ADB..." -ForegroundColor Yellow
$adbVersion = adb version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ ADB instalado e funcionando" -ForegroundColor Green
} else {
    Write-Host "   ❌ ADB não encontrado" -ForegroundColor Red
    Write-Host "   ℹ️  Instale o Android Platform Tools" -ForegroundColor Gray
    $allOk = $false
}

# Verificar pubspec.yaml
Write-Host ""
Write-Host "📦 Verificando pubspec.yaml..." -ForegroundColor Yellow
if (Test-Path "pubspec.yaml") {
    Write-Host "   ✅ pubspec.yaml encontrado" -ForegroundColor Green
} else {
    Write-Host "   ❌ pubspec.yaml não encontrado" -ForegroundColor Red
    Write-Host "   ℹ️  Execute este script no diretório raiz do projeto" -ForegroundColor Gray
    $allOk = $false
}

# Verificar android/
Write-Host ""
Write-Host "🤖 Verificando diretório Android..." -ForegroundColor Yellow
if (Test-Path "android") {
    Write-Host "   ✅ Diretório android/ encontrado" -ForegroundColor Green
} else {
    Write-Host "   ❌ Diretório android/ não encontrado" -ForegroundColor Red
    $allOk = $false
}

# Verificar scripts de deploy
Write-Host ""
Write-Host "🚀 Verificando scripts de deploy..." -ForegroundColor Yellow
if (Test-Path "deploy.ps1") {
    Write-Host "   ✅ deploy.ps1 encontrado" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  deploy.ps1 não encontrado" -ForegroundColor Yellow
}

if (Test-Path "build_clean.ps1") {
    Write-Host "   ✅ build_clean.ps1 encontrado" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  build_clean.ps1 não encontrado" -ForegroundColor Yellow
}

# Verificar conectividade com dispositivos
Write-Host ""
Write-Host "📱 Verificando conectividade com dispositivos..." -ForegroundColor Yellow
Write-Host "   (Dispositivos devem estar na mesma rede e com ADB habilitado)" -ForegroundColor Gray

# Fire Stick
Write-Host "   • Fire Stick (192.168.3.110)..." -ForegroundColor White
$pingFirestick = Test-Connection -ComputerName 192.168.3.110 -Count 1 -Quiet -ErrorAction SilentlyContinue
if ($pingFirestick) {
    Write-Host "     ✅ Acessível na rede" -ForegroundColor Green
} else {
    Write-Host "     ⚠️  Não acessível (verifique se está ligado e na rede)" -ForegroundColor Yellow
}

# Tablet
Write-Host "   • Tablet (192.168.3.159)..." -ForegroundColor White
$pingTablet = Test-Connection -ComputerName 192.168.3.159 -Count 1 -Quiet -ErrorAction SilentlyContinue
if ($pingTablet) {
    Write-Host "     ✅ Acessível na rede" -ForegroundColor Green
} else {
    Write-Host "     ⚠️  Não acessível (verifique se está ligado e na rede)" -ForegroundColor Yellow
}

# Verificar se há cache antigo
Write-Host ""
Write-Host "🗑️  Verificando cache antigo..." -ForegroundColor Yellow
$hasCache = $false

if (Test-Path "android\.gradle") {
    Write-Host "   ⚠️  Cache do Gradle encontrado (será removido no build limpo)" -ForegroundColor Yellow
    $hasCache = $true
}

if (Test-Path "android\build") {
    Write-Host "   ⚠️  Build anterior encontrado (será removido no build limpo)" -ForegroundColor Yellow
    $hasCache = $true
}

if (Test-Path "build") {
    Write-Host "   ⚠️  Diretório build/ encontrado (será removido no build limpo)" -ForegroundColor Yellow
    $hasCache = $true
}

if (!$hasCache) {
    Write-Host "   ✅ Nenhum cache antigo detectado" -ForegroundColor Green
}

# Resumo final
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan

if ($allOk) {
    Write-Host ""
    Write-Host "✅ TUDO PRONTO PARA BUILD!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Execute agora:" -ForegroundColor Cyan
    Write-Host "   1. .\build_clean.ps1  (Build limpo)" -ForegroundColor White
    Write-Host "   2. .\deploy.ps1       (Deploy automático)" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "❌ PROBLEMAS DETECTADOS!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Corrija os itens marcados com ❌ antes de continuar." -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

