# 웹 빌드 (GitHub Pages · 네이버 블로그 링크용)
# 사용: .\deploy\build-web.ps1
#       .\deploy\build-web.ps1 -BaseHref "/"

param(
    [string]$BaseHref = "/dessert_merge/"
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host ">> flutter pub get"
flutter pub get

Write-Host ">> flutter build web --release --wasm --base-href=$BaseHref"
flutter build web --release --wasm --base-href=$BaseHref

Write-Host ">> SPA fallback (404.html)"
Copy-Item "build\web\index.html" "build\web\404.html" -Force

Write-Host ""
Write-Host "Done. Upload build\web\ to hosting."
Write-Host "Blog link: https://s73325475-cyber.github.io$($BaseHref.TrimEnd('/'))/?mode=arcade"
