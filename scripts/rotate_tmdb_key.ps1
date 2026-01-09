<#
Rotate TMDB API key helper.

Usage examples:

# Interactive prompt (will update local .env and set GitHub repo secret using gh CLI):
#   .\scripts\rotate_tmdb_key.ps1

# With key as parameter:
#   .\scripts\rotate_tmdb_key.ps1 -Key "NEW_TMDB_KEY"

# Requirements:
# - gh (GitHub CLI) logged in (run `gh auth login` first)
# - Run this script from the repository root or pass --Repo to gh commands.
#>
Param(
    [string]$Key
)

function Write-ErrAndExit($msg){
    Write-Host "ERROR: $msg" -ForegroundColor Red
    exit 1
}

if (-not $Key) {
    $Key = Read-Host -Prompt "Enter the NEW TMDB API KEY (will not be echoed)"
}

if (-not $Key) { Write-ErrAndExit "No key provided. Aborting." }

# Update local .env (create or replace TMDB_API_KEY line)
$envFile = Join-Path -Path (Get-Location) -ChildPath '.env'

if (Test-Path $envFile) {
    $content = Get-Content $envFile
    $updated = $false
    $out = @()
    foreach ($line in $content) {
        if ($line -match '^\s*TMDB_API_KEY\s*=') {
            $out += "TMDB_API_KEY=$Key"
            $updated = $true
        } else {
            $out += $line
        }
    }
    if (-not $updated) { $out += "TMDB_API_KEY=$Key" }
    $out -join "`n" | Set-Content $envFile -Encoding UTF8
    Write-Host "Updated local .env with TMDB_API_KEY"
} else {
    "TMDB_API_KEY=$Key" | Out-File -FilePath $envFile -Encoding UTF8
    Write-Host "Created local .env with TMDB_API_KEY"
}

# Set GitHub repo secret (requires gh CLI and authenticated user)
try {
    gh --version > $null 2>&1
} catch {
    Write-ErrAndExit "gh CLI not found. Install from https://cli.github.com/ and authenticate (gh auth login)."
}

Write-Host "Setting GitHub repository secret 'TMDB_API_KEY' using gh..."
try {
    gh secret set TMDB_API_KEY --body "$Key"
    Write-Host "GitHub repo secret 'TMDB_API_KEY' set (or updated)."
} catch {
    Write-ErrAndExit "Failed to set GitHub secret. Ensure you have repo access and gh is authenticated."
}

Write-Host "Done. Remember to rotate the key at TMDB (revoke old key) and update any deployed environments." -ForegroundColor Green
