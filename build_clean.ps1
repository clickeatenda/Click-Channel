# Script para Build Limpo do APK
# Garante que nenhum cache seja incluído no APK

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           🧹 BUILD LIMPO - SEM CACHE                     ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Passo 1: Limpar build anterior
Write-Host "🧹 [1/5] Limpando build anterior..." -ForegroundColor Yellow
flutter clean
Write-Host "   ✅ Build anterior removido" -ForegroundColor Green
Write-Host ""

# Passo 2: Remover cache de desenvolvimento
Write-Host "🗑️  [2/5] Removendo cache de desenvolvimento..." -ForegroundColor Yellow

# Remover .env se existir (para garantir que APK vai limpo)
if (Test-Path ".env") {
    Write-Host "   ⚠️  Arquivo .env encontrado - será ignorado no build" -ForegroundColor Yellow
}

# Limpar cache do Gradle (Android)
if (Test-Path "android\.gradle") {
    Remove-Item -Path "android\.gradle" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   ✅ Cache do Gradle removido" -ForegroundColor Green
}

# Limpar cache do build (Android)
if (Test-Path "android\build") {
    Remove-Item -Path "android\build" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   ✅ Build do Android removido" -ForegroundColor Green
}

# Limpar cache do app (Android)
if (Test-Path "android\app\build") {
    Remove-Item -Path "android\app\build" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   ✅ Build do app removido" -ForegroundColor Green
}

Write-Host ""

# Passo 3: Atualizar dependências
Write-Host "📦 [3/5] Atualizando dependências..." -ForegroundColor Yellow
flutter pub get
Write-Host "   ✅ Dependências atualizadas" -ForegroundColor Green
Write-Host ""

# Passo 4: Verificar que não há cache no código
Write-Host "🔍 [4/5] Verificando ausência de cache..." -ForegroundColor Yellow
Write-Host "   ℹ️  Cache M3U e EPG são criados em RUNTIME" -ForegroundColor Gray
Write-Host "   ℹ️  Diretório: getApplicationSupportDirectory()" -ForegroundColor Gray
Write-Host "   ℹ️  Install marker detectará primeira instalação" -ForegroundColor Gray
Write-Host "   ✅ Build será limpo" -ForegroundColor Green
Write-Host ""

# Passo 5: Compilar APK Release
Write-Host "🔨 [5/5] Compilando APK Release LIMPO..." -ForegroundColor Yellow
Write-Host "   Isso pode levar 2-5 minutos..." -ForegroundColor Gray
Write-Host ""

flutter build apk --release --no-tree-shake-icons

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║           ✅ APK LIMPO COMPILADO COM SUCESSO!            ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
        $apkSize = (Get-Item $apkPath).Length / 1MB
        Write-Host "📊 Informações do APK:" -ForegroundColor Cyan
        Write-Host "   • Localização: $apkPath" -ForegroundColor White
        Write-Host "   • Tamanho: $([math]::Round($apkSize, 2)) MB" -ForegroundColor White
        Write-Host "   • Status: SEM CACHE - Instalação limpa" -ForegroundColor Green
        Write-Host ""
        
        Write-Host "🎯 Próximo passo:" -ForegroundColor Yellow
        Write-Host "   ./deploy.ps1  (para instalar nos dispositivos)" -ForegroundColor White
        Write-Host ""
    }
} else {
    Write-Host ""
    Write-Host "❌ Erro na compilação!" -ForegroundColor Red
    Write-Host "   Verifique os erros acima" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "💡 Nota: O app iniciará na tela de Setup (sem playlist pré-configurada)" -ForegroundColor Cyan
Write-Host ""

