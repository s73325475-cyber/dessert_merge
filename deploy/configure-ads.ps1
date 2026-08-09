# AdSense 실광고 설정 — GitHub Secret 안내 + 관련 페이지 열기
# 사용: .\deploy\configure-ads.ps1

$ErrorActionPreference = "Stop"
$repo = "s73325475-cyber/dessert_merge"
$gameUrl = "https://s73325475-cyber.github.io/dessert_merge/?mode=arcade&fresh=1"
$adsTxtUrl = "https://s73325475-cyber.github.io/dessert_merge/ads.txt"

Write-Host ""
Write-Host "=== Dessert Merge — 실광고(AdSense H5) 설정 안내 ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1] Google AdSense 가입 · 사이트 등록" -ForegroundColor Yellow
Write-Host "    사이트 URL: s73325475-cyber.github.io/dessert_merge"
Write-Host ""

Write-Host "[2] H5 Games Ads 베타 신청 (필수)" -ForegroundColor Yellow
Write-Host "    https://adsense.google.com/start/h5-beta/"
Write-Host ""

Write-Host "[3] Publisher ID 확인 (AdSense > 계정 > 계정 정보)" -ForegroundColor Yellow
Write-Host "    형식: ca-pub-1234567890123456"
Write-Host ""

Write-Host "[4] GitHub Secret 등록" -ForegroundColor Yellow
Write-Host "    Name:  AD_PUBLISHER_ID"
Write-Host "    Value: (위 Publisher ID)"
Write-Host "    URL:   https://github.com/$repo/settings/secrets/actions"
Write-Host ""

Write-Host "[5] GitHub Variable (테스트/실광고)" -ForegroundColor Yellow
Write-Host "    Name: AD_TEST_MODE"
Write-Host "    Value: true  (처음) -> false (실광고 전환)"
Write-Host "    URL:   https://github.com/$repo/settings/variables/actions"
Write-Host ""

Write-Host "[6] Actions 재배포" -ForegroundColor Yellow
Write-Host "    https://github.com/$repo/actions"
Write-Host "    -> Deploy Web to GitHub Pages -> Run workflow"
Write-Host ""

Write-Host "[7] 확인" -ForegroundColor Yellow
Write-Host "    게임:   $gameUrl"
Write-Host "    ads.txt: $adsTxtUrl"
Write-Host ""

Write-Host "자세한 가이드: deploy\ADS_SETUP.md" -ForegroundColor Green
Write-Host ""

$open = Read-Host "관련 페이지를 브라우저에서 열까요? (y/N)"
if ($open -eq "y" -or $open -eq "Y") {
  Start-Process "https://www.google.com/adsense/"
  Start-Sleep -Milliseconds 800
  Start-Process "https://adsense.google.com/start/h5-beta/"
  Start-Sleep -Milliseconds 800
  Start-Process "https://github.com/$repo/settings/secrets/actions"
  Start-Sleep -Milliseconds 800
  Start-Process "https://github.com/$repo/actions"
}

Write-Host "완료." -ForegroundColor Cyan
