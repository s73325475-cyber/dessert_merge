# Dessert Billiards Merge

물리 기반 디저트 빌리어드 머지 게임 (Flutter + Flame + Forge2D)

## 플랫폼

- Android
- Web (블로그·모바일 링크 배포)
- Windows

## 로컬 실행

```powershell
flutter pub get
flutter run -d chrome          # 웹
flutter run                    # 연결된 기기
```

## 웹 빌드 (블로그 배포)

```powershell
flutter build web --release --base-href="/REPO_NAME/"
```

네이버 블로그 배포 절차: **[deploy/BLOG_DEPLOY.md](deploy/BLOG_DEPLOY.md)**

### 블로그 추천 링크

```
https://s73325475-cyber.github.io/dessert_merge/?mode=arcade
```

## URL 파라미터 (웹)

| 파라미터 | 설명 |
|----------|------|
| `?mode=arcade` | 아케이드 바로 시작 |
| `?mode=campaign` | 캠페인 모드 |
| `?mode=menu` | 메인 메뉴 |
