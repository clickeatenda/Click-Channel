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
