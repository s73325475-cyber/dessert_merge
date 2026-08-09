import 'dart:math';

import 'config.dart';

enum MissionType { order, score, boss }

enum MissionIntroKind { score, order, boss }

/// 스테이지 인트로 룰렛 연출용 (미션은 이미 결정된 상태)
class MissionRoll {
  const MissionRoll.boss()
      : kind = MissionIntroKind.boss,
        orders = null,
        reelTierPool = null,
        resultTier = null,
        countPool = null,
        resultCount = null,
        scoreTarget = null;

  const MissionRoll.score({required this.scoreTarget})
      : kind = MissionIntroKind.score,
        orders = null,
        reelTierPool = null,
        resultTier = null,
        countPool = null,
        resultCount = null;

  const MissionRoll.order({
    required this.orders,
    required this.reelTierPool,
    required this.resultTier,
    required this.countPool,
    required this.resultCount,
  })  : kind = MissionIntroKind.order,
        scoreTarget = null;

  final MissionIntroKind kind;
  final List<OrderItem>? orders;
  final List<int>? reelTierPool;
  final int? resultTier;
  final List<int>? countPool;
  final int? resultCount;
  final int? scoreTarget;

  static const typeSymbols = ['⭐', '🍩'];
  int get typeResultIndex => kind == MissionIntroKind.score ? 0 : 1;
}

class OrderItem {
  OrderItem(this.tier, this.need);
  final int tier;
  final int need;
  int have = 0;
}

class Mission {
  Mission(this.type);
  final MissionType type;
  List<OrderItem> order = [];
  int target = 0;
  int have = 0;
  int hp = 0;
  int maxHp = 0;
  int weakTier = 1;
  String emoji = '👹';
  BossPattern? bossPattern;
}

class BossHit {
  BossHit(this.damage, this.weak, this.hp, this.maxHp);
  final int damage;
  final bool weak;
  final int hp;
  final int maxHp;
}

class StageManager {
  final _rng = Random();

  int stage = 1;
  bool boss = false;
  int shots = 0;
  int bonusStartShots = 0;
  late Mission mission;
  late MissionRoll missionRoll;

  StageManager() {
    reset();
  }

  bool isBossStage(int s) => s % GameConfig.bossEvery == 0;

  void start(int s) {
    stage = s;
    boss = isBossStage(s);
    mission = _buildMission(s, boss);
    shots = GameConfig.baseShots +
        (boss ? GameConfig.bossExtraShots : 0) +
        bonusStartShots;
  }

  Mission _buildMission(int s, bool isBoss) {
    if (isBoss) {
      final m = Mission(MissionType.boss);
      final round = Boss.roundForStage(s);
      m.maxHp = Boss.hpForRound(round);
      m.hp = m.maxHp;
      m.weakTier = 1 + _rng.nextInt(3);
      m.emoji = Boss.emojis[(round - 1) % Boss.emojis.length];
      m.bossPattern = BossPattern.forRound(round);
      missionRoll = MissionRoll.boss();
      return m;
    }

    final pickOrder = _rng.nextBool();

    if (pickOrder) {
      final m = Mission(MissionType.order);
      final maxTier = MissionDifficulty.orderMaxTier(s);
      final tier = 1 + _rng.nextInt(maxTier);
      final need = MissionDifficulty.orderNeed(s);

      m.order = [OrderItem(tier, need)];

      if (_rng.nextDouble() < MissionDifficulty.dualOrderChance(s)) {
        var t2 = 1 + _rng.nextInt(maxTier);
        if (t2 == tier && maxTier > 1) {
          t2 = (tier % maxTier) + 1;
        }
        final need2 = max(1, need - 1);
        m.order.add(OrderItem(t2, need2));
      }

      final tierPool = List.generate(maxTier, (i) => i + 1);
      final countPool = <int>{2, 3, 4, 5, need, need + 1}
          .where((n) => n >= 2 && n <= 6)
          .toList()
        ..sort();

      missionRoll = MissionRoll.order(
        orders: m.order,
        reelTierPool: tierPool,
        resultTier: tier,
        countPool: countPool,
        resultCount: need,
      );
      return m;
    }

    final m = Mission(MissionType.score);
    m.target = MissionDifficulty.scoreTarget(s);
    missionRoll = MissionRoll.score(scoreTarget: m.target);
    return m;
  }

  void consumeShot() {
    shots = max(0, shots - 1);
  }

  /// 합체 환불량 (실제 지급은 MergeGame에서 스테이지 상한 적용)
  int refundAmount(int newTier) => max(0, newTier - 2);

  void grantShots(int n) {
    shots += n;
  }

  BossHit? damageBoss(int tier, {MergeGrade? grade}) {
    if (mission.type != MissionType.boss) return null;
    if (tier != mission.weakTier) return null;
    var dmg = max(1, tier) * Boss.weakMult;
    if (grade == MergeGrade.bank || grade == MergeGrade.chain) {
      dmg = (dmg * GameConfig.bankBossDamageMult).round();
    }
    mission.hp = max(0, mission.hp - dmg);
    return BossHit(dmg, true, mission.hp, mission.maxHp);
  }

  void registerMerge(int producedTier) {
    if (mission.type == MissionType.order) {
      for (final it in mission.order) {
        if (it.tier == producedTier && it.have < it.need) it.have++;
      }
    }
  }

  /// 정밀 샷 합체 — 주문 미션 추가 1카운트
  void registerPrecisionMerge(int producedTier) {
    if (mission.type != MissionType.order) return;
    for (final it in mission.order) {
      if (it.tier == producedTier && it.have < it.need) it.have++;
    }
  }

  void registerScore(int gained) {
    if (mission.type == MissionType.score) mission.have += gained;
  }

  bool isCleared() {
    final m = mission;
    switch (m.type) {
      case MissionType.order:
        return m.order.every((i) => i.have >= i.need);
      case MissionType.score:
        return m.have >= m.target;
      case MissionType.boss:
        return m.hp <= 0;
    }
  }

  void next() => start(stage + 1);
  void reset() => start(1);
}
