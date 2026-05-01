param(
  [string]$ProjectName = "click-channel-app",
  [string]$Scope = "clickeatendas-projects",
  [string]$BackendUrl = "https://sass.clickeatende.com.br"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root ".env"
$backupFile = Join-Path $root ".env.codex-backup"
$webBuildDir = Join-Path $root "build\web"
$vercelConfigPath = Join-Path $webBuildDir "vercel.json"
$flutterBuildCacheDir = Join-Path $root ".dart_tool\flutter_build"

function Set-Or-AddEnvLine {
  param(
    [string[]]$Lines,
    [string]$Key,
    [string]$Value
  )

  $pattern = "^\s*$([regex]::Escape($Key))="
  $updated = $false

  $result = $Lines | ForEach-Object {
    if ($_ -match $pattern) {
      $updated = $true
      return "$Key=$Value"
    }
    return $_
  }

  if (-not $updated) {
    $result += "$Key=$Value"
  }

  return ,$result
}

function Restore-MainDartJsIfMissing {
  param(
    [string]$WebBuildDir,
    [string]$FlutterBuildCacheDir
  )

  $mainJsTarget = Join-Path $WebBuildDir "main.dart.js"
  if (Test-Path $mainJsTarget) {
    return
  }

  if (-not (Test-Path $FlutterBuildCacheDir)) {
    throw "main.dart.js não encontrado em $WebBuildDir e cache Flutter ausente em $FlutterBuildCacheDir"
  }

  $candidate = Get-ChildItem $FlutterBuildCacheDir -Directory |
    Sort-Object LastWriteTime -Descending |
    ForEach-Object {
      $file = Join-Path $_.FullName "main.dart.js"
      if (Test-Path $file) { Get-Item $file }
    } |
    Select-Object -First 1

  if (-not $candidate) {
    throw "main.dart.js não encontrado em $WebBuildDir nem no cache Flutter"
  }

  Copy-Item $candidate.FullName $mainJsTarget -Force
  Write-Host "Restaurado main.dart.js a partir de $($candidate.FullName)"
}

if (-not (Test-Path $envFile)) {
  throw "Arquivo .env não encontrado em $envFile"
}

Copy-Item $envFile $backupFile -Force

try {
  $lines = Get-Content $envFile
  $lines = Set-Or-AddEnvLine -Lines $lines -Key "BACKEND_URL" -Value $BackendUrl
  $lines = Set-Or-AddEnvLine -Lines $lines -Key "USE_CLICK_SAAS_AUTH" -Value "true"
  Set-Content -Path $envFile -Value $lines -Encoding UTF8

  Push-Location $root
  flutter build web --release --base-href /
  Pop-Location

  Restore-MainDartJsIfMissing -WebBuildDir $webBuildDir -FlutterBuildCacheDir $flutterBuildCacheDir

  $vercelConfig = @'
{
  "rewrites": [
    { "source": "/((?!.*\\.).*)", "destination": "/index.html" }
  ]
}
'@

  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($vercelConfigPath, $vercelConfig, $utf8NoBom)

  vercel link --yes --project $ProjectName --scope $Scope --cwd $webBuildDir | Out-Host
  vercel deploy $webBuildDir --prod --yes --scope $Scope | Out-Host
}
finally {
  if (Test-Path $backupFile) {
    Move-Item $backupFile $envFile -Force
  }
}
