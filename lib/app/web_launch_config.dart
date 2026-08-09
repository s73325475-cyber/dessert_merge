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

  static bool get isDirectPlay =>
      kIsWeb && parseTarget() != WebLaunchTarget.menu;
}
