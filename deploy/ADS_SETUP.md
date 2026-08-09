# 웹 정식 광고 연동 (Google H5 Games Ads)

디저트 빌리어드 머지 웹판은 **Google AdSense H5 Games Ads**(Ad Placement API)를 사용합니다.  
모바일 앱의 AdMob 보상형 광고와 같은 API 계열이며, Flutter 공식 패키지 `google_adsense`로 연동되어 있습니다.

---

## 1. 사전 준비 (Google 측)

1. [Google AdSense](https://www.google.com/adsense/) 계정 생성·사이트 등록  
   - 사이트 URL: `https://s73325475-cyber.github.io/dessert_merge/`
2. **H5 Games Ads 베타** 신청  
   - 패키지 안내: https://pub.dev/packages/google_adsense  
   - 승인 전에도 `AD_TEST_MODE=true` 로 **테스트 광고** 가능
3. Publisher ID 확인 (`ca-pub-XXXXXXXXXXXXXXXX`)

---

## 2. GitHub Pages 배포에 Publisher ID 넣기

### 방법 A — GitHub Secret (권장)

1. 저장소 → **Settings → Secrets and variables → Actions**
2. **New repository secret**
   - Name: `AD_PUBLISHER_ID`
   - Value: `ca-pub-XXXXXXXXXXXXXXXX`
3. (선택) Variable `AD_TEST_MODE` = `true` (테스트) / `false` (실광고)

워크플로가 빌드 시 자동으로 `--dart-define`에 전달합니다.

### 방법 B — 로컬 빌드

```powershell
flutter build web --release --wasm --base-href="/dessert_merge/" `
  --dart-define=AD_PUBLISHER_ID=ca-pub-XXXXXXXXXXXXXXXX `
  --dart-define=AD_TEST_MODE=true
```

---

## 3. Publisher ID 없을 때

`AD_PUBLISHER_ID`가 비어 있으면 **기존 stub**(1.2초 대기 후 보상)으로 동작합니다.  
개발·데모에는 그대로 사용 가능합니다.

---

## 4. 네이버 앱 WebView (선택)

앱 안 브라우저에서 AdMob 광고를 쓰려면 AdMob 보상형 슬롯 ID도 설정합니다.

| dart-define | 용도 |
|-------------|------|
| `ADMOB_REWARDED_SLOT` | WebView 보상형 |
| `ADMOB_INTERSTITIAL_SLOT` | WebView 전면 |

GitHub Secret 이름: `ADMOB_REWARDED_SLOT`, `ADMOB_INTERSTITIAL_SLOT`

---

## 5. 게임 내 광고 위치

| 기능 | API placement |
|------|----------------|
| 게임 오버 → 계속하기 | `dessert-reward` (보상형) |
| 보스 보상 추가 | 동일 |
| 코인 획득 광고 | 동일 |

보상은 **광고 시청 완료(`BreakStatus.viewed`)** 시에만 지급됩니다.

---

## 6. 정책·주의

- H5 Games Ads는 **웹 게임 전용**입니다.
- 보상형 광고 정책: https://support.google.com/adsense/answer/10858940
- 테스트 모드(`AD_TEST_MODE=true`)로 배포 URL에서 먼저 확인한 뒤 실광고로 전환하세요.

---

## 7. 문제 해결

| 증상 | 확인 |
|------|------|
| 광고 없이 stub만 | `AD_PUBLISHER_ID` Secret 설정 후 재배포 |
| 테스트 광고도 안 뜸 | H5 베타 미승인 → `adbreakTest=on` 확인 |
| 보상 안 줌 | 광고 중간에 닫음 → 정상 (보상 없음) |
| 네이버 앱 안 | Chrome에서 열기 권장 (WebView 한계) |
