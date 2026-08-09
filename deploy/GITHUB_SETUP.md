# GitHub Pages 배포 — 1회 설정

로컬 준비(커밋)는 완료되었습니다. **GitHub 로그인 후 push**만 하면 Actions가 자동 배포합니다.

---

## ① GitHub CLI 로그인 (최초 1회)

PowerShell에서:

```powershell
gh auth login
```

선택 가이드:
1. **GitHub.com**
2. **HTTPS**
3. **Login with a web browser** (브라우저 인증 추천)
4. 표시된 코드 입력 → GitHub에서 Authorize

---

## ② 저장소 생성 + push (한 번에)

프로젝트 폴더에서:

```powershell
cd "C:\mini game_01\dessert_merge"
git branch -M main
gh repo create dessert_merge --public --source=. --remote=origin --push
```

> 이미 GitHub에 `dessert_merge` 저장소가 있으면:
> ```powershell
> git branch -M main
> git remote add origin https://github.com/s73325475-cyber/dessert_merge.git
> git push -u origin main
> ```

---

## ③ GitHub Pages 활성화

1. https://github.com/s73325475-cyber/dessert_merge/settings/pages
2. **Build and deployment → Source: GitHub Actions** 선택
3. **Actions** 탭에서 `Deploy Web to GitHub Pages` 워크플로 실행 확인 (push 후 자동 시작)

---

## ④ 배포 확인 (2~5분 후)

| URL | 용도 |
|-----|------|
| https://s73325475-cyber.github.io/dessert_merge/ | 메인 |
| https://s73325475-cyber.github.io/dessert_merge/?mode=arcade | **블로그 링크** |

모바일에서 **탭하여 시작** → 아케이드 진입 확인.

---

## ⑤ 블로그 글 링크

```
https://s73325475-cyber.github.io/dessert_merge/?mode=arcade
```

`deploy/BLOG_POST_NAVER.txt` 에도 동일 URL 반영됨.

---

## 문제 해결

| 증상 | 해결 |
|------|------|
| 404 | Actions 배포 완료 대기 · Pages Source = GitHub Actions 확인 |
| Actions 실패 | Actions 탭에서 로그 확인 (Flutter 빌드 오류) |
| 흰 화면 | `--base-href="/dessert_merge/"` 확인 (워크플로에 포함됨) |
| push 거부 | `gh auth login` 후 재시도 |
