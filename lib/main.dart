import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/ad_config.dart';
import 'app/app_release_config.dart';
import 'app/web_launch_config.dart';
import 'game/ads.dart';
import 'game/audio.dart';
import 'game/config.dart';
import 'game/game_run_mode.dart';
import 'game/merge_game.dart';
import 'game/store.dart';
import 'ui/app_ui.dart';
import 'ui/mission_intro_banner.dart';
import 'ui/stage_select_picker.dart';
import 'ui/main_menu_screen.dart';
import 'ui/web_mobile_shell.dart';
import 'ui/web_play_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initAds();
  }
  final prefs = await SharedPreferences.getInstance();
  final store = Store(prefs);
  runApp(DessertMergeApp(store: store, audio: AudioManager(store)));
}

class DessertMergeApp extends StatefulWidget {
  const DessertMergeApp({super.key, required this.store, required this.audio});
  final Store store;
  final AudioManager audio;

  @override
  State<DessertMergeApp> createState() => _DessertMergeAppState();
}

class _DessertMergeAppState extends State<DessertMergeApp> {
  final _navKey = GlobalKey<NavigatorState>();
  MergeGame? _sessionGame;
  bool _webGatePassed = !kIsWeb || !WebLaunchConfig.needsPlayGate;
  bool _webAutoLaunchDone = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb &&
        WebLaunchConfig.shouldStartFresh &&
        WebLaunchConfig.parseTarget() == WebLaunchTarget.arcade) {
      widget.store.clearGameSession();
    }
    if (kIsWeb && _webGatePassed) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await widget.audio.unlockForWeb();
        if (mounted) _maybeAutoLaunchWeb();
      });
    }
  }

  bool get _hasSavedGame =>
      widget.store.hasGameSave || _sessionGame != null;

  MergeGame _ensureGame() {
    _sessionGame ??= MergeGame(store: widget.store, audio: widget.audio);
    return _sessionGame!;
  }

  Future<void> _openGame(BuildContext context,
      {required bool fresh,
      int? startStage,
      bool chapterSelect = false,
      bool arcade = false}) async {
    final game = _ensureGame();
    if (arcade) {
      if (fresh) {
        widget.store.clearGameSession();
        game.startArcadeRun();
      }
    } else if (fresh) {
      widget.store.clearGameSession();
      game.restart();
    }
    if (startStage != null && !arcade) {
      game.scheduleJumpToStage(startStage, chapterSelect: chapterSelect);
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GameScreen(game: game, audio: widget.audio),
      ),
    );
    game.syncProgressToStore();
    await game.persistSessionAsync();
    game.pauseEngine();
    if (mounted) setState(() {});
  }

  int get _sessionClearedStage =>
      _sessionGame == null ? 0 : _sessionGame!.sessionClearedStage;

  Future<void> _devResetAllProgress() async {
    widget.audio.bgmMuted = false;
    widget.audio.sfxMuted = false;
    if (_sessionGame != null) {
      _sessionGame!.devResetAll();
    } else {
      widget.store.resetAllProgress();
    }
    if (mounted) setState(() {});
  }

  void _onWebGateComplete() {
    setState(() => _webGatePassed = true);
    widget.audio.unlockForWeb();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoLaunchWeb());
  }

  Future<void> _maybeAutoLaunchWeb() async {
    if (!kIsWeb || _webAutoLaunchDone || !_webGatePassed) return;
    final ctx = _navKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    final target = WebLaunchConfig.parseTarget();
    if (target == WebLaunchTarget.menu) return;

    _webAutoLaunchDone = true;
    switch (target) {
      case WebLaunchTarget.arcade:
        final resumeArcade = WebLaunchConfig.shouldResumeSaved &&
            !WebLaunchConfig.shouldStartFresh &&
            widget.store.hasGameSave &&
            widget.store.savedRunMode == GameRunMode.arcade;
        await _openGame(ctx, fresh: !resumeArcade, arcade: true);
      case WebLaunchTarget.campaign:
        await _openGame(ctx, fresh: false);
      case WebLaunchTarget.menu:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      fontFamily: kIsWeb ? 'Malgun Gothic' : null,
      textTheme: kIsWeb
          ? ThemeData.light().textTheme.apply(
                fontFamily: 'Malgun Gothic',
                bodyColor: Colors.white,
                displayColor: Colors.white,
              )
          : GoogleFonts.gowunDodumTextTheme(),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _btnStyle(const Color(0xfff5b945)),
      ),
    );

    return MaterialApp(
      navigatorKey: _navKey,
      debugShowCheckedModeBanner: false,
      title: AppReleaseConfig.appName,
      theme: theme,
      builder: (context, child) => WebMobileShell(child: child),
      home: !_webGatePassed
          ? WebPlayGate(
              audio: widget.audio,
              onStart: _onWebGateComplete,
            )
          : MainMenuScreen(
              store: widget.store,
              audio: widget.audio,
              hasSavedGame: _hasSavedGame,
              sessionClearedStage: _sessionClearedStage,
              onPlay: _openGame,
              onDevResetAll: _devResetAllProgress,
            ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.game, required this.audio});
  final MergeGame game;
  final AudioManager audio;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  MergeGame get game => widget.game;
  bool _shopOpen = false;
  late bool _bgmMuted;
  late bool _sfxMuted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bgmMuted = widget.audio.bgmMuted;
    _sfxMuted = widget.audio.sfxMuted;
    game.resetRunDailyFlag();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      game.resumeEngine();
      widget.audio.startBgm(game.stageNo.value);
    });
  }

  @override
  void dispose() {
    game.notifyRunFinished();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      game.persistSessionAsync();
    }
  }

  void _openShop() {
    setState(() => _shopOpen = true);
    game.setShopOpen(true);
  }

  void _closeShop() {
    setState(() => _shopOpen = false);
    game.setShopOpen(false);
  }

  Future<void> _openStageSelect() async {
    if (game.bossReward.value != null || game.bossRoutePending.value != null) {
      return;
    }
    final maxStage = game.selectableMaxStage;
    if (maxStage < 1) return;

    game.pauseEngine();
    game.setShopOpen(true);
    final picked = await showStageSelectPicker(
      context,
      maxStage: maxStage,
      clearedThrough: maxStage,
      initialStage: maxStage,
      subtitle: '클리어한 스테이지 1 ~ $maxStage',
    );
    game.setShopOpen(false);
    if (!mounted) return;
    if (picked != null) {
      game.jumpToStage(picked, chapterSelect: true);
    }
    game.resumeEngine();
  }

  Future<void> _onBackPressed() async {
    if (_shopOpen) {
      _closeShop();
      return;
    }
    if (game.bossReward.value != null) return;
    if (game.bossRoutePending.value != null) return;

    game.pauseEngine();
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff2c1f43),
        title: Text('메인 화면', style: AppUi.modalTitle),
        content: Text(
          '메인 화면으로 나가시겠습니까?\n진행 중인 판은 저장되어 이어할 수 있습니다.',
          style: AppUi.modalBody.copyWith(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('취소', style: AppUi.button.copyWith(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('나가기', style: AppUi.button.copyWith(color: Colors.amberAccent)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (leave == true) {
      widget.audio.stopBgm();
      await game.persistSessionAsync();
      if (!mounted) return;
      Navigator.of(context).pop();
    } else {
      game.resumeEngine();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBackPressed();
      },
      child: Scaffold(
        backgroundColor: const Color(0xff150d24),
        body: SafeArea(
          child: Stack(
            children: [
              _Background(game: game),
              Column(
                children: [
                  _Hud(game: game),
                  Expanded(
                    child: Stack(
                      children: [
                        GameWidget(game: game),
                        _DangerVignette(game: game),
                        _BossBar(game: game),
                        _LeftToolbar(
                          game: game,
                          bgmMuted: _bgmMuted,
                          sfxMuted: _sfxMuted,
                          onShop: _openShop,
                          onStageSelect: _openStageSelect,
                          showStageSelect: game.selectableMaxStage >= 1,
                          onToggleBgm: () {
                            setState(() => _bgmMuted = !_bgmMuted);
                            widget.audio.setBgmMuted(_bgmMuted);
                          },
                          onToggleSfx: () {
                            setState(() => _sfxMuted = !_sfxMuted);
                            widget.audio.setSfxMuted(_sfxMuted);
                          },
                        ),
                        _RightToolbar(
                          game: game,
                          onShop: _openShop,
                        ),
                        _CenterTransient(
                            notifier: game.toast, color: Colors.amberAccent),
                        _CenterTransient(
                            notifier: game.bonus, color: Colors.greenAccent),
                        _MissionClearFlash(game: game),
                        MissionIntroBanner(game: game),
                        if (_shopOpen)
                          _ShopModal(game: game, onClose: _closeShop),
                        _BossRewardModal(game: game),
                        _BossRouteModal(game: game),
                        _GameOver(game: game),
                        const _AdModeBadge(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background({required this.game});
  final MergeGame game;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: game.themeId,
      builder: (_, id, _) {
        final t = kThemes.firstWhere((e) => e.id == id,
            orElse: () => kThemes.first);
        return Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [t.top, t.bottom],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.game});
  final MergeGame game;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppUi.hudMinHeight),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: _HudPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _Label('SCORE'),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: _IntText(game.score, style: AppUi.hudScore()),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('BEST ', style: AppUi.hudSub()),
                                _IntText(game.best, style: AppUi.hudSub()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppUi.hudGap),
                  Expanded(
                    flex: 3,
                    child: _HudPanel(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _Label('NEXT'),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ValueListenableBuilder<bool>(
                              valueListenable: game.powerShotArmed,
                              builder: (_, armed, __) =>
                                  ValueListenableBuilder<Set<int>>(
                                valueListenable: game.wantedSpawnTiers,
                                builder: (_, wanted, ___) =>
                                    ValueListenableBuilder<List<int>>(
                                  valueListenable: game.upcomingTiers,
                                  builder: (_, tiers, ____) =>
                                      ValueListenableBuilder<List<String>>(
                                    valueListenable: game.upcomingEmojis,
                                    builder: (_, emojis, _____) => Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (armed) ...[
                                          Text(
                                            '⚡',
                                            style: AppUi.emojiHud.copyWith(
                                              fontSize: 22,
                                              color:
                                                  const Color(0xffffd54f),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        for (var i = 0;
                                            i < emojis.length;
                                            i++) ...[
                                          if (i > 0) const SizedBox(width: 3),
                                          Text(
                                            emojis[i],
                                            style: AppUi.emojiHud.copyWith(
                                              fontSize: i == 0 ? 24 : 18,
                                              color: i < tiers.length &&
                                                      wanted.contains(
                                                          tiers[i])
                                                  ? const Color(0xffffe082)
                                                  : Colors.white.withValues(
                                                      alpha:
                                                          i == 0 ? 1.0 : 0.65),
                                              shadows: i < tiers.length &&
                                                      wanted.contains(
                                                          tiers[i])
                                                  ? const [
                                                      Shadow(
                                                        color: Colors.black54,
                                                        blurRadius: 4,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppUi.hudGap),
                  Expanded(
                    flex: 3,
                    child: _HudPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _Label('STAGE'),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: _IntText(game.stageNo, style: AppUi.hudScore()),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🚀 ', style: AppUi.hudSub()),
                                _IntText(game.shots, style: AppUi.hudSub()),
                              ],
                            ),
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable: game.shots,
                            builder: (context, shotCount, child) =>
                                ValueListenableBuilder<double>(
                              valueListenable: game.shotRegenLeft,
                              builder: (context, left, child) {
                                final atCap = shotCount >= game.stageShotCap;
                                return Text(
                                  atCap
                                      ? '+🚀 —'
                                      : '+🚀 ${MergeGame.formatShotRegen(left)}',
                                  style: AppUi.hudSub().copyWith(
                                    fontSize: 10,
                                    color: atCap
                                        ? Colors.white30
                                        : Colors.white54,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppUi.hudGap),
          ValueListenableBuilder<String>(
            valueListenable: game.mission,
            builder: (_, v, _) {
              if (v.isEmpty) return const SizedBox.shrink();
              return ValueListenableBuilder<String>(
                valueListenable: game.missionHint,
                builder: (_, hint, _) => Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: AppUi.hudPanel(radius: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Clear Mission',
                                style: AppUi.dim.copyWith(
                                    fontSize: 11,
                                    color: Colors.white54,
                                    letterSpacing: 0.5)),
                            if (hint.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(hint,
                                  style: AppUi.mission,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ],
                            const SizedBox(height: 2),
                            Text(v,
                                style: AppUi.dim.copyWith(
                                    fontSize: 13,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🪙', style: AppUi.hudCoin()),
                            _IntText(game.coins, style: AppUi.hudCoin()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HudPanel extends StatelessWidget {
  const _HudPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: AppUi.hudPanel(),
      child: child,
    );
  }
}

/// 미션 달성 시 화면 번쩍임
class _MissionClearFlash extends StatefulWidget {
  const _MissionClearFlash({required this.game});
  final MergeGame game;

  @override
  State<_MissionClearFlash> createState() => _MissionClearFlashState();
}

class _MissionClearFlashState extends State<_MissionClearFlash> {
  double _opacity = 0;
  int _lastId = -1;

  @override
  void initState() {
    super.initState();
    widget.game.missionClearFlash.addListener(_onFlash);
  }

  void _onFlash() {
    final t = widget.game.missionClearFlash.value;
    if (t == null || t.id == _lastId) return;
    _lastId = t.id;
    setState(() => _opacity = 0.55);
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _opacity = 0);
    });
  }

  @override
  void dispose() {
    widget.game.missionClearFlash.removeListener(_onFlash);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.1,
              colors: [
                Colors.amberAccent.withValues(alpha: 0.35),
                Colors.transparent,
              ],
              stops: const [0.2, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _BossBar extends StatelessWidget {
  const _BossBar({required this.game});
  final MergeGame game;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: game.bossActive,
      builder: (_, active, _) {
        if (!active) return const SizedBox.shrink();
        return Positioned(
          top: 6,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Column(
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: game.bossEmoji,
                  builder: (_, e, _) =>
                      Text(e, style: const TextStyle(fontSize: 42)),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 220,
                  padding: const EdgeInsets.all(3),
                  decoration: AppUi.hudPanel(radius: 10),
                  child: ValueListenableBuilder<double>(
                    valueListenable: game.bossHpFrac,
                    builder: (_, f, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: f.clamp(0, 1),
                        minHeight: 12,
                        backgroundColor: Colors.black45,
                        valueColor:
                            const AlwaysStoppedAnimation(Color(0xffff5d5d)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                ValueListenableBuilder<String>(
                  valueListenable: game.bossWeak,
                  builder: (_, w, _) =>
                      Text(w, style: AppUi.dim.copyWith(fontSize: 14)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DangerVignette extends StatelessWidget {
  const _DangerVignette({required this.game});
  final MergeGame game;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: game.shots,
      builder: (_, s, _) {
        final danger = s <= GameConfig.dangerShots && s > 0;
        return IgnorePointer(
          child: AnimatedOpacity(
            opacity: danger ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.0,
                  colors: [Colors.transparent, Color(0x88ff2828)],
                  stops: [0.55, 1.0],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LeftToolbar extends StatelessWidget {
  const _LeftToolbar({
    required this.game,
    required this.bgmMuted,
    required this.sfxMuted,
    required this.onShop,
    required this.onStageSelect,
    required this.showStageSelect,
    required this.onToggleBgm,
    required this.onToggleSfx,
  });
  final MergeGame game;
  final bool bgmMuted;
  final bool sfxMuted;
  final VoidCallback onShop;
  final VoidCallback onStageSelect;
  final bool showStageSelect;
  final VoidCallback onToggleBgm;
  final VoidCallback onToggleSfx;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 10,
      left: 10,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showStageSelect)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GhostRoundButton(
                emoji: '📍',
                tint: Colors.amberAccent,
                onTap: onStageSelect,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _GhostRoundButton(
              emoji: '🛒',
              tint: const Color(0xfff5b945),
              onTap: onShop,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _GhostRoundButton(
              emoji: bgmMuted ? '🎵' : '🎶',
              tint: bgmMuted ? Colors.white38 : Colors.white,
              onTap: onToggleBgm,
            ),
          ),
          _GhostRoundButton(
            emoji: sfxMuted ? '🔇' : '🔊',
            tint: sfxMuted ? Colors.white38 : Colors.white,
            onTap: onToggleSfx,
          ),
        ],
      ),
    );
  }
}

class _RightToolbar extends StatelessWidget {
  const _RightToolbar({required this.game, required this.onShop});
  final MergeGame game;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 10,
      right: 10,
      child: ValueListenableBuilder<int>(
        valueListenable: game.invVersion,
        builder: (_, _, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final p in kPowerups)
              _PwButton(
                emoji: p.emoji,
                count: game.store.invCount(p.id),
                onTap: () {
                  if (game.store.invCount(p.id) <= 0) {
                    onShop();
                  } else {
                    game.usePowerup(p.id);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PwButton extends StatelessWidget {
  const _PwButton(
      {required this.emoji, required this.count, required this.onTap});
  final String emoji;
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _GhostRoundButton(emoji: emoji, tint: Colors.white, onTap: onTap),
          Positioned(
            top: -6,
            right: -6,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xffec4899),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white54, width: 1),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 4),
                  ],
                ),
                alignment: Alignment.center,
                child: Text('$count', style: AppUi.badge),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 평소 반투명 윤곽 — 터치 시 잠깐 진해짐 (디저트 가림 최소화)
class _GhostRoundButton extends StatefulWidget {
  const _GhostRoundButton({
    required this.emoji,
    required this.tint,
    required this.onTap,
  });
  final String emoji;
  final Color tint;
  final VoidCallback onTap;

  @override
  State<_GhostRoundButton> createState() => _GhostRoundButtonState();
}

class _GhostRoundButtonState extends State<_GhostRoundButton> {
  bool _active = false;

  void _setActive(bool v) {
    if (_active == v) return;
    setState(() => _active = v);
  }

  @override
  Widget build(BuildContext context) {
    final fill = widget.tint.withValues(
      alpha: _active ? AppUi.toolbarActiveFill : AppUi.toolbarIdleFill,
    );
    final border = widget.tint.withValues(
      alpha: _active ? AppUi.toolbarActiveBorder : AppUi.toolbarIdleBorder,
    );
    final emojiOpacity =
        _active ? AppUi.toolbarActiveEmoji : AppUi.toolbarIdleEmoji;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTapDown: (_) => _setActive(true),
        onTapUp: (_) {
          _setActive(false);
          widget.onTap();
        },
        onTapCancel: () => _setActive(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: AppUi.toolbarBtnSize,
          height: AppUi.toolbarBtnSize,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: _active ? 2 : 1.5),
            boxShadow: _active
                ? const [
                    BoxShadow(
                        color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Opacity(
            opacity: emojiOpacity,
            child: Text(widget.emoji, style: AppUi.emojiBtn),
          ),
        ),
      ),
    );
  }
}

class _GameOver extends StatelessWidget {
  const _GameOver({required this.game});
  final MergeGame game;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: game.status,
      builder: (_, status, _) {
        if (status != 'over') return const SizedBox.shrink();
        return Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.65),
            alignment: Alignment.center,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
              decoration: AppUi.hudPanel(radius: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🍰', style: TextStyle(fontSize: 56)),
                  Text('GAME OVER', style: AppUi.modalTitle),
                  const SizedBox(height: 10),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('SCORE ', style: AppUi.dim),
                    _IntText(game.score, style: AppUi.score()),
                  ]),
                  const SizedBox(height: 22),
                  ElevatedButton(
                    style: _btnStyle(const Color(0xfff5b945)),
                    onPressed: game.continueGame,
                    child: Text(
                      '▶️ 계속하기 (광고 · 🚀${GameConfig.adContinueShots} 회복'
                      ' · 남은 ${game.store.adQuota.remaining(AdPlacement.continueGame)}회)',
                      style: AppUi.button,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: _btnStyle(const Color(0xffff8fb1)),
                    onPressed: game.restart,
                    child: Text('다시 하기', style: AppUi.button),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BossRewardModal extends StatelessWidget {
  const _BossRewardModal({required this.game});
  final MergeGame game;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<RewardEntry>?>(
      valueListenable: game.bossReward,
      builder: (_, rewards, _) {
        if (rewards == null) return const SizedBox.shrink();
        return Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.82),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: AppUi.hudPanel(radius: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('👹 BOSS 격파!',
                      style: AppUi.modalTitle.copyWith(color: Colors.amberAccent)),
                  const SizedBox(height: 6),
                  Text('영구 아이템 획득', style: AppUi.dim),
                  const SizedBox(height: 16),
                  for (final r in rewards)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(
                          r.isCoin
                              ? '🪙 +${r.coinAmount}  ·  ${r.desc}'
                              : '${r.emoji} ${r.name} Lv.${r.lvl}  ·  ${r.desc}',
                          style: AppUi.modalBody),
                    ),
                  const SizedBox(height: 12),
                  if (rewards.length < 2)
                    ElevatedButton(
                      style: _btnStyle(const Color(0xff34d399)),
                      onPressed: game.bossRewardWatchAd,
                      child: Text(
                        '🎬 광고 보고 아이템 한 번 더'
                        ' · 남은 ${game.store.adQuota.remaining(AdPlacement.bossExtra)}회',
                        style: AppUi.button.copyWith(color: Colors.white),
                      ),
                    ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: _btnStyle(const Color(0xffff8fb1)),
                    onPressed: game.closeBossReward,
                    child: Text('확인', style: AppUi.button),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BossRouteModal extends StatelessWidget {
  const _BossRouteModal({required this.game});
  final MergeGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: game.bossRoutePending,
      builder: (_, clearedStage, _) {
        if (clearedStage == null) return const SizedBox.shrink();
        final nextStage = clearedStage + 1;
        return Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.82),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: AppUi.hudPanel(radius: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('👹 STAGE $clearedStage 클리어!',
                      style: AppUi.modalTitle.copyWith(color: Colors.amberAccent)),
                  const SizedBox(height: 8),
                  Text(
                    '다음으로 진행할까요, 같은 보스를 반복할까요?',
                    style: AppUi.modalBody.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: _btnStyle(const Color(0xfff5b945)),
                      onPressed: game.confirmBossContinue,
                      child: Text('▶  STAGE $nextStage 로 진행',
                          style: AppUi.button),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.35)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: game.confirmBossRepeat,
                      child: Text('🔁  STAGE $clearedStage 보스 반복',
                          style: AppUi.button),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShopModal extends StatefulWidget {
  const _ShopModal({required this.game, required this.onClose});
  final MergeGame game;
  final VoidCallback onClose;
  @override
  State<_ShopModal> createState() => _ShopModalState();
}

class _ShopModalState extends State<_ShopModal> {
  MergeGame get game => widget.game;

  void _showBossPerkHelp() {
    final store = game.store;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff2c1f43),
        title: Text('보스 영구 아이템', style: AppUi.modalTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '보스 스테이지를 클리어하면 아래 아이템 중 하나를 영구 획득합니다.',
                  style: AppUi.modalBody.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                for (final p in kBossPerks) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p.emoji} ${p.name}  Lv.${store.getPerk(p.id)}',
                          style: AppUi.modalBody.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(p.desc,
                            style: AppUi.dim.copyWith(
                                fontSize: 13, color: Colors.white60)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('닫기',
                style: AppUi.button.copyWith(color: Colors.amberAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = game.store;
    final screenW = MediaQuery.sizeOf(context).width;
    final contentW = (screenW - 32).clamp(280.0, 400.0);

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentW,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('🛒 상점', style: AppUi.modalTitle),
                        const Spacer(),
                        Text('🪙 ', style: AppUi.coin),
                        _IntText(game.coins,
                            style: AppUi.coin.copyWith(fontSize: 20)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: _btnStyle(const Color(0xff34d399)),
                        onPressed: () => setState(game.watchAdForCoins),
                        child: Text(
                          '🎬 광고 보고 🪙+${Coins.adReward}'
                          ' · 남은 ${game.store.adQuota.remaining(AdPlacement.coins)}회',
                          style: AppUi.button.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                    const _SectionLabel('파워업'),
                    _ShopGrid(
                      width: contentW,
                      children: [
                        for (final p in kPowerups)
                          _ShopTile(
                            title: '${p.emoji}\n${p.label}',
                            sub: '🪙${p.cost} · 보유 ${store.invCount(p.id)}',
                            onTap: () => setState(() => game.buyPowerup(p.id)),
                          ),
                      ],
                    ),
                    const _SectionLabel('디저트 스킨'),
                    _ShopGrid(
                      width: contentW,
                      children: [
                        for (final s in kSkins)
                          _ShopTile(
                            title: s.emojis.join(' '),
                            sub: store.skin == s.id
                                ? '${s.name} · 선택됨'
                                : store.hasSkin(s.id)
                                    ? '${s.name} · 적용'
                                    : '${s.name} · 🪙${s.cost}',
                            selected: store.skin == s.id,
                            onTap: () =>
                                setState(() => game.buyOrSelectSkin(s.id)),
                          ),
                      ],
                    ),
                    const _SectionLabel('배경 테마'),
                    _ShopGrid(
                      width: contentW,
                      children: [
                        for (final t in kThemes)
                          _ShopTile(
                            title: t.name,
                            sub: store.theme == t.id
                                ? '선택됨'
                                : store.hasTheme(t.id)
                                    ? '적용'
                                    : '🪙${t.cost}',
                            selected: store.theme == t.id,
                            onTap: () =>
                                setState(() => game.buyOrSelectTheme(t.id)),
                          ),
                      ],
                    ),
                    _BossPerksPanel(
                      store: store,
                      onHelp: _showBossPerkHelp,
                    ),
                    if (kDebugMode) ...[
                      const _SectionLabel('🛠 개발자 테스트'),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: _btnStyle(const Color(0xff64748b)),
                          onPressed: () async {
                            final s = await showStageSelectPicker(
                              context,
                              maxStage: 999,
                              title: '🛠 DEV · 스테이지',
                            );
                            if (s != null) {
                              setState(() => game.jumpToStage(s, chapterSelect: true));
                            }
                          },
                          child: Text('스테이지 선택',
                              style: AppUi.button.copyWith(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: _btnStyle(const Color(0xff64748b)),
                          onPressed: () => setState(game.devClearPerks),
                          child: Text('보스 아이템만 초기화',
                              style: AppUi.button.copyWith(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: _btnStyle(const Color(0xff7f1d1d)),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xff2c1f43),
                                title: Text('전체 초기화', style: AppUi.modalTitle),
                                content: Text(
                                  'BEST·코인·인벤·보스 퍼크·스킨/테마·'
                                  '스테이지 진행·이어하기를 모두 삭제합니다.\n'
                                  '되돌릴 수 없습니다.',
                                  style: AppUi.modalBody
                                      .copyWith(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text('취소',
                                        style: AppUi.button
                                            .copyWith(color: Colors.white70)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text('전체 초기화',
                                        style: AppUi.button
                                            .copyWith(color: Colors.redAccent)),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              setState(game.devResetAll);
                            }
                          },
                          child: Text('전체 초기화',
                              style: AppUi.button.copyWith(color: Colors.white)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: _btnStyle(const Color(0xffff8fb1)),
                        onPressed: widget.onClose,
                        child: Text('닫기', style: AppUi.button),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 3열 균등 그리드 (화면 너비에 맞춤)
class _ShopGrid extends StatelessWidget {
  const _ShopGrid({required this.width, required this.children});
  final double width;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const cols = 3;
    const gap = 10.0;
    final tileW = (width - gap * (cols - 1)) / cols;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      alignment: WrapAlignment.center,
      children: [
        for (final c in children) SizedBox(width: tileW, child: c),
      ],
    );
  }
}

class _BossPerksPanel extends StatelessWidget {
  const _BossPerksPanel({required this.store, required this.onHelp});
  final Store store;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
        decoration: AppUi.hudPanel(radius: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('보스 영구 아이템',
                          style: AppUi.section.copyWith(color: Colors.white)),
                      Text('(보스 파밍 · 미획득 Lv0)',
                          style: AppUi.dim.copyWith(
                              fontSize: 12, color: Colors.white38)),
                    ],
                  ),
                ),
                Material(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onHelp,
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Center(
                        child: Text('?',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final p in kBossPerks)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                        alpha: store.getPerk(p.id) > 0 ? 0.06 : 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(
                            alpha: store.getPerk(p.id) > 0 ? 0.1 : 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p.emoji} ${p.name}  Lv.${store.getPerk(p.id)}',
                        style: AppUi.body.copyWith(
                          fontSize: 15,
                          color: store.getPerk(p.id) > 0
                              ? Colors.white
                              : Colors.white38,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.desc,
                        style: AppUi.dim.copyWith(
                            fontSize: 13,
                            color: store.getPerk(p.id) > 0
                                ? Colors.white54
                                : Colors.white30,
                            height: 1.35),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({
    required this.title,
    required this.sub,
    required this.onTap,
    this.selected = false,
  });
  final String title;
  final String sub;
  final VoidCallback onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0x55f5b945)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: Colors.amberAccent, width: 1.5)
              : Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppUi.body.copyWith(fontSize: 14, height: 1.2),
            ),
            const SizedBox(height: 6),
            Text(
              sub,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppUi.coin.copyWith(fontSize: 12, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text, style: AppUi.section),
        ),
      );
}

class _CenterTransient extends StatefulWidget {
  const _CenterTransient({required this.notifier, required this.color});
  final ValueNotifier<Transient?> notifier;
  final Color color;
  @override
  State<_CenterTransient> createState() => _CenterTransientState();
}

class _CenterTransientState extends State<_CenterTransient> {
  String _text = '';
  double _opacity = 0;
  int _lastId = -1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_onChange);
  }

  void _onChange() {
    final t = widget.notifier.value;
    if (t == null || t.id == _lastId) return;
    _lastId = t.id;
    setState(() {
      _text = t.text;
      _opacity = 1;
    });
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _opacity = 0);
    });
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onChange);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 300),
          child: Text(_text,
              textAlign: TextAlign.center,
              style: AppUi.toast.copyWith(color: widget.color)),
        ),
      ),
    );
  }
}

class _IntText extends StatelessWidget {
  const _IntText(this.notifier, {required this.style});
  final ValueNotifier<int> notifier;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: notifier,
        builder: (_, v, _) => Text('$v', style: style),
      );
}

ButtonStyle _btnStyle(Color bg) => ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: const Color(0xff150d24),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      shape: const StadiumBorder(),
      elevation: 2,
    );

/// stub / 테스트 / 실광고 구분 배지 (Phase 0 QA용)
class _AdModeBadge extends StatelessWidget {
  const _AdModeBadge();

  @override
  Widget build(BuildContext context) {
    final show = kDebugMode || AdConfig.testMode || adsUsingStub;
    if (!show) return const SizedBox.shrink();
    final label = adModeLabel();
    final color = switch (label) {
      'AD LIVE' => const Color(0xff34d399),
      'AD TEST' => const Color(0xfff5b945),
      _ => const Color(0xfffb7185),
    };
    return Positioned(
      right: 10,
      bottom: 10,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.8)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppUi.label.copyWith(fontSize: 11, height: 1.0),
      );
}
