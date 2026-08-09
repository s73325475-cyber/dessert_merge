import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 디저트 머지 공통 UI 스타일 (귀엽고 깔끔한 Jua + Gowun Dodum)
abstract final class AppUi {
  static TextStyle get display => GoogleFonts.jua(
        color: Colors.white,
        fontSize: 28,
        height: 1.1,
        shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
      );

  static TextStyle get title => GoogleFonts.jua(
        color: Colors.white,
        fontSize: 22,
        height: 1.15,
      );

  static TextStyle get body => GoogleFonts.gowunDodum(
        color: Colors.white,
        fontSize: 16,
        height: 1.25,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get label => GoogleFonts.gowunDodum(
        color: Colors.white60,
        fontSize: 13,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get dim => GoogleFonts.gowunDodum(
        color: Colors.white70,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get coin => GoogleFonts.jua(
        color: Colors.amberAccent,
        fontSize: 17,
        height: 1.1,
      );

  static TextStyle get mission => GoogleFonts.jua(
        color: const Color(0xffffe082),
        fontSize: 15,
        height: 1.15,
      );

  static TextStyle get badge => GoogleFonts.jua(
        color: Colors.white,
        fontSize: 13,
        height: 1,
      );

  static TextStyle get emojiLarge => const TextStyle(fontSize: 38, height: 1);

  static TextStyle get emojiBtn => const TextStyle(fontSize: 26, height: 1);

  static TextStyle get toast => GoogleFonts.jua(
        fontSize: 34,
        fontWeight: FontWeight.w400,
        height: 1.15,
        shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
      );

  static TextStyle get modalTitle => GoogleFonts.jua(
        color: Colors.white,
        fontSize: 28,
        height: 1.1,
      );

  static TextStyle get modalBody => GoogleFonts.gowunDodum(
        color: Colors.white,
        fontSize: 15,
        height: 1.3,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get section => GoogleFonts.jua(
        color: Colors.white70,
        fontSize: 17,
        height: 1.2,
      );

  static TextStyle get button => GoogleFonts.jua(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.1,
      );

  /// HUD 숫자용
  static TextStyle score({Color color = Colors.white}) =>
      GoogleFonts.jua(color: color, fontSize: 30, height: 1.05);

  /// HUD 상단 패널 (오버플로우 방지용 축소)
  static TextStyle hudScore({Color color = Colors.white}) =>
      GoogleFonts.jua(color: color, fontSize: 24, height: 1.0);

  static TextStyle hudSub({Color color = Colors.white70}) =>
      GoogleFonts.gowunDodum(
          color: color, fontSize: 12, height: 1.1, fontWeight: FontWeight.w600);

  static TextStyle hudCoin({Color color = Colors.amberAccent}) =>
      GoogleFonts.jua(color: color, fontSize: 13, height: 1.0);

  static TextStyle get emojiHud => const TextStyle(fontSize: 30, height: 1.0);

  static BoxDecoration hudPanel({double radius = 14}) => BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      );

  static const double hudMinHeight = 68;
  static const double hudGap = 4;
  static const double toolbarBtnSize = 56;
  static const double toolbarEmojiSize = 26;

  /// 우측 툴바 — 평소 유령(ghost) 스타일, 터치 시만 진하게
  static const double toolbarIdleFill = 0.10;
  static const double toolbarActiveFill = 0.52;
  static const double toolbarIdleBorder = 0.38;
  static const double toolbarActiveBorder = 0.85;
  static const double toolbarIdleEmoji = 0.62;
  static const double toolbarActiveEmoji = 1.0;
}
