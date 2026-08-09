# GitHub 배포 — 브라우저에서 하는 방법 (추천)

`gh` CLI 없이 **GitHub 웹 + PowerShell git push** 만으로 배포합니다.  
브라우저에 이미 GitHub 로그인되어 있으면 Credential Manager 창만 뜨면 됩니다.

---

## ① GitHub 웹에서 저장소 만들기 (1분)

1. https://github.com/new 접속 (또는 왼쪽 **New** 버튼)
2. 아래처럼 입력:

| 항목 | 값 |
|------|-----|
| Repository name | **`dessert_merge`** |
| Public | ✅ 선택 |
| Add README | ❌ **체크 해제** |
| Add .gitignore | ❌ None |
| Choose a license | ❌ None |

3. **Create repository** 클릭

> ⚠️ README를 추가하면 push 충돌이 납니다. **빈 저장소**로 만드세요.

---

## ② PowerShell에서 코드 올리기

```powershell
cd "C:\mini game_01\dessert_merge"
.\deploy\push-to-github.ps1
```

- Git Credential Manager 창이 뜨면 **브라우저로 GitHub 로그인** → 허용
- `Push OK!` 가 나오면 성공

---

## ③ GitHub 웹에서 Pages 켜기 (1분)

1. https://github.com/s73325475-cyber/dessert_merge/settings/pages
2. **Build and deployment**
3. **Source → GitHub Actions** 선택

---

## ④ 배포 확인 (2~5분 후)

**Actions** 탭에서 `Deploy Web to GitHub Pages` ✅ 초록색 확인 후:

| URL | 용도 |
|-----|------|
| https://s73325475-cyber.github.io/dessert_merge/?mode=arcade | **블로그 링크** |
| https://s73325475-cyber.github.io/dessert_merge/ | 메인 메뉴 |

모바일: **탭하여 시작** → 아케이드

---

## 블로그 글 링크

```
https://s73325475-cyber.github.io/dessert_merge/?mode=arcade
```

---

## 자주 나는 문제

| 증상 | 해결 |
|------|------|
| `repository not found` | ①번 저장소를 먼저 만들었는지 확인 (이름 `dessert_merge`) |
| push 거부 / 로그인 | Credential Manager 창에서 GitHub 계정 허용 |
| 404 (배포 후) | Pages Source = **GitHub Actions** 인지 확인 |
| Actions 빨간색 | Actions 탭 → 워크플로 로그 확인 |

---

## (선택) gh CLI 쓰고 싶을 때

```powershell
gh auth login
# GitHub.com → HTTPS → Login with a web browser
```

그 후 `.\deploy\push-to-github.ps1` 재실행.
