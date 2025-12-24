# Hot Reload para dispositivos conectados
$env:Path += ";C:\Users\joaov\AppData\Local\Android\Sdk\platform-tools"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          🔥 HOT RELOAD - ATUALIZACAO RAPIDA              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "📱 Dispositivos conectados:" -ForegroundColor Yellow
adb devices
Write-Host ""

Write-Host "🔨 Compilando e enviando atualizacao..." -ForegroundColor Yellow
Write-Host ""

# Build e instala automaticamente nos dispositivos conectados
flutter run --release

Write-Host ""
Write-Host "✅ Atualização concluída!" -ForegroundColor Green
Write-Host ""

