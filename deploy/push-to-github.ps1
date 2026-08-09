# GitHub Pages push (browser login OK — no gh CLI required)
# Step 1: Create repo on https://github.com/new  (name: dessert_merge, Public, empty)
# Step 2: Run: .\deploy\push-to-github.ps1

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$owner = "s73325475-cyber"
$repo = "dessert_merge"
$remoteUrl = "https://github.com/$owner/$repo.git"

Write-Host ""
Write-Host "=== Dessert Merge -> GitHub Pages ===" -ForegroundColor Cyan
Write-Host ""

# gh auth status writes to stderr; do not use Stop here
$ghAuthed = $false
try {
    $null = gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) { $ghAuthed = $true }
} catch {
    $ghAuthed = $false
}

Write-Host "[1/3] Branch: main"
git branch -M main

Write-Host "[2/3] Remote: $remoteUrl"
$existing = git remote get-url origin 2>$null
if ($LASTEXITCODE -ne 0) {
    git remote add origin $remoteUrl
} elseif ($existing -ne $remoteUrl) {
    git remote set-url origin $remoteUrl
}

Write-Host "[3/3] Push (browser login may open)..."
Write-Host ""
Write-Host "If repo does not exist yet, create it first:" -ForegroundColor Yellow
Write-Host "  https://github.com/new" -ForegroundColor Yellow
Write-Host "  Name: dessert_merge | Public | README/license OFF" -ForegroundColor Yellow
Write-Host ""

git push -u origin main
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Push failed. Common fixes:" -ForegroundColor Red
    Write-Host "  1. Create empty repo at https://github.com/new (name: dessert_merge)"
    Write-Host "  2. Sign in when Git Credential Manager opens"
    Write-Host "  3. Run this script again"
    exit 1
}

Write-Host ""
Write-Host "Push OK!" -ForegroundColor Green
Write-Host ""
Write-Host "Next (GitHub website):" -ForegroundColor Cyan
Write-Host "  1. https://github.com/$owner/$repo/settings/pages"
Write-Host "     -> Build and deployment -> Source: GitHub Actions"
Write-Host "  2. Wait 2-5 min, then open:"
Write-Host "     https://$owner.github.io/$repo/?mode=arcade"
Write-Host ""
