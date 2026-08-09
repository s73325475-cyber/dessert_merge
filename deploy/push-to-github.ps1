# GitHub Pages 배포 스크립트 (s73325475-cyber)
# 사용: PowerShell에서 .\deploy\push-to-github.ps1

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host ">> GitHub 로그인 확인..."
$auth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "GitHub 로그인이 필요합니다. 브라우저 창이 열립니다."
    gh auth login -h github.com -p https -w
}

Write-Host ">> 브랜치 main 확인..."
git branch -M main

Write-Host ">> 원격 저장소 생성 및 push..."
$remote = git remote get-url origin 2>$null
if (-not $remote) {
    gh repo create dessert_merge --public --source=. --remote=origin --push
} else {
    git push -u origin main
}

Write-Host ""
Write-Host "완료! 다음 단계:"
Write-Host "1. https://github.com/s73325475-cyber/dessert_merge/settings/pages"
Write-Host "   → Source: GitHub Actions 선택"
Write-Host "2. 2~5분 후 확인:"
Write-Host "   https://s73325475-cyber.github.io/dessert_merge/?mode=arcade"
