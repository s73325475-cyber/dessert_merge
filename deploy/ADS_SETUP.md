# 실광고 연동 완전 가이드 (Google H5 Games Ads)

디저트 빌리어드 머지 웹판은 **Google AdSense H5 Games Ads** 보상형 광고를 사용합니다.  
코드·배포 파이프라인은 이미 연결되어 있습니다. **아래 Google 계정 작업 + GitHub Secret 설정**만 하면 됩니다.

---

## 한눈에 보는 순서

| 단계 | 누가 | 예상 시간 |
|------|------|-----------|
| ① AdSense 가입·사이트 등록 | **본인** | 1~3일 (심사) |
| ② H5 Games Ads 베타 신청 | **본인** | 수일~수주 (승인 대기) |
| ③ Publisher ID · ads.txt 확인 | **본인** | 10분 |
| ④ GitHub Secret 설정 | **본인** | 5분 |
| ⑤ 테스트 광고 확인 | **본인** | 10분 |
| ⑥ 실광고 전환 | **본인** | 5분 |
| ads.txt 자동 생성·배포 | **이미 구현됨** | Secret 설정 후 자동 |

**게임 URL:** https://s73325475-cyber.github.io/dessert_merge/?mode=arcade  
**ads.txt URL (배포 후):** https://s73325475-cyber.github.io/dessert_merge/ads.txt

---

## ① Google AdSense 가입 · 사이트 등록

### 1-1. AdSense 시작

1. https://www.google.com/adsense/ 접속 → Google 계정으로 시작
2. 국가·결제 정보 입력 (수익 지급용)

### 1-2. 사이트 추가

1. AdSense → **사이트(Sites)** → **+ 새 사이트**
2. 사이트 URL 입력:
   ```
   s73325475-cyber.github.io/dessert_merge
   ```
   또는 전체 URL:
   ```
   https://s73325475-cyber.github.io/dessert_merge/
   ```
3. **소유권 확인** 방법 선택 (AdSense가 안내하는 방법 중 하나):
   - **ads.txt** (아래 ③에서 자동 생성·배포됨 — Secret 설정 후 재배포)
   - 또는 **AdSense 코드**를 페이지 `<head>`에 삽입 (코드는 `google_adsense` 패키지가 빌드 시 자동 주입)

### 1-3. 심사 대기

- 상태가 **준비됨(Ready)** 이 될 때까지 대기 (보통 수 시간~수일)
- 게임·블로그 콘텐츠가 [AdSense 정책](https://support.google.com/adsense/answer/48182)에 맞는지 확인

---

## ② H5 Games Ads 베타 신청 (필수)

일반 AdSense만으로는 **게임 보상형 광고**가 안 될 수 있습니다. H5 Games Ads 베타 승인이 필요합니다.

### 신청 링크 (둘 중 하나)

- **AdSense 헬프센터:** https://adsense.google.com/start/h5-beta/?src=help-center  
- **Google 개발자 문서:** https://developers.google.com/ad-placement/docs/beta  

### 신청 시 입력 예시

| 항목 | 예시 |
|------|------|
| 게임 이름 | Dessert Billiards Merge / 디저트 빌리어드 머지 |
| URL | https://s73325475-cyber.github.io/dessert_merge/ |
| 플랫폼 | HTML5 / Flutter Web (WASM) |
| 광고 유형 | Rewarded (보상형), Interstitial (선택) |
| 설명 | 모바일 세로 물리 머지·빌리어드 웹게임. 게임 오버 시 광고 시청 후 발사 횟수 회복. |

승인 전에도 `AD_TEST_MODE=true` 로 **테스트 광고** UI를 확인할 수 있습니다 (Publisher ID 필요).

---

## ③ Publisher ID 확인

1. AdSense → **계정(Account)** → **설정 → 계정 정보**
2. **Publisher ID** 복사 (형식: `pub-1234567890123456` 또는 `ca-pub-1234567890123456`)

이 ID를 다음 단계 GitHub Secret에 넣습니다.

---

## ④ GitHub Secret · Variable 설정

### 4-1. Secret 페이지 열기

👉 https://github.com/s73325475-cyber/dessert_merge/settings/secrets/actions

또는 PowerShell에서 안내 스크립트 실행:

```powershell
cd "C:\mini game_01\dessert_merge"
.\deploy\configure-ads.ps1
```

### 4-2. 필수 Secret

| Name | Value 예시 | 설명 |
|------|------------|------|
| `AD_PUBLISHER_ID` | `ca-pub-1234567890123456` | AdSense Publisher ID |

**New repository secret** → Name / Value 입력 → Add secret

### 4-3. Variable (테스트 ↔ 실광고 전환)

👉 https://github.com/s73325475-cyber/dessert_merge/settings/variables/actions

| Name | Value | 시기 |
|------|-------|------|
| `AD_TEST_MODE` | `true` | 처음 연동·UI 확인 (테스트 광고) |
| `AD_TEST_MODE` | `false` | 테스트 완료 후 **실광고·수익** |

Variable이 없으면 Publisher ID 설정 시 기본 **`true`(테스트)** 로 빌드됩니다.

### 4-4. (선택) 네이버 앱 WebView용 AdMob

앱 내 WebView에서 AdMob 광고를 쓰려면 AdMob에서 보상형·전면 슬롯 생성 후:

| Secret Name | Value |
|-------------|-------|
| `ADMOB_REWARDED_SLOT` | `ca-app-pub-XXXX/YYYY` |
| `ADMOB_INTERSTITIAL_SLOT` | `ca-app-pub-XXXX/ZZZZ` |

---

## ⑤ 배포 (재실행)

Secret 설정 후 **Actions를 다시 실행**해야 반영됩니다.

1. https://github.com/s73325475-cyber/dessert_merge/actions  
2. **Deploy Web to GitHub Pages** 클릭  
3. **Run workflow** → Branch: `main` → Run  

또는 아무 커밋 push 시 자동 배포.

### 배포 시 자동 처리되는 것

- `--dart-define=AD_PUBLISHER_ID=…` 빌드에 주입  
- **`ads.txt` 자동 생성** → `build/web/ads.txt`  
  - 내용: `google.com, pub-XXXXXXXX, DIRECT, f08c47fec0942fa0`  
- AdSense H5 SDK 초기화 (`google_adsense` 패키지)

---

## ⑥ 테스트 광고 확인

1. `AD_PUBLISHER_ID` Secret 설정  
2. Variable `AD_TEST_MODE` = `true` (또는 미설정)  
3. Actions 배포 완료 후 **Chrome**에서:
   ```
   https://s73325475-cyber.github.io/dessert_merge/?mode=arcade&fresh=1
   ```
4. 게임 오버 → **「계속하기 (광고 · 🚀5 회복)」** 탭  
5. **테스트 광고**가 뜨고, 끝까지 보면 5발 회복되는지 확인  

### ads.txt 확인

브라우저에서 열기:

```
https://s73325475-cyber.github.io/dessert_merge/ads.txt
```

Publisher ID 한 줄이 보이면 OK. AdSense 사이트 화면에서 **확인됨**으로 바뀌는 데 시간이 걸릴 수 있습니다.

---

## ⑦ 실광고 전환

테스트가 정상이면:

1. GitHub Variable `AD_TEST_MODE` → **`false`** 로 변경  
2. Actions **Run workflow** 재실행  
3. Chrome에서 같은 방법으로 광고 재확인 (실광고·수익 집계 시작)

⚠️ **중간에 광고를 닫으면 보상 없음** — 정상 동작입니다.

---

## 게임 내 광고 위치

| 기능 | placement 이름 |
|------|----------------|
| 게임 오버 → 계속하기 | `dessert-reward` |
| 보스 보상 추가 | 동일 |
| 코인 획득 광고 | 동일 |

Publisher ID **없음** → 기존 stub (1.2초 대기 후 보상, 수익 없음)

---

## 문제 해결

| 증상 | 원인 · 해결 |
|------|-------------|
| 여전히 1.2초만 기다림 (stub) | `AD_PUBLISHER_ID` Secret 없음 → ④ 다시 |
| 테스트 광고도 안 뜸 | H5 베타 미승인 · AdSense 사이트 미준비 → ①② 대기 |
| ads.txt 404 | Secret 설정 후 **재배포** 안 함 → ⑤ Run workflow |
| AdSense 사이트 미확인 | ads.txt URL 접속 가능한지 확인 · 24시간 대기 |
| 보상 안 줌 | 광고 중간 종료 → 정상 |
| 네이버 앱 안 | Chrome에서 열기 (WebView 한계) |

---

## 참고 링크

- [H5 Games Ads 시작](https://support.google.com/adsense/answer/9959170)  
- [게임 페이지에 AdSense 코드 추가](https://support.google.com/adsense/answer/9955214)  
- [보상형 광고 정책](https://support.google.com/adsense/answer/10858940)  
- [Flutter google_adsense 패키지](https://pub.dev/packages/google_adsense)  

---

## 로컬에서 직접 빌드 (선택)

```powershell
cd "C:\mini game_01\dessert_merge"
flutter build web --release --wasm --base-href="/dessert_merge/" `
  --dart-define=AD_PUBLISHER_ID=ca-pub-XXXXXXXXXXXXXXXX `
  --dart-define=AD_TEST_MODE=true
```

`build/web/ads.txt` 를 수동으로 만들려면 `deploy/ads.txt.example` 참고.
