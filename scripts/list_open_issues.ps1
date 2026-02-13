#!/usr/bin/env pwsh
# Script to list open issues and check their implementation status

Write-Host "Fetching open issues..." -ForegroundColor Cyan

$issues = gh issue list --state open --limit 60 --json number,title,labels | ConvertFrom-Json

Write-Host "`n=== OPEN ISSUES ($($issues.Count)) ===" -ForegroundColor Yellow

foreach ($issue in $issues | Sort-Object -Property number) {
    $priority = ($issue.labels | Where-Object { $_.name -like "*Média*" -or $_.name -like "*Alta*" -or $_.name -like "*Crítica*" }).name
    if (-not $priority) { $priority = "Sem prioridade" }
    
    Write-Host "#$($issue.number) - $($issue.title)" -ForegroundColor Green
    Write-Host "  Priority: $priority" -ForegroundColor Gray
}

Write-Host "`n=== Suggestions for closing ===" -ForegroundColor Cyan
Write-Host "Review ISSUES.md to identify which are marked as RESOLVIDO" -ForegroundColor White
