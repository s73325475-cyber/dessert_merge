# 네이버 블로그 · 모바일 웹 배포 가이드

디저트 빌리어드 머지를 **네이버 블로그에서 링크로 공유**하기 위한 배포 절차입니다.  
네이버 블로그는 iframe 제한이 있어 **외부 호스팅 URL + 링크 버튼** 방식을 권장합니다.

---

## 1. 웹 빌드

프로젝트 루트에서:

```powershell
cd "C:\mini game_01\dessert_merge"
flutter pub get
flutter build web --release --base-href="/REPO_NAME/"
```

| 상황 | `--base-href` |
|------|----------------|
| GitHub Pages `username.github.io/REPO_NAME/` | `/REPO_NAME/` |
| 루트 도메인 `games.example.com/` | `/` |
| Netlify/Vercel 루트 배포 | `/` |

빌드 결과: `build/web/` 폴더

---

## 2. GitHub Pages 배포 (권장 · 무료)

### A. GitHub Actions (자동)

1. GitHub에 저장소 push
2. **Settings → Pages → Source: GitHub Actions** 선택
3. `main` 브랜치 push 시 `.github/workflows/deploy-web.yml` 이 자동 배포

배포 URL 예: `https://s73325475-cyber.github.io/dessert_merge/`

> **사전 논의:** GitHub 저장소 생성·push는 본인 계정 권한이 필요합니다.  
> Actions 워크플로 파일은 이미 포함되어 있습니다.

### B. 수동 업로드

`build/web/` 내용을 GitHub Pages 브랜치(`gh-pages`) 또는 Netlify에 드래그 앤 드롭.

GitHub Pages SPA 라우팅용: `build/web/index.html`을 `404.html`로 **복사**해 함께 업로드.

---

## 3. 네이버 블로그에 올리기

### 추천 링크 URL

| 용도 | URL |
|------|-----|
| **블로그 본문 버튼 (추천)** | `https://s73325475-cyber.github.io/dessert_merge/?mode=arcade` |
| 메인 메뉴 포함 | `https://s73325475-cyber.github.io/dessert_merge/` |
| 캠페인 모드 | `https://s73325475-cyber.github.io/dessert_merge/?mode=campaign` |

`?mode=arcade` → 탭하여 시작 → **아케이드 바로 진입** (모바일 방문자 UX 최적)

### 블로그 글 작성 예

1. 스마트에디터 ONE에서 **텍스트 + 이미지**로 게임 소개
2. **링크** 삽입:
   - 표시 텍스트: `🍰 지금 플레이하기`
   - URL: `https://s73325475-cyber.github.io/dessert_merge/?mode=arcade`
3. (선택) 캡처 GIF/스크린샷 1~2장 첨부

### HTML 버튼 (고급 — HTML 블록 지원 시)

```html
<p style="text-align:center;margin:24px 0;">
  <a href="https://s73325475-cyber.github.io/dessert_merge/?mode=arcade"
     target="_blank" rel="noopener"
     style="display:inline-block;padding:16px 32px;background:#f5b945;color:#2c1f43;
            font-weight:bold;border-radius:999px;text-decoration:none;font-size:18px;">
    🍰 디저트 머지 플레이하기
  </a>
</p>
<p style="text-align:center;color:#888;font-size:13px;">
  모바일 · 세로 화면 권장 · 새 창에서 열립니다
</p>
```

> 네이버 블로그 HTML 편집은 에디터/스킨에 따라 제한될 수 있습니다.  
> **링크 삽입**만으로도 충분합니다.

---

## 4. 모바일 UX (이미 적용됨)

| 기능 | 설명 |
|------|------|
| **탭하여 시작** | 브라우저 오디오 정책 + 로딩 체감 개선 |
| **세로 최적화** | PWA manifest `portrait-primary` |
| **조작 안내** | 웹 메인 메뉴에 드래그 조준 안내 |
| **뒤로가기** | 메뉴 종료 시 "블로그로 돌아가기" 문구 |
| **Android 업데이트 UI** | 웹에서 숨김 |

---

## 5. 배포 후 체크리스트

- [ ] 모바일 Chrome / Safari에서 `?mode=arcade` 링크 테스트
- [ ] 첫 화면 "탭하여 시작" → 게임 진입 확인
- [ ] 드래그 조준·발사 동작 확인
- [ ] BGM·효과음 재생 확인 (무음이면 기기 음량·무음 모드 확인)
- [ ] 블로그 글에서 링크 탭 → 새 탭/앱 내 브라우저로 열리는지 확인
- [ ] (선택) `web/index.html`의 `og:url`을 실제 배포 URL로 수정 후 재빌드

---

## 6. URL 파라미터

| 파라미터 | 동작 |
|----------|------|
| `?mode=arcade` | 아케이드 즉시 시작 |
| `?mode=campaign` | 캠페인(이어하기) |
| `?mode=menu` | 메인 메뉴 |
| `?gate=0` | 시작 게이트 생략 (테스트용) |

---

## 7. 대안 호스팅

| 서비스 | 특징 |
|--------|------|
| **GitHub Pages** | 무료, Actions 자동 배포 |
| **Netlify** | 드래그 앤 드롭, 커스텀 도메인 |
| **Cloudflare Pages** | 빠른 CDN |
| **Firebase Hosting** | Google 계정 연동 |

---

## 8. 아직 직접 해야 하는 것 (권한 필요 · skip)

- GitHub 저장소 생성 및 push
- GitHub Pages 활성화
- 네이버 블로그 글 작성·링크 삽입
- (선택) 커스텀 도메인 연결
- (선택) OG 미리보기용 썸네일 이미지 제작·업로드

코드·빌드·가이드는 준비되어 있으니, **호스팅 URL만 정하면** 블로그에 바로 연결할 수 있습니다.
