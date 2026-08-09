import 'dart:async';

import 'package:flutter/material.dart';

import '../game/merge_game.dart';
import '../game/stage.dart';
import 'app_ui.dart';

/// 스테이지 전환 — 미션 룰렛 + Clear Mission 안내
class MissionIntroBanner extends StatefulWidget {
  const MissionIntroBanner({super.key, required this.game});
  final MergeGame game;

  @override
  State<MissionIntroBanner> createState() => _MissionIntroBannerState();
}

class _MissionIntroBannerState extends State<MissionIntroBanner> {
  StageIntroInfo? _info;
  double _opacity = 0;
  int _lastId = -1;
  bool _skipped = false;

  /// 0=type reel, 1=order reels / score count, 2=final text
  int _phase = 0;
  String? _typeDisplay;
  String? _dessertDisplay;
  String? _countDisplay;
  int _scoreDisplay = 0;
  Timer? _fadeTimer;

  @override
  void initState() {
    super.initState();
    widget.game.stageIntro.addListener(_onIntro);
  }

  void _onIntro() {
    final info = widget.game.stageIntro.value;
    if (info == null || info.id == _lastId) return;
    _lastId = info.id;
    _fadeTimer?.cancel();
    setState(() {
      _info = info;
      _opacity = 1;
      _skipped = false;
      _phase = 0;
      _typeDisplay = null;
      _dessertDisplay = null;
      _countDisplay = null;
      _scoreDisplay = 0;
    });
    _runSequence(info);
  }

  Future<void> _runSequence(StageIntroInfo info) async {
    final roll = info.roll;
    if (roll.kind == MissionIntroKind.boss) {
      _finishSequence(info, delayMs: 2600);
      return;
    }

    await _spinTypeReel(roll);
    if (!mounted || _skipped || _lastId != info.id) return;

    if (roll.kind == MissionIntroKind.order) {
      setState(() => _phase = 1);
      await _spinDessertReel(roll);
      if (!mounted || _skipped || _lastId != info.id) return;
      await _spinCountReel(roll);
    } else {
      setState(() => _phase = 1);
      await _countUpScore(roll.scoreTarget ?? 0);
    }

    if (!mounted || _skipped || _lastId != info.id) return;
    _finishSequence(info, delayMs: 1800);
  }

  Future<void> _spinTypeReel(MissionRoll roll) async {
    const pool = MissionRoll.typeSymbols;
    final result = pool[roll.typeResultIndex];
    for (var i = 0; i < 8; i++) {
      if (_skipped) break;
      setState(() => _typeDisplay = pool[i % pool.length]);
      await Future<void>.delayed(Duration(milliseconds: 70 + i * 12));
    }
    if (!_skipped) setState(() => _typeDisplay = result);
    await Future<void>.delayed(const Duration(milliseconds: 320));
  }

  Future<void> _spinDessertReel(MissionRoll roll) async {
    final pool = roll.reelTierPool ?? [1];
    final resultTier = roll.resultTier ?? pool.first;
    for (var i = 0; i < 7; i++) {
      if (_skipped) break;
      final t = pool[i % pool.length];
      setState(() => _dessertDisplay = MergeGame.skinEmoji(t));
      await Future<void>.delayed(Duration(milliseconds: 75 + i * 14));
    }
    if (!_skipped) {
      setState(() => _dessertDisplay = MergeGame.skinEmoji(resultTier));
    }
    await Future<void>.delayed(const Duration(milliseconds: 280));
  }

  Future<void> _spinCountReel(MissionRoll roll) async {
    final pool = roll.countPool ?? [2, 3];
    final result = roll.resultCount ?? pool.first;
    for (var i = 0; i < 7; i++) {
      if (_skipped) break;
      setState(() => _countDisplay = '×${pool[i % pool.length]}');
      await Future<void>.delayed(Duration(milliseconds: 75 + i * 14));
    }
    if (!_skipped) setState(() => _countDisplay = '×$result');
    await Future<void>.delayed(const Duration(milliseconds: 280));
  }

  Future<void> _countUpScore(int target) async {
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      if (_skipped) break;
      setState(() => _scoreDisplay = (target * i / steps).round());
      await Future<void>.delayed(const Duration(milliseconds: 55));
    }
    if (!_skipped) setState(() => _scoreDisplay = target);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  void _finishSequence(StageIntroInfo info, {required int delayMs}) {
    if (!mounted) return;
    setState(() => _phase = 2);
    _fadeTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted && _lastId == info.id) {
        setState(() => _opacity = 0);
        widget.game.onStageIntroDismissed();
      }
    });
  }

  void _skip() {
    if (_info == null || _opacity <= 0) return;
    _skipped = true;
    final info = _info!;
    final roll = info.roll;
    setState(() {
      _phase = 2;
      if (roll.kind != MissionIntroKind.boss) {
        _typeDisplay = MissionRoll.typeSymbols[roll.typeResultIndex];
        if (roll.kind == MissionIntroKind.order) {
          _dessertDisplay =
              MergeGame.skinEmoji(roll.resultTier ?? 1);
          _countDisplay = '×${roll.resultCount ?? 2}';
        } else {
          _scoreDisplay = roll.scoreTarget ?? 0;
        }
      }
    });
    _fadeTimer?.cancel();
    _fadeTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted && _lastId == info.id) {
        setState(() => _opacity = 0);
        widget.game.onStageIntroDismissed();
      }
    });
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    widget.game.stageIntro.removeListener(_onIntro);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_info == null) return const SizedBox.shrink();
    final info = _info!;
    final roll = info.roll;
    final showReels = roll.kind != MissionIntroKind.boss && _phase < 2;

    return Align(
      alignment: const Alignment(0, -0.72),
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 350),
        child: GestureDetector(
          onTap: _skip,
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: AppUi.hudPanel(radius: 18).copyWith(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'STAGE ${info.stage}',
                  style: AppUi.modalTitle.copyWith(
                    fontSize: 32,
                    color: Colors.amberAccent,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Clear Mission',
                  style: AppUi.dim.copyWith(
                    fontSize: 12,
                    color: Colors.white54,
                    letterSpacing: 0.6,
                  ),
                ),
                if (roll.kind == MissionIntroKind.boss) ...[
                  const SizedBox(height: 8),
                  Text(
                    info.missionHint,
                    style: AppUi.mission.copyWith(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  if (info.missionProgress.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      info.missionProgress,
                      style: AppUi.dim.copyWith(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ] else if (showReels) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ReelSlot(
                        label: '미션',
                        display: _typeDisplay ?? '?',
                        active: _typeDisplay != null,
                        fontSize: 28,
                      ),
                      if (roll.kind == MissionIntroKind.order &&
                          _phase >= 1 &&
                          _typeDisplay ==
                              MissionRoll.typeSymbols[1]) ...[
                        const SizedBox(width: 10),
                        _ReelSlot(
                          label: '디저트',
                          display: _dessertDisplay ?? '?',
                          active: _dessertDisplay != null,
                          fontSize: 32,
                        ),
                        const SizedBox(width: 10),
                        _ReelSlot(
                          label: '개수',
                          display: _countDisplay ?? '?',
                          active: _countDisplay != null,
                          fontSize: 26,
                          textStyle: AppUi.modalTitle.copyWith(
                            fontSize: 26,
                            color: Colors.white,
                          ),
                        ),
                      ],
                      if (roll.kind == MissionIntroKind.score &&
                          _phase >= 1 &&
                          _typeDisplay ==
                              MissionRoll.typeSymbols[0]) ...[
                        const SizedBox(width: 10),
                        _ReelSlot(
                          label: '목표',
                          display: '$_scoreDisplay',
                          active: _scoreDisplay > 0,
                          fontSize: 26,
                          textStyle: AppUi.modalTitle.copyWith(
                            fontSize: 26,
                            color: const Color(0xff9ad0ec),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '탭하여 스킵',
                    style: AppUi.dim.copyWith(
                      fontSize: 11,
                      color: Colors.white38,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  if (info.missionHint.isNotEmpty)
                    Text(
                      info.missionHint,
                      style: AppUi.mission.copyWith(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  if (info.missionProgress.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      info.missionProgress,
                      style: AppUi.dim.copyWith(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReelSlot extends StatelessWidget {
  const _ReelSlot({
    required this.label,
    required this.display,
    required this.active,
    required this.fontSize,
    this.textStyle,
  });

  final String label;
  final String display;
  final bool active;
  final double fontSize;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppUi.dim.copyWith(fontSize: 10, color: Colors.white38),
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? const Color(0xffffe082).withValues(alpha: 0.7)
                  : Colors.white24,
              width: active ? 2 : 1,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 80),
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
            child: Text(
              display,
              key: ValueKey(display),
              style: textStyle ??
                  TextStyle(fontSize: fontSize, height: 1.0),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
