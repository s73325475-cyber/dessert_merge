import 'package:flutter/foundation.dart';

/// 블로그·모바일 링크 진입용 URL 파라미터.
///
/// 예) `?mode=arcade` — 아케이드 바로 시작 (네이버 블로그 추천 링크)
///     `?mode=campaign` — 캠페인 이어하기/새 시작
///     `?mode=menu` — 메인 메뉴
enum WebLaunchTarget {
  menu,
  arcade,
  campaign,
}

abstract final class WebLaunchConfig {
  static const String blogArcadeQuery = '?mode=arcade';

  static WebLaunchTarget parseTarget([Uri? uri]) {
    if (!kIsWeb) return WebLaunchTarget.menu;
    final u = uri ?? Uri.base;
    final mode = (u.queryParameters['mode'] ??
            u.queryParameters['play'] ??
            u.queryParameters['start'] ??
            '')
        .toLowerCase()
        .trim();
    return switch (mode) {
      'arcade' || 'a' || 'play' => WebLaunchTarget.arcade,
      'campaign' || 'c' || 'stage' => WebLaunchTarget.campaign,
      'menu' || 'home' => WebLaunchTarget.menu,
      _ => WebLaunchTarget.menu,
    };
  }

  static bool get needsPlayGate {
    if (!kIsWeb) return false;
    return Uri.base.queryParameters['gate'] != '0';
  }

  /// 블로그·공유 링크 등 — 저장된 판을 이어하지 않고 새 게임
  static bool get shouldStartFresh {
    if (!kIsWeb) return false;
    final u = Uri.base;
    final fresh = (u.queryParameters['fresh'] ?? u.queryParameters['new'] ?? '')
        .toLowerCase();
    if (fresh == '1' || fresh == 'true' || fresh == 'yes') return true;
    final from = (u.queryParameters['from'] ?? '').toLowerCase();
    if (from == 'blog' || from == 'naver') return true;
    return false;
  }

  /// URL로 명시적 이어하기 (`?mode=arcade&resume=1`)
  static bool get shouldResumeSaved {
    if (!kIsWeb) return false;
    final resume = (Uri.base.queryParameters['resume'] ?? '').toLowerCase();
    return resume == '1' || resume == 'true' || resume == 'yes';
  }

  static bool get isDirectPlay =>
      kIsWeb && parseTarget() != WebLaunchTarget.menu;
}
