# GitHub setup helper — browser create repo (1 click) + auto push
# Run: .\deploy\setup-github.ps1

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$owner = "s73325475-cyber"
$repo = "dessert_merge"
$newRepoUrl = "https://github.com/new?name=$repo&visibility=public&description=Dessert+Billiards+Merge+web+game"
$repoUrl = "https://github.com/$owner/$repo"
$pagesUrl = "https://github.com/$owner/$repo/settings/pages"
$playUrl = "https://$owner.github.io/$repo/?mode=arcade"

Write-Host ""
Write-Host "=== GitHub setup (s73325475-cyber) ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: open pre-filled new repo page
Write-Host "[Step 1] Opening GitHub new repository page..."
Start-Process $newRepoUrl
Write-Host ""
Write-Host "Browser checklist (about 30 seconds):" -ForegroundColor Yellow
Write-Host "  - Repository name: dessert_merge (pre-filled)"
Write-Host "  - Public"
Write-Host "  - README / .gitignore / License: ALL OFF"
Write-Host "  - Click: Create repository"
Write-Host ""
Read-Host "Press Enter AFTER you clicked Create repository"

# Step 2: wait until repo exists
Write-Host ""
Write-Host "[Step 2] Checking repository..."
$ready = $false
for ($i = 1; $i -le 30; $i++) {
    try {
        $r = Invoke-WebRequest -Uri $repoUrl -UseBasicParsing -Method Head -TimeoutSec 10
        if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400) {
            $ready = $true
            break
        }
    } catch {
        Start-Sleep -Seconds 2
    }
}
if (-not $ready) {
    Write-Host "Repository not found yet: $repoUrl" -ForegroundColor Red
    Write-Host "Please create the repo in browser, then run: .\deploy\push-to-github.ps1"
    exit 1
}
Write-Host "Repository found." -ForegroundColor Green

# Step 3: push
Write-Host ""
Write-Host "[Step 3] Pushing code (GitHub login window may appear)..."
& (Join-Path $PSScriptRoot "push-to-github.ps1")
if ($LASTEXITCODE -ne 0) { exit 1 }

# Step 4: open Pages settings
Write-Host ""
Write-Host "[Step 4] Opening GitHub Pages settings..."
Start-Process $pagesUrl
Write-Host ""
Write-Host "Pages checklist:" -ForegroundColor Yellow
Write-Host "  - Build and deployment -> Source: GitHub Actions"
Write-Host "  - Wait 2-5 minutes on Actions tab"
Write-Host ""
Write-Host "Play URL (after deploy):" -ForegroundColor Green
Write-Host "  $playUrl"
Write-Host ""
