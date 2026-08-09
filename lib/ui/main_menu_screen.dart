import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/app_release_config.dart';
import '../game/daily_missions.dart';
import '../game/audio.dart';
import '../game/config.dart';
import '../game/store.dart';
import '../services/app_update_service.dart';
import 'app_ui.dart';
import 'app_update_dialog.dart';
import 'stage_select_picker.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({
    super.key,
    required this.store,
    required this.audio,
    required this.hasSavedGame,
    required this.sessionClearedStage,
    required this.onPlay,
    required this.onDevResetAll,
  });
  final Store store;
  final AudioManager audio;
  final bool hasSavedGame;
  final int sessionClearedStage;
  final Future<void> Function(BuildContext context,
      {required bool fresh,
      int? startStage,
      bool chapterSelect,
      bool arcade}) onPlay;
  final Future<void> Function() onDevResetAll;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  late final AppUpdateService _updateService;
  String _versionLabel = '';

  @override
  void initState() {
    super.initState();
    _updateService = AppUpdateService(widget.store.prefs);
    widget.store.refreshDailyMissions();
    _loadVersionLabel();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoCheckUpdate());
  }

  Future<void> _loadVersionLabel() async {
    final info = await _updateService.packageInfo();
    if (!mounted) return;
    setState(() {
      _versionLabel = 'v${info.version} (${info.buildNumber})';
    });
  }

  Future<void> _autoCheckUpdate() async {
    if (kIsWeb ||
        !AppReleaseConfig.autoCheckOnMenu ||
        !_updateService.isConfigured) {
      return;
    }
    final update = await _updateService.checkForUpdate();
    if (!mounted || update == null) return;
    await showAppUpdateDialog(context, service: _updateService, info: update);
  }

  Future<void> _manualCheckUpdate() async {
    if (!_updateService.isConfigured) {
      await showManualUpdateResult(
        context,
        message:
            '업데이트 서버 URL이 설정되지 않았습니다.\n'
            '배포 시 --dart-define=UPDATE_MANIFEST_URL=... 로 지정하세요.',
        isError: true,
      );
      return;
    }
    final update = await _updateService.checkForUpdate();
    if (!mounted) return;
    if (update != null) {
      await showAppUpdateDialog(
        context,
        service: _updateService,
        info: update,
        allowSkip: false,
      );
    } else {
      final msg = _updateService.lastError ??
          (_updateService.status == AppUpdateStatus.upToDate
              ? '최신 버전입니다.'
              : '업데이트 확인을 완료했습니다.');
      await showManualUpdateResult(
        context,
        message: msg,
        isError: _updateService.status == AppUpdateStatus.error,
      );
    }
  }

  void _refresh() => setState(() {});

  int get _maxSelectableStage =>
      widget.store.menuSelectableMax(widget.sessionClearedStage);

  Future<void> _startArcade() async {
    await widget.onPlay(context, fresh: true, arcade: true);
    _refresh();
  }

  void _claimDaily(String id) {
    final reward = widget.store.claimDailyMission(id);
    if (reward != null) {
      widget.audio.stageStart();
    }
    _refresh();
  }

  Future<void> _continueGame() async {
    await widget.onPlay(context, fresh: false, chapterSelect: false);
    _refresh();
  }

  Future<void> _startNewGame() async {
    if (widget.hasSavedGame) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xff2c1f43),
          title: Text('새 게임', style: AppUi.modalTitle),
          content: Text(
            '진행 중인 판을 버리고 처음부터 시작할까요?',
            style: AppUi.modalBody.copyWith(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('취소',
                  style: AppUi.button.copyWith(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('새로 시작',
                  style: AppUi.button.copyWith(color: Colors.amberAccent)),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      await widget.onPlay(context, fresh: true, chapterSelect: false);
    } else {
      await widget.onPlay(context, fresh: false, chapterSelect: false);
    }
    _refresh();
  }

  Future<void> _pickStage() async {
    final maxStage = _maxSelectableStage;
    if (maxStage < 1) return;
    final stage = await showStageSelectPicker(
      context,
      maxStage: maxStage,
      clearedThrough: maxStage,
      initialStage: maxStage,
      subtitle: '클리어한 스테이지 1 ~ $maxStage',
    );
    if (stage == null || !mounted) return;
    await widget.onPlay(context,
        fresh: false, startStage: stage, chapterSelect: true);
    _refresh();
  }

  Future<void> _devPickStage() async {
    final stage = await showStageSelectPicker(
      context,
      maxStage: 999,
      title: '🛠 DEV · 스테이지',
    );
    if (stage == null || !mounted) return;
    await widget.onPlay(context,
        fresh: false, startStage: stage, chapterSelect: true);
    _refresh();
  }

  Future<void> _devResetAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff2c1f43),
        title: Text('전체 초기화', style: AppUi.modalTitle),
        content: Text(
          '다음 데이터를 모두 삭제합니다.\n'
          '· BEST / 코인 / 스테이지 진행\n'
          '· 인벤토리 (파워·샷 아이템)\n'
          '· 보스 영구 아이템 (퍼크)\n'
          '· 스킨·테마 (기본만)\n'
          '· 이어하기 저장\n\n'
          '되돌릴 수 없습니다. (개발자 테스트용)',
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
            child: Text('전체 초기화',
                style: AppUi.button.copyWith(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await widget.onDevResetAll();
    _refresh();
  }

  Future<void> _devClearPerks() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff2c1f43),
        title: Text('보스 아이템 초기화', style: AppUi.modalTitle),
        content: Text(
          '획득한 보스 영구 아이템을 모두 삭제합니다.\n(개발자 테스트용)',
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
            child: Text('초기화',
                style: AppUi.button.copyWith(color: Colors.amberAccent)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    widget.store.clearPerks();
    _refresh();
  }

  Future<void> _onBackPressed() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff2c1f43),
        title: Text('게임 종료', style: AppUi.modalTitle),
        content: Text(
          kIsWeb
              ? '이전 페이지(블로그)로 돌아가시겠습니까?'
              : '게임을 종료하시겠습니까?',
          style: AppUi.modalBody.copyWith(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소', style: AppUi.button.copyWith(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(kIsWeb ? '돌아가기' : '종료',
                style: AppUi.button.copyWith(color: Colors.amberAccent)),
          ),
        ],
      ),
    );
    if (exit == true && mounted) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final maxStage = _maxSelectableStage;
    final theme = kThemes.firstWhere((t) => t.id == store.theme,
        orElse: () => kThemes.first);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBackPressed();
      },
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [theme.top, theme.bottom],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🍰', style: TextStyle(fontSize: 72)),
                          const SizedBox(height: 8),
                    if (kIsWeb) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: AppUi.hudPanel(radius: 14),
                        child: Text(
                          '📱 드래그로 조준 → 손을 떼면 발사\n세로 화면에 최적화되어 있어요',
                          style: AppUi.dim.copyWith(
                            fontSize: 13,
                            color: Colors.white70,
                            height: 1.45,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    Text(
                      'Dessert Billiards',
                      style: AppUi.modalTitle.copyWith(fontSize: 32),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Merge',
                      style: AppUi.modalTitle.copyWith(
                        fontSize: 26,
                        color: Colors.amberAccent,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: AppUi.hudPanel(radius: 16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('STAGE ', style: AppUi.hudSub()),
                              Text('$maxStage',
                                  style: AppUi.hudSub().copyWith(color: Colors.white)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('BEST ', style: AppUi.hudSub()),
                              Text('${store.best}',
                                  style: AppUi.hudScore(color: Colors.white)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('🪙 ', style: AppUi.hudCoin()),
                              Text('${store.coins}',
                                  style: AppUi.hudCoin().copyWith(fontSize: 18)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DailyMissionPanel(
                      daily: store.daily,
                      onClaim: _claimDaily,
                    ),
                    const SizedBox(height: 20),
                    if (widget.hasSavedGame) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: menuBtnStyle(const Color(0xfff5b945)),
                          onPressed: _continueGame,
                          child: Text('▶  이어하기', style: AppUi.button),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                          onPressed: _startNewGame,
                          child: Text('🔄  새로 시작', style: AppUi.button),
                        ),
                      ),
                    ] else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: menuBtnStyle(const Color(0xfff5b945)),
                          onPressed: _startNewGame,
                          child: Text('▶  시작하기', style: AppUi.button),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xff9ad0ec),
                          side: BorderSide(
                              color:
                                  const Color(0xff9ad0ec).withValues(alpha: 0.55)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: _startArcade,
                        child: Text('🎮  아케이드', style: AppUi.button),
                      ),
                    ),
                    if (maxStage >= 1) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.amberAccent,
                            side: BorderSide(
                                color: Colors.amberAccent.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: _pickStage,
                          child: Text('📍  스테이지 선택', style: AppUi.button),
                        ),
                      ),
                    ],
                    if (kDebugMode) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white54,
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.25)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: _devPickStage,
                          child: Text('🛠 DEV · 스테이지 선택',
                              style: AppUi.button.copyWith(fontSize: 15)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _devResetAll,
                        child: Text(
                          '🛠 DEV · 전체 초기화',
                          style: AppUi.dim.copyWith(
                            fontSize: 14,
                            color: Colors.redAccent.withValues(alpha: 0.85),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _devClearPerks,
                        child: Text(
                          '🛠 DEV · 보스 아이템만 초기화',
                          style: AppUi.dim.copyWith(
                            fontSize: 14,
                            color: Colors.white54,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (!kIsWeb)
                  TextButton(
                    onPressed: _manualCheckUpdate,
                    child: Text(
                      '업데이트 확인 · $_versionLabel',
                      style: AppUi.dim.copyWith(
                        fontSize: 12,
                        color: Colors.white38,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                else
                  Text(
                    '웹 · $_versionLabel',
                    style: AppUi.dim.copyWith(
                      fontSize: 12,
                      color: Colors.white24,
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyMissionPanel extends StatelessWidget {
  const _DailyMissionPanel({required this.daily, required this.onClaim});

  final DailyMissionState daily;
  final void Function(String id) onClaim;

  @override
  Widget build(BuildContext context) {
    if (daily.entries.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppUi.hudPanel(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('오늘의 미션', style: AppUi.hudSub()),
              if (daily.unclaimedCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xffffe082).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${daily.unclaimedCount}개 수령 가능',
                    style: AppUi.dim.copyWith(
                      fontSize: 11,
                      color: const Color(0xffffe082),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          for (final e in daily.entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          style: AppUi.dim.copyWith(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: e.target > 0
                                ? (e.progress / e.target).clamp(0.0, 1.0)
                                : 0,
                            minHeight: 6,
                            backgroundColor: Colors.black26,
                            color: e.claimable
                                ? const Color(0xffffe082)
                                : const Color(0xff9ad0ec),
                          ),
                        ),
                        Text(
                          '${e.progress}/${e.target} · 🪙${e.coinReward}',
                          style: AppUi.dim.copyWith(
                            fontSize: 10,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (e.claimable)
                    TextButton(
                      onPressed: () => onClaim(e.id),
                      child: Text(
                        '수령',
                        style: AppUi.button.copyWith(
                          fontSize: 14,
                          color: const Color(0xffffe082),
                        ),
                      ),
                    )
                  else if (e.claimed)
                    Text(
                      '완료',
                      style: AppUi.dim.copyWith(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

ButtonStyle menuBtnStyle(Color bg) => ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: const Color(0xff150d24),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: const StadiumBorder(),
      elevation: 3,
    );
