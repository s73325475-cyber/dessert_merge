import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import 'ads.dart';
import 'audio.dart';
import 'boss_rewards.dart';
import 'bumper.dart';
import 'config.dart';
import 'dessert.dart';
import 'effects.dart';
import 'spawn.dart';
import 'daily_missions.dart';
import 'game_run_mode.dart';
import 'game_session_save.dart';
import 'stage.dart';
import 'store.dart';

class RewardEntry {
  RewardEntry.perk({
    required this.emoji,
    required this.name,
    required this.desc,
    required this.lvl,
    this.skillJump = false,
  })  : isCoin = false,
        coinAmount = 0;

  RewardEntry.coins(this.coinAmount)
      : isCoin = true,
        emoji = '🪙',
        name = '중복 보상',
        desc = '이미 보유한 단계의 아이템',
        lvl = 0,
        skillJump = false;

  final String emoji;
  final String name;
  final String desc;
  final int lvl;
  final bool isCoin;
  final int coinAmount;
  final bool skillJump;
}

class Transient {
  Transient(this.text, this.id);
  final String text;
  final int id;
}

/// 스테이지 진입 안내 (중상단 배너)
class StageIntroInfo {
  StageIntroInfo({
    required this.stage,
    required this.missionHint,
    required this.missionProgress,
    required this.roll,
    required this.id,
  });
  final int stage;
  final String missionHint;
  final String missionProgress;
  final MissionRoll roll;
  final int id;
}

enum _ActionType { merge }

enum _BossGimmickKind { junk, steal, smash }

class _Pending {
  _Pending(this.type, this.a, this.b);
  final _ActionType type;
  final Dessert a;
  final Dessert b;
}

class MergeGame extends Forge2DGame with MultiTouchDragDetector {
  MergeGame({required this.store, required this.audio})
      : super(gravity: Vector2.zero(), zoom: 10);

  final Store store;
  final AudioManager audio;
  final _rng = Random();

  // ----- HUD/오버레이 상태 -----
  final ValueNotifier<int> score = ValueNotifier(0);
  final ValueNotifier<int> best = ValueNotifier(0);
  final ValueNotifier<int> shots = ValueNotifier(GameConfig.baseShots);
  /// 투척 충전까지 남은 시간(초)
  final ValueNotifier<double> shotRegenLeft =
      ValueNotifier(GameConfig.shotRegenSec);
  final ValueNotifier<int> stageNo = ValueNotifier(1);
  final ValueNotifier<int> coins = ValueNotifier(0);
  final ValueNotifier<String> status = ValueNotifier('playing');
  final ValueNotifier<String> mission = ValueNotifier('');
  final ValueNotifier<String> missionHint = ValueNotifier('');
  static const int upcomingPreviewCount = 3;
  final ValueNotifier<List<String>> upcomingEmojis =
      ValueNotifier(const ['🍬', '🍬', '🍬']);
  final ValueNotifier<List<int>> upcomingTiers =
      ValueNotifier(const [0, 0, 0]);
  final ValueNotifier<Set<int>> wantedSpawnTiers = ValueNotifier({});
  final ValueNotifier<int> invVersion = ValueNotifier(0);
  /// 파워샷(⚡) — 다음 1발 물리 2배
  final ValueNotifier<bool> powerShotArmed = ValueNotifier(false);
  final ValueNotifier<String> themeId = ValueNotifier('default');

  final ValueNotifier<bool> bossActive = ValueNotifier(false);
  final ValueNotifier<double> bossHpFrac = ValueNotifier(1);
  final ValueNotifier<String> bossEmoji = ValueNotifier('👹');
  final ValueNotifier<String> bossWeak = ValueNotifier('');

  final ValueNotifier<Transient?> toast = ValueNotifier(null);
  final ValueNotifier<Transient?> bonus = ValueNotifier(null);
  final ValueNotifier<Transient?> missionClearFlash = ValueNotifier(null);
  final ValueNotifier<StageIntroInfo?> stageIntro = ValueNotifier(null);
  final ValueNotifier<List<RewardEntry>?> bossReward = ValueNotifier(null);
  /// 보스 보상 확인 후 — 같은 보스 반복 vs 다음 스테이지 (클리어한 보스 스테이지 번호)
  final ValueNotifier<int?> bossRoutePending = ValueNotifier(null);

  int _transientId = 0;

  // ----- 스킨 -----
  static List<String> currentSkinEmojis = kSkins[0].emojis;
  static String skinEmoji(int tier) =>
      currentSkinEmojis[tier.clamp(0, kMaxTier)];

  // ----- 발사 / 조준 -----
  final Vector2 launchPos = Vector2(GameConfig.fieldW / 2, GameConfig.launchY);
  Vector2? _touchPos;
  int? _aimPointerId;
  bool _aimFired = false;
  double _aimStartClock = 0;
  double _fireCooldownT = 0;
  bool _magnetSkipFrame = false;
  final Vector2 _aimDir = Vector2(0, -1);
  bool get aiming => _touchPos != null;
  Vector2 get aimDir => _aimDir;
  double get aimStartClock => _aimStartClock;
  double get clock => _clock;
  bool get canFireAfterAimHold => _canFireAfterAim();
  /// 발사 속도 (고정). 충돌 파워는 _powerMult → Dessert.launchPowerMult
  double get launchSpeed => GameConfig.maxLaunchSpeed;
  late Spawn currentSpawn;
  final List<Spawn> _upcomingQueue = [];

  // ----- 스테이지 -----
  final stage = StageManager();
  GameRunMode runMode = GameRunMode.campaign;
  int _arcadeWave = 1;
  bool _runDailyCounted = false;
  bool get isArcade => runMode == GameRunMode.arcade;

  // ----- 진행 상태 -----
  bool blocked = false;
  bool _missionCountingEnabled = true;
  int _missionEpoch = 0;
  bool _onLoadDone = false;
  int? _pendingJumpStage;
  bool _pendingChapterSelect = false;
  double _clock = 0;
  double _lastMergeTime = -10;
  int _combo = 0;
  double _shotRegenT = GameConfig.shotRegenSec;
  double _sessionSaveT = 0;
  static const _sessionSaveInterval = 3.0;

  int get _stageShotCap =>
      GameConfig.baseShots +
      (stage.boss ? GameConfig.bossExtraShots : 0) +
      stage.bonusStartShots;

  int get stageShotCap => _stageShotCap;

  void _resetShotRegenTimer() {
    _shotRegenT = GameConfig.shotRegenSec;
    shotRegenLeft.value = _shotRegenT;
  }

  void _updateShotRegen(double dt) {
    if (stage.shots >= _stageShotCap) {
      _resetShotRegenTimer();
      return;
    }
    _shotRegenT -= dt;
    if (_shotRegenT <= 0) {
      stage.grantShots(1);
      shots.value = stage.shots;
      if (shots.value > 0) _graceTimer = null;
      _showBonus('+1 🚀');
      _resetShotRegenTimer();
      return;
    }
    shotRegenLeft.value = _shotRegenT;
  }

  static String formatShotRegen(double sec) {
    final s = sec.ceil().clamp(0, 99999);
    if (s >= 60) {
      final m = s ~/ 60;
      final r = s % 60;
      return '$m:${r.toString().padLeft(2, '0')}';
    }
    return '${s}s';
  }

  double? _graceTimer;
  int _shotsConsumedThisStage = 0;
  /// 이번 스테이지에서 소모한 발사 횟수 (통계용)
  int get stageShotsConsumed => _shotsConsumedThisStage;
  int get adContinueRewardShots => GameConfig.adContinueShots;

  void _resetStageShotCounter() => _shotsConsumedThisStage = 0;

  void _recordShotConsumed() => _shotsConsumedThisStage++;

  int _fireId = 0;
  int _activeFireId = 0;
  int _mergesThisFire = 0;

  int _stageRefundGranted = 0;
  void _resetStageRefundCounter() => _stageRefundGranted = 0;

  void _applyMergeRefund(int producedTier, {double mult = 1.0}) {
    var amount = stage.refundAmount(producedTier);
    if (producedTier >= 3) amount += store.getPerk('refund');
    amount = max(0, (amount * mult).floor());
    final room = GameConfig.maxRefundPerStage - _stageRefundGranted;
    final grant = min(amount, room);
    if (grant <= 0) return;
    _stageRefundGranted += grant;
    stage.grantShots(grant);
    shots.value = stage.shots;
  }

  double _bossJunkCd = 0;
  double _bossStealCd = 0;
  double _bossSmashCd = 0;
  bool _bossJunkArmed = false;
  bool _bossStealArmed = false;
  bool _bossSmashArmed = false;
  int _bossJunkShots = 0;
  int _bossStealShots = 0;
  int _bossSmashShots = 0;
  _BossGimmickKind? _bossPendingCast;
  double _bossCastTelegraphT = 0;
  Dessert? _bossSmashTarget;

  void _resetBossGimmicks() {
    _bossJunkCd = 0;
    _bossStealCd = 0;
    _bossSmashCd = 0;
    _bossJunkArmed = false;
    _bossStealArmed = false;
    _bossSmashArmed = false;
    _bossJunkShots = 0;
    _bossStealShots = 0;
    _bossSmashShots = 0;
    _bossPendingCast = null;
    _bossCastTelegraphT = 0;
    _bossSmashTarget = null;
  }

  /// 스테이지 선택으로 시작한 앵커 (보스 파밍 시 동일 스테이지 반복)
  int? _chapterAnchorStage;
  int? _pendingBossClearStage;
  int? _pendingBossNextStage;

  // ----- 퍼크 효과 값 -----
  double _goldenChance = Golden.chance;
  double _mergePowerShotChance = MergeDrop.powerShotChance;
  double _comboWindow = GameConfig.comboWindowSec;
  double _powerMult = 1;
  double _coinMult = 1;
  double _scoreMult = 1;

  final List<_Pending> _pending = [];

  // ----- 화면 흔들림 -----
  double _shakeT = 0;
  double _shakeMag = 0;
  late final Vector2 _camBase =
      Vector2(GameConfig.fieldW / 2, GameConfig.fieldH / 2);

  @override
  Color backgroundColor() => const Color(0xff150d24);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = _camBase.clone();
    world.add(_Boundaries());
    world.add(_GuideLayer(this));

    coins.value = store.coins;
    best.value = store.best;
    applyCosmetics();
    applyPerks();
    if (_pendingJumpStage != null) {
      final n = _pendingJumpStage!;
      final ch = _pendingChapterSelect;
      _pendingJumpStage = null;
      _pendingChapterSelect = false;
      jumpToStage(n, chapterSelect: ch);
    } else if (store.hasGameSave) {
      restoreFromStore();
    } else if (runMode == GameRunMode.arcade) {
      // startArcadeRun() 등으로 이미 세션이 준비된 경우 (_startStage가 campaign으로 덮어쓰지 않음)
    } else {
      _startStage(1);
      audio.startBgm(1);
    }
    _onLoadDone = true;
  }

  /// onLoad 완료 전 스테이지 점프 예약 (메인→스테이지 선택 최초 진입 버그 방지)
  void scheduleJumpToStage(int n, {bool chapterSelect = false}) {
    if (_onLoadDone) {
      jumpToStage(n, chapterSelect: chapterSelect);
      return;
    }
    _pendingJumpStage = n;
    _pendingChapterSelect = chapterSelect;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final zoom = min(size.x / GameConfig.fieldW, size.y / GameConfig.fieldH);
    camera.viewfinder.zoom = zoom;
  }

  // ===== 퍼크 / 코스메틱 =====
  void applyPerks() {
    _goldenChance = Golden.chance + store.getPerk('golden') * 0.03;
    _mergePowerShotChance =
        MergeDrop.powerShotChance + store.getPerk('luck') * 0.01;
    _comboWindow = GameConfig.comboWindowSec + store.getPerk('comboHold') * 0.4;
    _powerMult = 1 + store.getPerk('powerMult') * 0.1;
    _coinMult = 1 + store.getPerk('coinMult') * 0.2;
    _scoreMult = 1 + store.getPerk('scoreMult') * 0.1;
    stage.bonusStartShots = store.getPerk('startShots');
  }

  void applyCosmetics() {
    final skin = kSkins.firstWhere((s) => s.id == store.skin,
        orElse: () => kSkins.first);
    currentSkinEmojis = skin.emojis;
    themeId.value = store.theme;
  }

  // ===== 스테이지 =====
  void _startStage(int n, {bool showIntro = false}) {
    runMode = GameRunMode.campaign;
    stage.start(n);
    stageNo.value = n;
    shots.value = stage.shots;
    _graceTimer = null;
    _resetStageShotCounter();
    _resetStageRefundCounter();
    _resetBossGimmicks();
    currentSpawn = _roll(n);
    _resetUpcoming(n);
    _applyStartBoost();
    _spawnBumpers(n);
    _updateBossUi();
    _updateMission();
    _resetShotRegenTimer();
    powerShotArmed.value = false;
    if (showIntro) {
      _missionCountingEnabled = false;
      _showStageIntro();
    } else {
      _beginMissionCounting();
      blocked = false;
    }
    if (stage.boss) audio.boss();
    persistSession();
  }

  void _resetMissionProgress() {
    final m = stage.mission;
    switch (m.type) {
      case MissionType.order:
        for (final it in m.order) {
          it.have = 0;
        }
      case MissionType.score:
        m.have = 0;
      case MissionType.boss:
        m.hp = m.maxHp;
        bossHpFrac.value = 1;
    }
  }

  void _beginMissionCounting() {
    _missionEpoch++;
    _missionCountingEnabled = true;
  }

  void _addDessert(Dessert d, {bool forMission = true}) {
    d.missionEpoch =
        forMission && _missionCountingEnabled ? _missionEpoch : 0;
    world.add(d);
  }

  bool _countsForMission(Dessert d) =>
      _missionCountingEnabled &&
      d.missionEpoch > 0 &&
      d.missionEpoch == _missionEpoch;

  bool _mergeCountsForMission(Dessert a, Dessert b) =>
      a.isNormal && b.isNormal && _countsForMission(a) && _countsForMission(b);

  void _showStageIntro() {
    _pending.clear();
    _missionCountingEnabled = false;
    _updateMission();
    stageIntro.value = StageIntroInfo(
      stage: stage.stage,
      missionHint: missionHint.value,
      missionProgress: mission.value,
      roll: stage.missionRoll,
      id: _transientId++,
    );
  }

  /// 미션 인트로 연출 종료 — 이 시점부터 미션 진행 집계
  void onStageIntroDismissed() {
    if (status.value != 'playing') return;
    if (bossReward.value != null || bossRoutePending.value != null) return;
    _resetMissionProgress();
    _beginMissionCounting();
    _updateMission();
  }

  void _applyStartBoost() {
    final lvl = store.getPerk('startBoost');
    if (lvl <= 0) return;
    if (_rng.nextDouble() < min(lvl * 0.25, 0.9)) {
      currentSpawn = Spawn.normal(
        SpawnDifficulty.rollTier(_rng, stageNo.value),
        golden: true,
      );
    }
  }

  void _clearBumpers() {
    for (final b in world.children.whereType<BumperComponent>().toList()) {
      b.removeFromParent();
    }
  }

  void _spawnBumpers(int n) {
    _clearBumpers();
    final count = Difficulty.bumperCount(n);
    if (count <= 0) return;
    for (var i = 0; i < count; i++) {
      final x = Bumper.radius + 4 +
          _rng.nextDouble() * (GameConfig.fieldW - 2 * (Bumper.radius + 4));
      final y = Bumper.marginTop +
          _rng.nextDouble() *
              (GameConfig.fieldH - Bumper.marginTop - Bumper.marginBottom);
      world.add(BumperComponent(Vector2(x, y)));
    }
  }

  void _resetUpcoming(int stageNum) {
    _upcomingQueue
      ..clear()
      ..addAll(List.generate(upcomingPreviewCount, (_) => _roll(stageNum)));
    _syncUpcomingEmojis();
  }

  void _syncUpcomingEmojis() {
    upcomingEmojis.value =
        _upcomingQueue.map((s) => s.emoji).toList(growable: false);
    upcomingTiers.value =
        _upcomingQueue.map((s) => s.tier).toList(growable: false);
  }

  void _advanceUpcoming(int stageNum) {
    if (_upcomingQueue.isEmpty) {
      _upcomingQueue.add(_roll(stageNum));
    }
    currentSpawn = _upcomingQueue.removeAt(0);
    _upcomingQueue.add(_roll(stageNum));
    _syncUpcomingEmojis();
  }

  /// 발사 방향·반경 기준 실제 스폰 위치 (가이드·발사 공통)
  Vector2 spawnPosForLaunch(Vector2 dir, double r) {
    var spawnPos = launchPos + dir * (r + 0.55);
    spawnPos.x = spawnPos.x.clamp(r + 0.2, GameConfig.fieldW - r - 0.2);
    spawnPos.y = spawnPos.y.clamp(r + 0.2, GameConfig.fieldH - r - 0.2);

    for (var pass = 0; pass < 8; pass++) {
      var moved = false;
      for (final d in world.children.whereType<Dessert>()) {
        if (!d.isMounted) continue;
        final delta = spawnPos - d.body.position;
        final dist = delta.length;
        final minDist = r + d.radius + 0.1;
        if (dist < minDist) {
          if (dist > 1e-5) {
            spawnPos = d.body.position + delta * (minDist / dist);
          } else {
            spawnPos += dir * 0.2;
          }
          moved = true;
        }
      }
      spawnPos.x = spawnPos.x.clamp(r + 0.2, GameConfig.fieldW - r - 0.2);
      spawnPos.y = spawnPos.y.clamp(r + 0.2, GameConfig.fieldH - r - 0.2);
      if (!moved) break;
    }
    return spawnPos;
  }

  static String tierName(int tier) =>
      kDessertNames[tier.clamp(0, kMaxTier)];

  void _updateMission() {
    if (runMode == GameRunMode.arcade) {
      mission.value = '🎮 ARCADE · Wave $_arcadeWave';
      missionHint.value = 'BEST ${best.value} 도전!';
      wantedSpawnTiers.value = {};
      return;
    }
    final m = stage.mission;
    switch (m.type) {
      case MissionType.order:
        missionHint.value = m.order
            .map((it) =>
                '${tierName(it.tier)}을(를) ${it.need}개 만드세요')
            .join('\n');
        mission.value = m.order
            .map((it) => '${skinEmoji(it.tier)} ${it.have}/${it.need}')
            .join('   ');
        break;
      case MissionType.score:
        missionHint.value = '디저트 합체로 점수를 획득하세요';
        mission.value = '${m.have} / ${m.target}';
        break;
      case MissionType.boss:
        missionHint.value =
            '${tierName(m.weakTier)}(${skinEmoji(m.weakTier)}) 약점 합체로 보스 HP를 깎으세요';
        mission.value = '${m.emoji} BOSS  ${m.hp}/${m.maxHp}';
        break;
    }
    wantedSpawnTiers.value = switch (m.type) {
      MissionType.order => m.order
          .where((it) => it.have < it.need)
          .map((it) => it.tier)
          .toSet(),
      MissionType.boss => {m.weakTier},
      MissionType.score => {},
    };
  }

  void _updateBossUi() {
    if (runMode == GameRunMode.arcade) {
      bossActive.value = false;
      return;
    }
    final m = stage.mission;
    if (m.type == MissionType.boss) {
      bossActive.value = true;
      bossEmoji.value = m.emoji;
      bossHpFrac.value = m.hp / m.maxHp;
      bossWeak.value = '약점 ${skinEmoji(m.weakTier)} ×${Boss.weakMult}';
    } else {
      bossActive.value = false;
    }
  }

  SpawnBias _computeSpawnBias() {
    var tier0Count = 0;
    for (final d in world.children.whereType<Dessert>()) {
      if (d.isMounted && d.isNormal && d.tier == 0) tier0Count++;
    }
    final boost = <int>{};
    if (runMode == GameRunMode.campaign) {
      final m = stage.mission;
      switch (m.type) {
        case MissionType.order:
          for (final o in m.order) {
            if (o.have < o.need) boost.add(o.tier);
          }
        case MissionType.boss:
          boost.add(m.weakTier);
        case MissionType.score:
          break;
      }
    }
    return SpawnBias(
      penalizeTier0: tier0Count >= GameConfig.tier0FieldBiasThreshold,
      boostTiers: boost,
    );
  }

  // ===== 발사 롤 =====
  Spawn _roll(int n) {
    final golden = n >= Golden.fromStage && _rng.nextDouble() < _goldenChance;
    final tier = SpawnDifficulty
        .rollTierBiased(_rng, n, _computeSpawnBias())
        .clamp(0, kMaxTier);
    return Spawn.normal(tier, golden: golden);
  }

  /// 파워샷 아이템 물리 배율 (기본 2× + bombPower 퍼크)
  double get _powerShotItemMult =>
      PowerShot.physicsMult + store.getPerk('bombPower') * 0.2;

  /// 합체 시 파워샷 인벤토리 드롭 (코인 없음)
  bool _tryMergeItemDrop() {
    if (stage.stage < MergeDrop.fromStage) return false;
    if (_rng.nextDouble() >= _mergePowerShotChance) return false;
    store.addInv(PowerShot.id);
    invVersion.value++;
    _showBonus('${PowerShot.emoji} 파워샷 획득!');
    return true;
  }

  // ===== 입력 (드래그로 방향 조준 → 손 떼면 최대 파워 발사) =====
  // MultiTouchDragDetector: 두 번째 손가락이 닿아도 첫 조준 손가락 유지
  /// GameWidget 기준 터치 → 월드 좌표 (HUD 분리 후 global 사용 시 조준 어긋남)
  Vector2 _touchToWorld(Vector2 widgetPos) => screenToWorld(widgetPos);

  @override
  void onDragStart(int pointerId, DragStartInfo info) {
    if (!_canAim) return;
    if (_aimPointerId != null) return;
    _aimPointerId = pointerId;
    _aimFired = false;
    _aimStartClock = _clock;
    _touchPos = _touchToWorld(info.eventPosition.widget);
    _snapAimToTouch();
  }

  @override
  void onDragUpdate(int pointerId, DragUpdateInfo info) {
    if (!_canAim || _aimPointerId != pointerId) return;
    _touchPos = _touchToWorld(info.eventPosition.widget);
  }

  @override
  void onDragEnd(int pointerId, DragEndInfo info) {
    if (_aimPointerId != pointerId) return;
    _snapAimToTouch();
    _finishAim();
  }

  @override
  void onDragCancel(int pointerId) {
    if (_aimPointerId != pointerId) return;
    if (!_aimFired && _touchPos != null && _canFireAfterAim()) {
      _snapAimToTouch();
      _fire();
    }
    _clearAim();
  }

  bool _canFireAfterAim() => _clock - _aimStartClock >= GameConfig.minAimHoldSec;

  void _finishAim() {
    if (!_aimFired && _canFireAfterAim()) _fire();
    _clearAim();
  }

  void _clearAim() {
    _aimPointerId = null;
    _touchPos = null;
    _aimFired = false;
  }

  bool get _canPlay => status.value == 'playing' && !blocked;

  bool get _canAim => _canPlay && _fireCooldownT <= 0;

  /// 터치 → 발사 방향·스폰 (반복 보정 — 가이드·발사 동일)
  ({Vector2 dir, Vector2 spawnPos})? resolveAim({Spawn? spawn}) {
    if (_touchPos == null) return null;
    final s = spawn ?? currentSpawn;
    final r = s.radius;
    var dir = _touchPos! - launchPos;
    if (dir.length < GameConfig.minAimDist) return null;
    dir = dir.normalized();
    var spawnPos = spawnPosForLaunch(dir, r);
    for (var i = 0; i < GameConfig.aimResolveIterations; i++) {
      final toFinger = _touchPos! - spawnPos;
      if (toFinger.length < GameConfig.minAimDist) break;
      dir = toFinger.normalized();
      final next = spawnPosForLaunch(dir, r);
      if ((next - spawnPos).length2 < 0.0001) {
        spawnPos = next;
        break;
      }
      spawnPos = next;
    }
    return (dir: dir, spawnPos: spawnPos);
  }

  Vector2? aimDirFromTouch({Spawn? spawn}) => resolveAim(spawn: spawn)?.dir;

  void _snapAimToTouch() {
    final raw = aimDirFromTouch();
    if (raw != null) _aimDir.setFrom(raw);
  }

  void _updateAim(double dt) {
    if (_touchPos == null) return;
    final target = aimDirFromTouch();
    if (target == null) return;
    if (_aimPointerId != null) {
      _aimDir.setFrom(target);
      return;
    }
    final t = 1 - exp(-GameConfig.aimSmoothing * dt);
    _aimDir.lerp(target, t);
    _aimDir.normalize();
  }

  void _fire() {
    if (!_canPlay || _touchPos == null || shots.value <= 0 || _aimFired) return;
    if (_fireCooldownT > 0) return;
    final aim = resolveAim();
    if (aim == null) return;
    final dir = aim.dir;
    final spawnPos = aim.spawnPos;
    final armed = powerShotArmed.value;
    final speed = launchSpeed * (armed ? PowerShot.speedMult : 1.0);
    final physicsMult =
        armed ? _powerMult * _powerShotItemMult : _powerMult;
    final velocity = dir * speed;
    _activeFireId = ++_fireId;
    _mergesThisFire = 0;

    _addDessert(
      Dessert.fromSpawn(
        currentSpawn,
        spawnPos,
        bullet: true,
        powerShot: armed,
        launchPowerMult: physicsMult,
        initialVelocity: velocity,
        spawnFireId: _activeFireId,
      ),
    );
    if (armed) {
      powerShotArmed.value = false;
      shake(6);
    }
    _aimFired = true;
    _fireCooldownT = GameConfig.fireCooldownSec;
    audio.launch();

    stage.consumeShot();
    _recordShotConsumed();
    shots.value = stage.shots;
    _onBossPlayerShot();
    _advanceUpcoming(stageNo.value);

    if (shots.value <= 0) _graceTimer = GameConfig.graceSec;
    _enforceActiveFieldCap();
  }

  // ===== 충돌 큐 =====
  void onDessertContact(Dessert a, Dessert b) {
    if (!a.canMergeWith(b)) return;

    if (a.isNormal && b.isNormal && a.tier == b.tier) {
      a.merging = true;
      b.merging = true;
      _pending.add(_Pending(_ActionType.merge, a, b));
    }
  }

  void _checkEligibleMerges() {
    final list = world.children
        .whereType<Dessert>()
        .where((d) => d.isMounted && !d.merging)
        .toList();
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        final a = list[i], b = list[j];
        if (!a.canMergeWith(b)) continue;
        if (!a.isNormal || !b.isNormal || a.tier != b.tier) continue;
        final dist = (a.body.position - b.body.position).length;
        if (dist > a.radius + b.radius + 0.08) continue;
        onDessertContact(a, b);
      }
    }
  }

  void onPowerShotImpact(Vector2 pos) {
    _addPopup(ScorePopup(pos..y -= 2, 'POW!', const Color(0xffffd54f)));
    _addBurst(pos, const Color(0xffffd54f), 10);
  }

  @override
  void update(double dt) {
    if (status.value == 'playing' &&
        stage.mission.type == MissionType.boss) {
      _updateBossGimmicks(dt);
    }

    if (!_canPlay) {
      _applyShake(dt, frozen: true);
      return;
    }
    _tickBulletFlight(dt);
    super.update(dt);
    _clock += dt;
    if (_fireCooldownT > 0) {
      _fireCooldownT = max(0, _fireCooldownT - dt);
    }
    _updateAim(dt);
    _updateShotRegen(dt);
    _updateLaunchZoneRelocate(dt);
    _checkEligibleMerges();

    if (_pending.isNotEmpty) {
      final batch = List<_Pending>.from(_pending);
      _pending.clear();
      for (final p in batch) {
        _doMerge(p.a, p.b);
      }
    }

    _applyMagnet();
    _trimExcessEffects();

    if (_graceTimer != null) {
      _graceTimer = _graceTimer! - dt;
      if (_graceTimer! <= 0) _gameOver();
    }

    _applyShake(dt);

    if (_chapterAnchorStage == null &&
        (status.value == 'playing' || status.value == 'over')) {
      _sessionSaveT += dt;
      if (_sessionSaveT >= _sessionSaveInterval) {
        _sessionSaveT = 0;
        persistSession();
      }
    }
  }

  // ===== 합체/폭발/와일드 =====
  void _doMerge(Dessert a, Dessert b) {
    if (!a.isMounted || !b.isMounted) return;
    final mid = (a.body.position + b.body.position)..scale(0.5);
    final golden = a.golden || b.golden;
    final tier = a.tier;
    final precision = a.isNormal &&
        b.isNormal &&
        (a.precisionMerge || b.precisionMerge);
    final countsForMission = _mergeCountsForMission(a, b);
    final fromThisFire =
        a.spawnFireId == _activeFireId || b.spawnFireId == _activeFireId;
    MergeGrade? grade;
    if (fromThisFire) {
      if (_mergesThisFire >= 1) {
        grade = MergeGrade.chain;
      } else {
        final bulletPart = a.bullet ? a : (b.bullet ? b : null);
        if (bulletPart != null &&
            bulletPart.wallHitCount >= GameConfig.bulletMergeMinWallHits) {
          grade = MergeGrade.bank;
        } else {
          grade = MergeGrade.clean;
        }
      }
      _mergesThisFire++;
    }
    final inheritFireId = fromThisFire ? _activeFireId : 0;
    a.removeFromParent();
    b.removeFromParent();
    _produce(
      tier,
      mid,
      golden,
      precision: precision,
      countsForMission: countsForMission,
      grade: grade,
      inheritFireId: inheritFireId,
    );
  }

  void _produce(
    int tier,
    Vector2 pos,
    bool golden, {
    bool precision = false,
    bool countsForMission = false,
    MergeGrade? grade,
    int inheritFireId = 0,
  }) {
    if (_clock - _lastMergeTime < _comboWindow) {
      _combo += 1;
    } else {
      _combo = 1;
    }
    _lastMergeTime = _clock;

    int gained;
    int producedTier = tier;
    if (tier >= kMaxTier) {
      gained = kDesserts[kMaxTier].score * 2;
    } else {
      producedTier = tier + 1;
      gained = kDesserts[producedTier].score;
      _addDessert(
        Dessert(
          kind: DessertKind.normal,
          tier: producedTier,
          spawnPosition: pos.clone(),
          golden: false,
          spawnFireId: inheritFireId,
        ),
        forMission: countsForMission,
      );
      _applyMergeRefund(
        producedTier,
        mult: grade == MergeGrade.bank ? GameConfig.bankRefundMult : 1.0,
      );
    }

    gained *= _combo;
    if (golden) gained *= Golden.scoreMult;
    gained = (gained * _scoreMult).round();
    _addScore(gained);
    final itemDropped = _tryMergeItemDrop();
    if (!itemDropped) _earnCoins(max(1, tier));

    audio.merge(producedTier);
    _addBurst(pos, kDesserts[producedTier.clamp(0, kMaxTier)].color, 10);
    _applyMergeKnockback(pos, producedTier, grade);
    _addPopup(ScorePopup(
        pos, '+$gained', _combo > 1 ? const Color(0xffffd166) : Colors.white));
    if (_combo >= 3) shake(4.0 + _combo.toDouble());

    if (countsForMission) {
      stage.registerMerge(producedTier);
      if (precision && grade == MergeGrade.clean) {
        stage.registerPrecisionMerge(producedTier);
      }
      stage.registerScore(gained);

      if (stage.mission.type == MissionType.boss) {
        final hit = stage.damageBoss(producedTier, grade: grade);
        if (hit != null) {
          audio.bossHit(hit.weak);
          bossHpFrac.value = hit.hp / hit.maxHp;
          if (hit.weak) {
            final style = grade == MergeGrade.chain
                ? 'CHAIN'
                : grade == MergeGrade.bank
                    ? 'BANK'
                    : null;
            final label = style != null
                ? 'WEAK! $style -${hit.damage}'
                : 'WEAK! -${hit.damage}';
            _addPopup(ScorePopup(
                pos..y -= 3, label, const Color(0xffff5d5d)));
            shake(8);
          }
        }
      }
    }
    if (grade != null) {
      if (grade == MergeGrade.bank) {
        store.dailyBump(DailyMissionKind.bankMerge);
      } else if (grade == MergeGrade.chain) {
        store.dailyBump(DailyMissionKind.chainMerge);
      }
      final bonusShots = switch (grade) {
        MergeGrade.clean => GameConfig.precisionShotBonus,
        MergeGrade.bank => GameConfig.bankMergeShotBonus,
        MergeGrade.chain => GameConfig.chainMergeShotBonus,
      };
      if (bonusShots > 0) {
        stage.grantShots(bonusShots);
        shots.value = stage.shots;
      }
      _addPopup(ScorePopup(
          pos..y -= 2.8, grade.label, grade.color, size: 2.4));
      shake(switch (grade) {
        MergeGrade.chain => 6.0,
        MergeGrade.bank => 4.0,
        MergeGrade.clean => 3.0,
      });
    }

    if (shots.value > 0) _graceTimer = null;
    _updateMission();

    final goldenBonus = golden ? Golden.shotBonus : 0;
    final clearing = runMode == GameRunMode.campaign &&
        countsForMission &&
        stage.isCleared();
    if (clearing && !stage.boss) {
      final bonus =
          GameConfig.clearBonus * stage.stage;
      _celebrateMission(stage.mission.type, pos, bonus);
    }
    if (clearing) {
      _stageClear(skipToast: !stage.boss);
    }

    _enforceActiveFieldCap();

    // 스테이지 클리어 직후 shots가 리셋되므로, 황금 보너스는 클리어 처리 후 적용
    if (goldenBonus > 0) {
      stage.grantShots(goldenBonus);
      shots.value = stage.shots;
      _showBonus('+$goldenBonus 🚀');
      if (shots.value > 0) _graceTimer = null;
    }
  }

  void _celebrateMission(MissionType type, Vector2 pos, int bonus) {
    missionClearFlash.value = Transient('clear', _transientId++);
    shake(14);
    final color = switch (type) {
      MissionType.score => const Color(0xff9ad0ec),
      MissionType.order => const Color(0xffb8f5a3),
      MissionType.boss => const Color(0xffff5d5d),
    };
    _addBurst(pos, color, 16);
    _addBurst(Vector2(GameConfig.fieldW / 2, GameConfig.fieldH * 0.45), color, 10);
    final msg = switch (type) {
      MissionType.score => '⭐ 점수 미션 달성!',
      MissionType.order => '✅ 주문 미션 달성!',
      MissionType.boss => '👹 BOSS 격파!',
    };
    _showToast('$msg  +$bonus');
    audio.stageStart();
  }

  void _addScore(int gained) {
    score.value += gained;
    if (score.value > best.value) {
      best.value = score.value;
      store.setBest(score.value);
    }
    _checkArcadeWave();
  }

  void _applyMergeKnockback(Vector2 pos, int producedTier, MergeGrade? grade) {
    final radius = GameConfig.mergeKnockbackRadius;
    final base = GameConfig.mergeKnockbackImpulse * (1 + producedTier * 0.12);
    final mult =
        grade == MergeGrade.chain ? GameConfig.mergeKnockbackChainMult : 1.0;
    for (final d in world.children.whereType<Dessert>()) {
      if (!d.isMounted || d.merging || d.isJunk || d.isBulletInFlight) {
        continue;
      }
      final delta = d.body.position - pos;
      final dist = delta.length;
      if (dist < 1e-4 || dist > radius) continue;
      final falloff = 1 - dist / radius;
      d.body.linearVelocity +=
          delta.normalized() * base * mult * falloff;
      d.body.setAwake(true);
    }
  }

  void _earnCoins(int base) {
    final c = (base * _coinMult).round();
    store.addCoins(c);
    coins.value = store.coins;
  }

  void _addBurst(Vector2 pos, Color color, int count) {
    world.add(burst(pos, color, count));
  }

  void _addPopup(ScorePopup popup) {
    world.add(popup);
    final popups = world.children.whereType<ScorePopup>().toList();
    if (popups.length > GameConfig.maxScorePopups) {
      popups.first.removeFromParent();
    }
  }

  void _trimExcessEffects() {
    final bursts = world.children.whereType<SimpleBurst>().toList();
    if (bursts.length > 6) {
      for (var i = 0; i < bursts.length - 6; i++) {
        bursts[i].removeFromParent();
      }
    }
  }

  /// 플레이 중 필드 디저트 상한 — 물리·메모리 부하 방지
  void _enforceActiveFieldCap() {
    final cap = GameConfig.maxActiveDesserts;
    final onField = world.children
        .whereType<Dessert>()
        .where((d) => d.isMounted && !d.isBulletInFlight)
        .toList();
    if (onField.length <= cap) return;
    onField.sort(
        (a, b) => _fieldTrimPriority(a).compareTo(_fieldTrimPriority(b)));
    for (var i = 0; i < onField.length - cap; i++) {
      onField[i].removeFromParent();
    }
  }

  void _tickBulletFlight(double dt) {
    for (final d in world.children.whereType<Dessert>()) {
      d.tickBulletFlight(dt);
    }
  }

  // ===== 자석 =====
  void _applyMagnet() {
    final lvl = store.getPerk('magnet');
    if (lvl <= 0) return;
    _magnetSkipFrame = !_magnetSkipFrame;
    if (_magnetSkipFrame) return;
    final k = 0.02 * lvl;
    final bodies = world.children
        .whereType<Dessert>()
        .where((d) => d.isNormal && !d.bullet && d.age > 0.35)
        .toList();
    if (bodies.length > 18) return;
    for (var i = 0; i < bodies.length; i++) {
      for (var j = i + 1; j < bodies.length; j++) {
        final a = bodies[i], b = bodies[j];
        if (a.tier != b.tier) continue;
        final pa = a.body.position, pb = b.body.position;
        final dx = pb.x - pa.x, dy = pb.y - pa.y;
        final d = sqrt(dx * dx + dy * dy);
        if (d < 0.1 || d > 12) continue;
        final fx = dx / d * k, fy = dy / d * k;
        a.body.applyForce(Vector2(fx, fy));
        b.body.applyForce(Vector2(-fx, -fy));
      }
    }
  }

  // ===== 보스 기믹 =====
  void _onBossPlayerShot() {
    if (stage.mission.type != MissionType.boss) return;
    if (_bossPendingCast != null) return;
    if (_bossJunkArmed) _bossJunkShots++;
    if (_bossStealArmed) _bossStealShots++;
    if (_bossSmashArmed) _bossSmashShots++;
  }

  BossPattern get _activeBossPattern {
    final pat = stage.mission.bossPattern;
    if (pat != null) return pat;
    return BossPattern.forRound(Boss.roundForStage(stage.stage));
  }

  void _updateBossGimmicks(double dt) {
    if (stage.mission.type != MissionType.boss) return;
    final pat = _activeBossPattern;

    if (_bossPendingCast != null) {
      _bossCastTelegraphT -= dt;
      if (_bossCastTelegraphT <= 0) {
        _executeBossCast(_bossPendingCast!);
        _bossPendingCast = null;
        _bossSmashTarget = null;
      }
      return;
    }

    if (pat.junkEnabled) _bossJunkCd += dt;
    if (pat.stealEnabled) _bossStealCd += dt;
    if (pat.smashEnabled) _bossSmashCd += dt;

    if (pat.junkEnabled &&
        !_bossJunkArmed &&
        _bossJunkCd >= pat.junkInterval) {
      _bossJunkArmed = true;
      _bossJunkShots = 0;
    }
    if (pat.stealEnabled &&
        !_bossStealArmed &&
        _bossStealCd >= pat.stealInterval) {
      _bossStealArmed = true;
      _bossStealShots = 0;
    }
    if (pat.smashEnabled &&
        !_bossSmashArmed &&
        _bossSmashCd >= pat.smashInterval) {
      _bossSmashArmed = true;
      _bossSmashShots = 0;
    }

    if (_bossJunkArmed && _bossJunkShots >= pat.castMinShots) {
      _beginBossCast(_BossGimmickKind.junk);
      return;
    }
    if (_bossStealArmed && _bossStealShots >= pat.castMinShots) {
      _beginBossCast(_BossGimmickKind.steal);
      return;
    }
    if (_bossSmashArmed && _bossSmashShots >= pat.castMinShots) {
      final target = _pickSmashTarget();
      if (target != null) {
        _bossSmashTarget = target;
        _beginBossCast(_BossGimmickKind.smash);
      } else {
        _bossSmashArmed = false;
        _bossSmashShots = 0;
        _bossSmashCd = pat.smashInterval - 3;
      }
    }
  }

  void _beginBossCast(_BossGimmickKind kind) {
    _bossPendingCast = kind;
    _bossCastTelegraphT = Boss.castTelegraphSec;
    final msg = switch (kind) {
      _BossGimmickKind.junk => '👹 🪨 방해물 예고!',
      _BossGimmickKind.steal => '👹 ⚡ 발사 탈취 예고!',
      _BossGimmickKind.smash => '👹 💥 디저트 파괴 예고!',
    };
    _showToast(msg);
  }

  void _executeBossCast(_BossGimmickKind kind) {
    switch (kind) {
      case _BossGimmickKind.junk:
        _spawnJunk(showToast: false);
        _bossJunkCd = 0;
        _bossJunkArmed = false;
        _bossJunkShots = 0;
      case _BossGimmickKind.steal:
        _stealShot();
        _bossStealCd = 0;
        _bossStealArmed = false;
        _bossStealShots = 0;
      case _BossGimmickKind.smash:
        _smashFieldDessert();
        _bossSmashCd = 0;
        _bossSmashArmed = false;
        _bossSmashShots = 0;
    }
  }

  Dessert? _pickSmashTarget() {
    final candidates = world.children
        .whereType<Dessert>()
        .where((d) =>
            d.isNormal &&
            !d.bullet &&
            !d.merging &&
            d.isMounted &&
            d.age > 0.2)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.tier.compareTo(b.tier));
    final pool = candidates.take(min(5, candidates.length)).toList();
    return pool[_rng.nextInt(pool.length)];
  }

  void _smashFieldDessert() {
    final target = _bossSmashTarget;
    if (target == null || !target.isMounted) return;
    final block = min(store.getPerk('shield') * 0.15, 0.6);
    if (block > 0 && _rng.nextDouble() < block) {
      _showBonus('🛡️ 방어!');
      return;
    }
    final pos = target.body.position.clone();
    target.removeFromParent();
    shake(8);
    audio.steal();
    _addBurst(pos, const Color(0xffff5d5d), 12);
    _showToast('💥 디저트 파괴!');
  }

  void _spawnJunk({bool showToast = true}) {
    final junkCount =
        world.children.whereType<Dessert>().where((d) => d.isJunk).length;
    if (junkCount >= Boss.maxJunkOnField) return;
    final x = Junk.radius + 3 +
        _rng.nextDouble() * (GameConfig.fieldW - 2 * (Junk.radius + 3));
    final d = Dessert.fromSpawn(Spawn.junk(), Vector2(x, 11),
        initialVelocity: Vector2((_rng.nextDouble() - 0.5) * 6, 6));
    _addDessert(d, forMission: false);
    shake(4);
    audio.junk();
    if (showToast) _showToast('👹 🪨 방해물!');
  }

  void _stealShot() {
    if (shots.value <= 0) return;
    final block = min(store.getPerk('shield') * 0.2, 0.8);
    if (block > 0 && _rng.nextDouble() < block) {
      _showBonus('🛡️ 방어!');
      return;
    }
    stage.consumeShot();
    _recordShotConsumed();
    shots.value = stage.shots;
    audio.steal();
    shake(6);
    _showBonus('⚡ -1 🚀');
    if (shots.value <= 0) _graceTimer = GameConfig.graceSec;
  }

  // ===== 스테이지 클리어 =====
  void _stageClear({bool skipToast = false}) {
    if (runMode == GameRunMode.arcade) return;
    final clearedStage = stage.stage;
    final wasBoss = stage.boss;
    store.recordStageClear(clearedStage);
    if (wasBoss) {
      store.dailyBump(DailyMissionKind.bossClear);
    } else {
      store.dailyBump(DailyMissionKind.stageClear);
    }

    final bonusScore = GameConfig.clearBonus * clearedStage * (wasBoss ? 3 : 1);
    _addScore(bonusScore);
    _earnCoins(clearedStage * Coins.perStage + (wasBoss ? Coins.bossBonus : 0));
    _combo = 0;
    _graceTimer = null;

    if (!skipToast) {
      if (wasBoss) {
        audio.bossDown();
        _addBurst(Vector2(GameConfig.fieldW / 2, 9), const Color(0xffff5d5d), 14);
        shake(14);
        _showToast('👹 BOSS 격파!  +$bonusScore');
      } else {
        _showToast('STAGE $clearedStage CLEAR!  +$bonusScore');
      }
    } else if (wasBoss) {
      audio.bossDown();
      _addBurst(Vector2(GameConfig.fieldW / 2, 9), const Color(0xffff5d5d), 14);
      shake(14);
    }

    if (wasBoss) {
      _clearJunk();
      _resetBossGimmicks();
      _pendingBossClearStage = clearedStage;
      _pendingBossNextStage = clearedStage + 1;
      currentSpawn = Spawn.normal(0, golden: true);
      _upcomingQueue
        ..clear()
        ..addAll([
          _roll(stageNo.value),
          _roll(stageNo.value),
          _roll(stageNo.value),
        ]);
      _syncUpcomingEmojis();
      _showBossReward(_grantBossPerk(clearedStage), clearedStage: clearedStage);
      return;
    }

    stage.next();
    stageNo.value = stage.stage;
    shots.value = stage.shots;
    _resetStageShotCounter();
    _resetStageRefundCounter();
    _resetShotRegenTimer();
    _resetBossGimmicks();
    currentSpawn = _roll(stage.stage);
    _resetUpcoming(stage.stage);
    audio.startBgm(stage.stage);

    _applyStartBoost();
    _spawnBumpers(stage.stage);
    _updateBossUi();
    _updateMission();
    _trimFieldDesserts();
    _showStageIntro();
  }

  void _clearDesserts() {
    for (final d in world.children.whereType<Dessert>().toList()) {
      d.removeFromParent();
    }
  }

  void _clearJunk() {
    for (final d
        in world.children.whereType<Dessert>().where((d) => d.isJunk).toList()) {
      d.removeFromParent();
    }
  }

  /// 제거 우선순위 (낮을수록 먼저 제거)
  int _fieldTrimPriority(Dessert d) {
    if (d.isJunk) return -10;
    if (d.isNormal) return d.tier;
    return 99;
  }

  /// 스테이지 전환 시 필드 디저트 상한 — 낮은 티어(사탕 등)부터 정리
  void _trimFieldDesserts() {
    final cap = GameConfig.maxFieldDessertsFor(stage.stage);
    final onField =
        world.children.whereType<Dessert>().where((d) => d.isMounted).toList();
    if (onField.length <= cap) return;

    onField.sort(
        (a, b) => _fieldTrimPriority(a).compareTo(_fieldTrimPriority(b)));
    for (var i = 0; i < onField.length - cap; i++) {
      onField[i].removeFromParent();
    }
  }

  // ===== 아케이드 =====
  void resetRunDailyFlag() => _runDailyCounted = false;

  void notifyRunFinished() {
    if (_runDailyCounted) return;
    _runDailyCounted = true;
    store.dailyBump(DailyMissionKind.playRuns);
  }

  void startArcadeRun() {
    runMode = GameRunMode.arcade;
    store.clearGameSession();
    _pendingJumpStage = null;
    _pendingChapterSelect = false;
    _clearDesserts();
    score.value = 0;
    _combo = 0;
    _lastMergeTime = -10;
    _missionEpoch = 0;
    _missionCountingEnabled = true;
    blocked = false;
    bossReward.value = null;
    bossRoutePending.value = null;
    _chapterAnchorStage = null;
    _pendingBossClearStage = null;
    _pendingBossNextStage = null;
    status.value = 'playing';
    _arcadeWave = 1;
    _runDailyCounted = false;
    applyPerks();
    _startArcadeWave();
    audio.startBgm(1);
  }

  void _startArcadeWave() {
    final pseudo = _arcadeWave.clamp(1, 999);
    stageNo.value = _arcadeWave;
    stage.shots = GameConfig.baseShots;
    shots.value = stage.shots;
    _graceTimer = null;
    _resetStageShotCounter();
    _resetStageRefundCounter();
    _resetBossGimmicks();
    currentSpawn = _roll(pseudo);
    _resetUpcoming(pseudo);
    _applyStartBoost();
    _spawnBumpers(pseudo);
    bossActive.value = false;
    mission.value = '🎮 ARCADE · Wave $_arcadeWave';
    missionHint.value = 'BEST ${best.value} 도전!';
    wantedSpawnTiers.value = {};
    powerShotArmed.value = false;
    _resetShotRegenTimer();
  }

  void _checkArcadeWave() {
    if (runMode != GameRunMode.arcade) return;
    final wave = (score.value ~/ GameConfig.arcadeWaveScoreStep) + 1;
    if (wave <= _arcadeWave) return;
    _arcadeWave = wave;
    stageNo.value = _arcadeWave;
    mission.value = '🎮 ARCADE · Wave $_arcadeWave';
    stage.grantShots(GameConfig.arcadeWaveShotBonus);
    shots.value = stage.shots;
    _showBonus(
        'Wave $_arcadeWave! +${GameConfig.arcadeWaveShotBonus} 🚀');
    audio.stageStart();
  }

  // ===== 게임 오버 / 부활 / 재시작 =====
  void _gameOver() {
    _graceTimer = null;
    status.value = 'over';
    audio.gameOver();
  }

  void continueGame() {
    if (status.value != 'over') return;
    showRewardedAd(_resumeAfterAdContinue);
  }

  void _resumeAfterAdContinue() {
    final grant = GameConfig.adContinueShots;
    stage.grantShots(grant);
    status.value = 'playing';
    _graceTimer = null;
    _resetBossGimmicks();
    _touchPos = null;
    _aimFired = false;
    blocked = false;
    shots.value = stage.shots;
    _resetStageShotCounter();
    _showBonus('▶️ +$grant 🚀');
    audio.stageStart();
    persistSession();
  }

  void restart() {
    store.clearGameSession();
    runMode = GameRunMode.campaign;
    _arcadeWave = 1;
    _runDailyCounted = false;
    _pendingJumpStage = null;
    _pendingChapterSelect = false;
    _clearDesserts();
    score.value = 0;
    _combo = 0;
    _lastMergeTime = -10;
    _missionEpoch = 0;
    _missionCountingEnabled = false;
    blocked = false;
    bossReward.value = null;
    bossRoutePending.value = null;
    _chapterAnchorStage = null;
    _pendingBossClearStage = null;
    _pendingBossNextStage = null;
    status.value = 'playing';
    applyPerks();
    _startStage(1);
    audio.startBgm(1);
  }

  /// 현재 세션 기준 클리어한 최고 스테이지 (스테이지 N 플레이 중 → N-1 클리어)
  int get sessionClearedStage =>
      stage.stage > 1 ? stage.stage - 1 : 0;

  /// 메인 복귀 시 클리어 기록 저장 (챕터 점프 세션은 제외)
  void syncProgressToStore() {
    if (runMode == GameRunMode.arcade) return;
    if (_chapterAnchorStage != null) return;
    final cleared = sessionClearedStage;
    if (cleared > 0) store.recordStageClear(cleared);
  }

  /// 진행 중인 판 저장 (앱 재실행 후 이어하기)
  void persistSession() {
    if (_chapterAnchorStage != null) return;
    if (status.value != 'playing' && status.value != 'over') return;
    final cleared = sessionClearedStage;
    if (cleared > 0) store.recordStageClear(cleared);
    store.saveGameSession(_exportSession());
  }

  Future<void> persistSessionAsync() async {
    if (_chapterAnchorStage != null) return;
    if (status.value != 'playing' && status.value != 'over') return;
    final cleared = sessionClearedStage;
    if (cleared > 0) store.recordStageClear(cleared);
    await store.saveGameSession(_exportSession());
  }

  void restoreFromStore() {
    final data = store.loadGameSession();
    if (data == null) {
      _startStage(1);
      audio.startBgm(1);
      return;
    }
    _importSession(data);
  }

  Map<String, dynamic> _exportSession() {
    final desserts = world.children.whereType<Dessert>().where((d) {
      return d.isMounted && !d.isBulletInFlight;
    });
    return {
      'v': 1,
      'runMode': runMode.name,
      'arcadeWave': _arcadeWave,
      'stage': stage.stage,
      'clearedStage': sessionClearedStage,
      'boss': stage.boss,
      'stageShots': stage.shots,
      'score': score.value,
      'status': status.value,
      'shotRegenT': _shotRegenT,
      'powerShotArmed': powerShotArmed.value,
      'currentSpawn': GameSessionSave.spawnToJson(currentSpawn),
      'upcoming': _upcomingQueue.map(GameSessionSave.spawnToJson).toList(),
      'mission': GameSessionSave.missionToJson(stage.mission),
      'desserts': [
        for (final d in desserts)
          {
            'k': d.kind.name,
            't': d.tier,
            'g': d.golden,
            'x': d.body.position.x,
            'y': d.body.position.y,
          },
      ],
    };
  }

  void _importSession(Map<String, dynamic> data) {
    _clearDesserts();
    _pending.clear();
    _graceTimer = null;
    blocked = false;
    bossReward.value = null;
    bossRoutePending.value = null;
    _pendingBossClearStage = null;
    _pendingBossNextStage = null;
    _chapterAnchorStage = null;
    powerShotArmed.value = false;
    _combo = 0;
    _lastMergeTime = -10;
    _fireCooldownT = 0;
    _missionEpoch = 0;
    _missionCountingEnabled = false;

    final savedMode = data['runMode'] as String?;
    runMode = savedMode == null
        ? GameRunMode.campaign
        : GameRunMode.values.byName(savedMode);
    _arcadeWave = (data['arcadeWave'] as num?)?.toInt() ?? 1;

    stage.stage = (data['stage'] as num).toInt();
    stage.boss = data['boss'] as bool? ?? stage.isBossStage(stage.stage);
    stage.shots = (data['stageShots'] as num).toInt();
    stage.mission = GameSessionSave.missionFromJson(
        Map<String, dynamic>.from(data['mission'] as Map));
    if (stage.boss && stage.mission.bossPattern == null) {
      stage.mission.bossPattern =
          BossPattern.forRound(Boss.roundForStage(stage.stage));
    }
    stage.missionRoll = stage.boss
        ? MissionRoll.boss()
        : stage.mission.type == MissionType.score
            ? MissionRoll.score(scoreTarget: stage.mission.target)
            : MissionRoll.order(
                orders: stage.mission.order,
                reelTierPool: stage.mission.order.map((o) => o.tier).toList(),
                resultTier: stage.mission.order.first.tier,
                countPool: [stage.mission.order.first.need],
                resultCount: stage.mission.order.first.need,
              );

    score.value = (data['score'] as num).toInt();
    status.value = data['status'] as String? ?? 'playing';
    if (runMode == GameRunMode.arcade) {
      stageNo.value = _arcadeWave;
      bossActive.value = false;
      mission.value = '🎮 ARCADE · Wave $_arcadeWave';
      missionHint.value = 'BEST ${best.value} 도전!';
      wantedSpawnTiers.value = {};
    } else {
      stageNo.value = stage.stage;
    }
    shots.value = stage.shots;
    _shotRegenT = (data['shotRegenT'] as num?)?.toDouble() ??
        GameConfig.shotRegenSec;
    shotRegenLeft.value = _shotRegenT;
    powerShotArmed.value = data['powerShotArmed'] as bool? ?? false;

    currentSpawn = GameSessionSave.spawnFromJson(
        Map<String, dynamic>.from(data['currentSpawn'] as Map));
    _upcomingQueue
      ..clear()
      ..addAll(
        (data['upcoming'] as List).map(
          (e) => GameSessionSave.spawnFromJson(
              Map<String, dynamic>.from(e as Map)),
        ),
      );
    _syncUpcomingEmojis();

    for (final raw in data['desserts'] as List) {
      final m = raw as Map<String, dynamic>;
      final kind = DessertKind.values.byName(m['k'] as String);
      final tier = (m['t'] as num).toInt();
      final pos = Vector2(
        (m['x'] as num).toDouble(),
        (m['y'] as num).toDouble(),
      );
      _addDessert(
        Dessert(
          kind: kind,
          tier: tier,
          spawnPosition: pos,
          golden: m['g'] as bool? ?? false,
        ),
        forMission: false,
      );
    }

    if (stage.boss) {
      _resetBossGimmicks();
    }
    _spawnBumpers(stage.stage);
    _updateBossUi();
    _updateMission();
    coins.value = store.coins;
    best.value = store.best;
    audio.startBgm(stage.stage);
    _beginMissionCounting();
    blocked = false;
    persistSession();
  }

  int get selectableMaxStage =>
      store.menuSelectableMax(sessionClearedStage);

  void _advanceToStage(int n) {
    stage.start(n);
    stageNo.value = n;
    shots.value = stage.shots;
    _graceTimer = null;
    _resetBossGimmicks();
    currentSpawn = _roll(n);
    _resetUpcoming(n);
    _applyStartBoost();
    _spawnBumpers(n);
    _updateBossUi();
    _updateMission();
    audio.startBgm(n);
    _resetShotRegenTimer();
    _trimFieldDesserts();
    _showStageIntro();
  }
  void jumpToStage(int n, {bool chapterSelect = false}) {
    _clearDesserts();
    _combo = 0;
    _graceTimer = null;
    _resetBossGimmicks();
    _resetStageRefundCounter();
    blocked = false;
    bossReward.value = null;
    bossRoutePending.value = null;
    _pendingBossClearStage = null;
    _pendingBossNextStage = null;
    _chapterAnchorStage = chapterSelect ? n : null;
    if (chapterSelect) store.clearGameSession();
    status.value = 'playing';
    applyPerks();
    _startStage(n.clamp(1, 999), showIntro: true);
    audio.startBgm(stage.stage);
  }

  // ===== 보스 보상 =====
  RewardEntry _grantBossPerk(int clearedStage) {
    final round = BossRewards.bossRound(clearedStage);
    final result = BossRewards.grant(store, round, _rng);
    applyPerks();
    coins.value = store.coins;
    invVersion.value++;

    if (result.isCoin) {
      return RewardEntry.coins(result.coinAmount);
    }
    final p = result.perk!;
    return RewardEntry.perk(
      emoji: p.emoji,
      name: p.name,
      desc: result.skillJump ? '${p.desc} (스킬 획득!)' : p.desc,
      lvl: result.newLevel,
      skillJump: result.skillJump,
    );
  }

  int _lastBossClearStage = 5;

  void _showBossReward(RewardEntry first, {required int clearedStage}) {
    _lastBossClearStage = clearedStage;
    blocked = true;
    bossReward.value = [first];
  }

  void bossRewardWatchAd() {
    showRewardedAd(() {
      final extra = _grantBossPerk(_lastBossClearStage);
      bossReward.value = [...?bossReward.value, extra];
      audio.stageStart();
    });
  }

  void closeBossReward() {
    bossReward.value = null;
    if (_pendingBossClearStage != null) {
      bossRoutePending.value = _pendingBossClearStage;
      return;
    }
    blocked = false;
  }

  /// 보스 격파 후 — 다음 스테이지로 진행
  void confirmBossContinue() {
    final next = _pendingBossNextStage;
    if (next == null) return;
    _pendingBossClearStage = null;
    _pendingBossNextStage = null;
    bossRoutePending.value = null;
    _chapterAnchorStage = null;
    blocked = false;
    _advanceToStage(next);
  }

  /// 보스 격파 후 — 같은 보스 스테이지 반복 (파밍)
  void confirmBossRepeat() {
    final s = _pendingBossClearStage;
    if (s == null) return;
    _pendingBossNextStage = null;
    bossRoutePending.value = null;
    _chapterAnchorStage = s;
    blocked = false;
    _startStage(s, showIntro: true);
    shots.value = stage.shots;
    _trimFieldDesserts();
    audio.startBgm(s);
  }

  // ===== 파워업 / 상점 (UI 호출) =====
  void usePowerup(String type) {
    if (!_canPlay) return;
    if (!store.useInv(type)) return; // UI에서 상점 열기 처리
    if (type == PowerShot.id) {
      powerShotArmed.value = true;
      _showBonus('${PowerShot.emoji} 파워샷!');
    } else if (type == 'shots') {
      stage.grantShots(5);
      shots.value = stage.shots;
      _showBonus('+5 🚀');
    }
    invVersion.value++;
    audio.stageStart();
  }

  bool buyPowerup(String id) {
    final p = kPowerups.firstWhere((e) => e.id == id);
    if (!store.spend(p.cost)) return false;
    store.addInv(id);
    coins.value = store.coins;
    invVersion.value++;
    return true;
  }

  void buyOrSelectSkin(String id) {
    final s = kSkins.firstWhere((e) => e.id == id);
    if (store.hasSkin(id)) {
      store.selectSkin(id);
    } else if (store.spend(s.cost)) {
      store.unlockSkin(id);
      store.selectSkin(id);
      coins.value = store.coins;
    } else {
      return;
    }
    applyCosmetics();
    _syncUpcomingEmojis();
    invVersion.value++;
  }

  void buyOrSelectTheme(String id) {
    final t = kThemes.firstWhere((e) => e.id == id);
    if (store.hasTheme(id)) {
      store.selectTheme(id);
    } else if (store.spend(t.cost)) {
      store.unlockTheme(id);
      store.selectTheme(id);
      coins.value = store.coins;
    } else {
      return;
    }
    applyCosmetics();
    invVersion.value++;
  }

  void watchAdForCoins() {
    showRewardedAd(() {
      store.addCoins(Coins.adReward);
      coins.value = store.coins;
    });
  }

  /// 개발자 테스트 — 보스 영구 아이템(퍼크) 전부 삭제
  void devClearPerks() {
    store.clearPerks();
    applyPerks();
    invVersion.value++;
    _showToast('🛠 보스 아이템 초기화');
  }

  /// 개발자 테스트 — 스코어·코인·인벤·퍼크·진행·이어하기 전부 초기화
  void devResetAll() {
    store.resetAllProgress();
    audio.bgmMuted = false;
    audio.sfxMuted = false;
    restart();
    invVersion.value++;
    _showToast('🛠 전체 초기화 완료');
  }

  /// 개발자 테스트 — 지정 스테이지로 이동
  void devJumpToStage(int n) {
    jumpToStage(n, chapterSelect: true);
    _showToast('🛠 STAGE $n');
  }

  void setShopOpen(bool open) {
    blocked = open;
  }

  void _updateLaunchZoneRelocate(double dt) {
    final r0 = GameConfig.launchZoneRadius;
    for (final d in world.children.whereType<Dessert>().toList()) {
      d.tickRelocateCooldown(dt);
      if (!d.isMounted || d.merging) continue;
      if (!d.isAtRest) continue;
      if (!d.canRelocateFromLaunch) continue;
      final pos = d.body.position;
      if ((pos - launchPos).length > r0) continue;
      final dest = _pickRelocatePos(d.radius, exclude: d);
      if (dest == null) continue;
      d.body.setTransform(dest, 0);
      d.body.linearVelocity.setZero();
      d.body.angularVelocity = 0;
      d.markLaunchRelocated();
    }
  }

  Vector2? _pickRelocatePos(double r, {Dessert? exclude}) {
    const margin = 2.0;
    const tries = 36;
    final minY = margin + r;
    final maxY = GameConfig.fieldH - margin - r;
    final minX = margin + r;
    final maxX = GameConfig.fieldW - margin - r;
    final zoneR = GameConfig.launchZoneRadius + r;

    for (var i = 0; i < tries; i++) {
      final pos = Vector2(
        minX + _rng.nextDouble() * (maxX - minX),
        minY + _rng.nextDouble() * (maxY - minY),
      );
      if ((pos - launchPos).length < zoneR) continue;

      var ok = true;
      for (final other in world.children.whereType<Dessert>()) {
        if (!other.isMounted || identical(other, exclude)) continue;
        if ((pos - other.body.position).length < r + other.radius + 0.12) {
          ok = false;
          break;
        }
      }
      if (ok) return pos;
    }
    return null;
  }

  // ===== 화면 흔들림 / 토스트 =====
  void shake(double px) {
    _shakeMag = max(_shakeMag, px / 10);
    _shakeT = 0.3;
  }

  void _applyShake(double dt, {bool frozen = false}) {
    if (aiming) {
      camera.viewfinder.position = _camBase.clone();
      return;
    }
    if (_shakeT > 0) {
      _shakeT -= dt;
      final m = _shakeMag * (_shakeT / 0.3).clamp(0, 1);
      camera.viewfinder.position = _camBase +
          Vector2((_rng.nextDouble() * 2 - 1) * m, (_rng.nextDouble() * 2 - 1) * m);
    } else {
      camera.viewfinder.position = _camBase.clone();
      _shakeMag = 0;
    }
  }

  void _showToast(String text) {
    toast.value = Transient(text, _transientId++);
  }

  void _showBonus(String text) {
    bonus.value = Transient(text, _transientId++);
  }
}

// ===== 벽 =====
class _Boundaries extends BodyComponent<MergeGame> {
  _Boundaries() : super(renderBody: false);

  @override
  Body createBody() {
    final w = GameConfig.fieldW;
    final h = GameConfig.fieldH;
    final shape = ChainShape()
      ..createLoop([
        Vector2(0, 0),
        Vector2(w, 0),
        Vector2(w, h),
        Vector2(0, h),
      ]);
    final body = world.createBody(BodyDef(type: BodyType.static));
    body.createFixture(FixtureDef(shape, restitution: GameConfig.wallRestitution, friction: 0.0));
    body.userData = fieldWallTag;
    return body;
  }
}

// ===== 조준 가이드 + 발사대 미리보기 =====
class _GuideLayer extends Component {
  _GuideLayer(this.game);
  final MergeGame game;

  @override
  void render(Canvas canvas) {
    final lp = game.launchPos;
    final zoneR = GameConfig.launchZoneRadius;
    canvas.drawCircle(
      lp.toOffset(),
      zoneR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.28,
    );

    if (!game.aiming) {
      Dessert.drawEmoji(canvas, game.currentSpawn.emoji,
          game.currentSpawn.radius * 1.6, lp.toOffset(), opacity: 0.6);
      return;
    }

    final aim = game.resolveAim();
    if (aim == null) return;
    final dir = aim.dir;
    final spawnPos = aim.spawnPos;
    final r = game.currentSpawn.radius;

    Dessert.drawEmoji(canvas, game.currentSpawn.emoji, r * 1.6,
        spawnPos.toOffset(), opacity: 0.85);

    final pts = _predict(spawnPos, dir, r);

    final aimPaint = Paint()
      ..strokeWidth = 0.38
      ..strokeCap = StrokeCap.round;

    if (pts.length >= 2) {
      for (var i = 0; i + 1 < pts.length; i++) {
        final alpha = (0.88 - i * 0.2).clamp(0.28, 0.88);
        aimPaint.color = Colors.white.withValues(alpha: alpha);
        canvas.drawLine(pts[i], pts[i + 1], aimPaint);
      }
      final tip = pts.last;
      final prev = pts[pts.length - 2];
      final seg = Offset(tip.dx - prev.dx, tip.dy - prev.dy);
      final a = atan2(seg.dy, seg.dx);
      const wing = 0.65;
      aimPaint.color = Colors.white.withValues(alpha: 0.9);
      canvas.drawLine(
        tip,
        Offset(tip.dx + cos(a + 2.6) * wing, tip.dy + sin(a + 2.6) * wing),
        aimPaint,
      );
      canvas.drawLine(
        tip,
        Offset(tip.dx + cos(a - 2.6) * wing, tip.dy + sin(a - 2.6) * wing),
        aimPaint,
      );
    } else {
      const guideLen = 10.0;
      final tip = spawnPos + dir * guideLen;
      aimPaint.color = Colors.white.withValues(alpha: 0.75);
      canvas.drawLine(spawnPos.toOffset(), tip.toOffset(), aimPaint);
    }

    if (!game.canFireAfterAimHold) {
      final hold = ((game.clock - game.aimStartClock) /
              GameConfig.minAimHoldSec)
          .clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: spawnPos.toOffset(), radius: r * 1.15),
        -pi / 2,
        pi * 2 * hold,
        false,
        Paint()
          ..color = const Color(0xffffe082).withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.3,
      );
    }
  }

  List<Offset> _predict(Vector2 pos, Vector2 dir, double r) {
    final pts = <Offset>[pos.toOffset()];
    final n = dir.normalized();
    var vx = n.x;
    var vy = n.y;
    const eps = 1e-4;

    for (var bounce = 0; bounce < 3; bounce++) {
      double tMin = double.infinity;
      var reflectX = false;

      if (vx < -1e-9) {
        final t = (r - pos.x) / vx;
        if (t > eps && t < tMin) {
          tMin = t;
          reflectX = true;
        }
      } else if (vx > 1e-9) {
        final t = (GameConfig.fieldW - r - pos.x) / vx;
        if (t > eps && t < tMin) {
          tMin = t;
          reflectX = true;
        }
      }

      if (vy < -1e-9) {
        final t = (r - pos.y) / vy;
        if (t > eps && t < tMin) {
          tMin = t;
          reflectX = false;
        }
      } else if (vy > 1e-9) {
        final t = (GameConfig.fieldH - r - pos.y) / vy;
        if (t > eps && t < tMin) {
          tMin = t;
          reflectX = false;
        }
      }

      if (tMin == double.infinity) break;

      pos = Vector2(pos.x + vx * tMin, pos.y + vy * tMin);
      pts.add(pos.toOffset());

      if (reflectX) {
        vx = -vx;
        pos.x += vx * eps;
      } else {
        vy = -vy;
        pos.y += vy * eps;
      }
    }
    return pts;
  }
}
