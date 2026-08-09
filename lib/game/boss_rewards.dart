import 'dart:math';

import 'config.dart';
import 'store.dart';

/// 보스 격파 보상 결과
class BossGrantResult {
  const BossGrantResult.perk({
    required this.perk,
    required this.newLevel,
    this.skillJump = false,
  })  : isCoin = false,
        coinAmount = 0;

  const BossGrantResult.coins(this.coinAmount)
      : isCoin = true,
        perk = null,
        newLevel = 0,
        skillJump = false;

  final bool isCoin;
  final int coinAmount;
  final PerkSpec? perk;
  final int newLevel;
  /// Lv(R-1)이 아닌 낮은 레벨에서 R단계 보스로 점프 획득
  final bool skillJump;
}

/// 보스 N단계(R) 격파 시 퍼크 보상 (엄격 + 스킬 점프)
class BossRewards {
  BossRewards._();

  static int bossRound(int stage) => stage ~/ GameConfig.bossEvery;

  static BossGrantResult grant(Store store, int bossRound, Random rng) {
    final r = bossRound.clamp(1, 999);

    final strict = kBossPerks
        .where((p) => store.getPerk(p.id) == r - 1)
        .toList(growable: false);
    if (strict.isNotEmpty) {
      final perk = strict[rng.nextInt(strict.length)];
      store.setPerkLevel(perk.id, r);
      return BossGrantResult.perk(perk: perk, newLevel: r);
    }

    final skill = kBossPerks
        .where((p) => store.getPerk(p.id) < r - 1)
        .toList(growable: false);
    if (skill.isNotEmpty) {
      final perk = skill[rng.nextInt(skill.length)];
      store.setPerkLevel(perk.id, r);
      return BossGrantResult.perk(
        perk: perk,
        newLevel: r,
        skillJump: true,
      );
    }

    final coins = Boss.duplicateCoinsForRound(r);
    store.addCoins(coins);
    return BossGrantResult.coins(coins);
  }

  static int countAtLevel(Store store, int level) =>
      kBossPerks.where((p) => store.getPerk(p.id) >= level).length;

  static bool hasAllAtLevel(Store store, int level) =>
      countAtLevel(store, level) >= kBossPerks.length;
}
