// 게임 전역 설정 (웹 config.js 포팅).
// 물리는 Forge2D(미터) 기준, 공간 값은 웹의 픽셀/10 스케일.
import 'dart:math';

import 'package:flutter/material.dart';

class GameConfig {
  static const double fieldW = 42.0;
  static const double fieldH = 64.0;
  static const double launchY = 58.0;

  static const double restitution = 0.63;
  /// 필드 벽 반발 (뱅크샷 — 벽 직접 충돌 +20%)
  static const double wallRestitution = 1.2;
  /// 투사체 비행 중 반발 (디저트·벽 공통 기본)
  static const double bulletFlightRestitution = 0.9;
  /// 벽 / 디저트 첫 충돌 settle 보정 (차이 축소)
  static const double wallContactEffectMult = 1.2;
  static const double dessertContactEffectMult = 0.8;
  /// 디저트 간 충돌 감속 추가 (+30%)
  static const double dessertDecelBoost = 1.3;
  /// 투사체 착지 후(디저트 충돌) 밀치기 — powerMult 퍼크로만 강화
  static const double bulletPowerScale = 0.25;
  static const double friction = 0.02;
  /// 필드 디저트 기본 감쇠
  static const double linearDamping = 0.58;
  /// 발사 직후 — 첫 벽 충돌 전 (약한 공기 저항)
  static const double bulletLinearDamping = 0.04;
  /// 비행 중 Forge2D damping (보조)
  static const double bulletWallFlightDamping = 0.12;
  /// 3뱅크 이후 — 기본 대비 2× 감속
  static const double bulletPostWallFlightDamping = 0.36;
  /// 물리 스텝 전 명시 감속 — 초당 속도 유지율
  static const double bulletFlightRetainPerSec = 0.93;
  /// 3뱅크 이후 — 유지율 2× 감속 (0.88→0.76, 약 24%/초)
  static const double bulletPostWallRetainPerSec = 0.76;
  /// 첫 벽 이후 속도 상한 (launch 대비, grace 이후)
  static const double bulletPostWallSpeedCeilingMult = 0.9;
  /// 벽 감속 면제 횟수 (이후 매 벽 충돌마다 decel)
  static const int bulletWallFreeHits = 3;
  /// 3뱅크 이후 벽 1회당 속도 배율 (2× 감속 → 0.97→0.94)
  static const double bulletWallDecelMult = 0.94;
  /// 첫 충돌 후 감속 — 착지 후 빨리 멈춤
  static const double bulletSettleDamping = 0.72;
  /// 첫 충돌 직후 속도 배율
  static const double bulletSettleSpeedMult = 0.58;
  /// 착지 후 최대 속도 (일반 샷)
  static const double bulletMaxSettleSpeed = 28.0;
  /// 착지 후 sleep 임계 (낮을수록 빨리 정지)
  static const double bulletSleepSpeed = 0.11;

  /// 발사체→디저트 밀치기 (각도 무관, launch × mult)
  static const double dessertPartnerPushMult = 0.34;
  /// 디저트 충돌 후 — 접선(미끄러짐) 유지율
  static const double bulletSettleTangentKeep = 0.82;
  /// 직격(법선만) 시 옆으로 흘러내리는 속도 비율
  static const double bulletSettleHeadOnSlideMult = 0.38;

  /// ⚡ 파워샷 — settle도 동일 비율(×1.5 속도, ÷1.5 damping)
  static const double powerShotSettleDamping = 0.45;
  static const double powerShotSettleSpeedMult = 0.72;
  static const double powerShotMaxSettleSpeed = 38.0;
  static const double powerShotSleepSpeed = 0.08;

  /// 보스 powerMult — 충돌 후 굴러감·밀치기 (발사 속도와 분리)
  static double bulletSettleDampingFor(
    double launchPowerMult, {
    bool powerShot = false,
    bool wallHit = false,
  }) {
    final base =
        powerShot ? powerShotSettleDamping : bulletSettleDamping;
    var d = base / launchPowerMult.clamp(1.0, 2.5);
    if (wallHit) {
      d /= wallContactEffectMult;
    } else {
      d /= dessertContactEffectMult;
      d *= dessertDecelBoost;
    }
    return d;
  }

  static double bulletSettleSpeedMultFor(
    double launchPowerMult, {
    bool powerShot = false,
    bool wallHit = false,
  }) {
    final base =
        powerShot ? powerShotSettleSpeedMult : bulletSettleSpeedMult;
    var m =
        (base + (launchPowerMult - 1) * 0.14).clamp(base, 0.92);
    if (wallHit) {
      m *= wallContactEffectMult;
    } else {
      m *= dessertContactEffectMult;
      // dessertDecelBoost는 damping에만 — 속도 배율 이중 감쇠 방지
    }
    return m;
  }

  static double bulletMaxSettleSpeedFor(
    double launchPowerMult, {
    bool powerShot = false,
    bool wallHit = false,
  }) {
    final mult = bulletSettleSpeedMultFor(
      launchPowerMult,
      powerShot: powerShot,
      wallHit: wallHit,
    );
    final shotSpeed =
        powerShot ? maxLaunchSpeed * PowerShot.speedMult : maxLaunchSpeed;
    final powerScale = launchPowerMult.clamp(1.0, 2.5);
    // settle 목표(launch×mult)와 cap 정합 — 이후 update에서 재감속 방지
    return shotSpeed * powerScale * mult * 1.05;
  }

  /// 착지 후 투사체-디저트 / 투사체-벽 반발 (settle 직후 fixture)
  static double bulletSettleRestitution({
    required bool wallHit,
    required bool powerShot,
  }) {
    final base = bulletFlightRestitution;
    var r = base *
        (wallHit ? wallContactEffectMult : dessertContactEffectMult);
    if (!wallHit) r /= dessertDecelBoost;
    return powerShot ? r.clamp(0.0, 1.05) : r.clamp(0.0, 1.0);
  }

  static double bulletSleepSpeedFor({
    bool powerShot = false,
    bool wallHit = true,
  }) {
    final base = powerShot ? powerShotSleepSpeed : bulletSleepSpeed;
    if (wallHit || powerShot) return base;
    return base * dessertDecelBoost;
  }

  static const double density = 1.0;

  /// 발사 속도 (퍼크와 무관, 고정)
  static const double maxLaunchSpeed = 128.0;
  static const double minAimDist = 0.3;
  /// 연속 발사 방지 쿨다운 (초)
  static const double fireCooldownSec = 0.45;

  static const double comboWindowSec = 2.0;

  static const int baseShots = 8;
  static const int bossExtraShots = 6;
  static const int bossEvery = 5;
  /// 투척 1회 충전 간격 (초)
  static const double shotRegenSec = 90.0;
  /// 스테이지당 합체 환불 상한 (추가 발사)
  static const int maxRefundPerStage = 8;
  static const double graceSec = 2.5;
  static const int clearBonus = 100;

  static const int dangerShots = 3;
  /// 광고 시청 후 게임 오버 부활 — 고정 지급 발사 수
  static const int adContinueShots = 5;

  /// 일일 광고 시청 한도 (슬롯별)
  static const int adDailyContinueLimit = 8;
  static const int adDailyBossLimit = 10;
  static const int adDailyCoinsLimit = 12;

  /// 모든 티어 공통 — 물리·렌더 동일 반경 (조준 혼동 방지)
  static const double dessertRadius = 2.1;

  /// 스테이지별 필드 유지 상한 (초과 시 낮은 티어부터 제거)
  static int maxFieldDessertsFor(int stage) {
    if (stage >= 15) return 15;
    if (stage >= 10) return 12;
    return 9;
  }

  /// 조준 최소 유지 시간 (초)
  static const double minAimHoldSec = 0.22;
  /// 조준 방향 보간 (높을수록 즉시 반응)
  static const double aimSmoothing = 24.0;
  static const int aimResolveIterations = 5;
  /// 정밀 샷(첫 충돌 같은 티어 합체) — Phase1: CLEAN 등급 (보너스 발사 없음)
  static const int precisionShotBonus = 0;
  /// 플레이 중 필드 디저트 상한 (초과 시 낮은 티어 제거)
  static const int maxActiveDesserts = 30;
  static const int maxScorePopups = 8;

  /// bullet 착지 후 같은 티어 합체까지 대기 (초) — 벽 1회+ 시 면제
  static const double bulletMergeDelaySec = 0.15;
  static const int bulletMergeMinWallHits = 1;
  static const double bankRefundMult = 1.25;
  static const double bankBossDamageMult = 1.2;
  /// 합체 넉백
  static const double mergeKnockbackRadius = 8.5;
  static const double mergeKnockbackImpulse = 11.0;
  static const double mergeKnockbackChainMult = 1.4;
  /// 필드 tier0 과다 시 tier0 출현↓
  static const int tier0FieldBiasThreshold = 4;
  static const double tier0SpawnPenalty = 0.30;
  static const double missionTierSpawnBoost = 0.24;
  /// 아케이드 웨이브 (점수 구간)
  static const int arcadeWaveScoreStep = 420;
  static const int arcadeWaveShotBonus = 2;
  static const int bankMergeShotBonus = 1;
  static const int chainMergeShotBonus = 2;
  /// 필드 디저트 정지 판정 / sleep
  static const double fieldRestSpeed = 0.12;
  static const double fieldSleepSpeed = 0.12;
  /// 저속 구간 추가 감쇠 (매 프레임 배율)
  static const double fieldTailDecay = 0.88;

  /// 발사대 보호 원 — 최종 정지 시에만 다른 위치로 이동
  static const double launchZoneRadius = 5.5;
}

/// 미션·주문 난이도 스케일
class MissionDifficulty {
  static int orderMaxTier(int stage) =>
      (1 + stage ~/ 4).clamp(1, kMaxTier);

  static int orderNeed(int stage) {
    final cycle = (stage - 1) ~/ GameConfig.bossEvery;
    return (2 + stage ~/ 6 + cycle).clamp(2, 6);
  }

  static double dualOrderChance(int stage) {
    if (stage < 8) return 0;
    return min(0.25 + stage * 0.018, 0.55);
  }

  static int scoreTarget(int stage) {
    final base = 68 + stage * 28;
    final cycle = (stage - 1) ~/ GameConfig.bossEvery;
    return (base * (1 + cycle * 0.1)).round();
  }
}

/// 스테이지별 발사 롤 (티어 풀)
class SpawnBias {
  const SpawnBias({this.penalizeTier0 = false, this.boostTiers = const {}});
  final bool penalizeTier0;
  final Set<int> boostTiers;
  static const empty = SpawnBias();
}

class SpawnDifficulty {
  static Map<int, double> _baseWeights(int stage) {
    if (stage < 5) return {0: 0.72, 1: 0.28};
    if (stage < 10) return {0: 0.55, 1: 0.30, 2: 0.15};
    if (stage < 15) return {0: 0.42, 1: 0.30, 2: 0.28};
    return {0: 0.32, 1: 0.30, 2: 0.38};
  }

  static int rollTier(Random rng, int stage) =>
      rollTierBiased(rng, stage, SpawnBias.empty);

  static int rollTierBiased(Random rng, int stage, SpawnBias bias) {
    final weights = Map<int, double>.from(_baseWeights(stage));
    if (bias.penalizeTier0 && weights.containsKey(0)) {
      weights[0] =
          (weights[0]! * (1 - GameConfig.tier0SpawnPenalty)).clamp(0.08, 1.0);
    }
    for (final tier in bias.boostTiers) {
      if (weights.containsKey(tier)) {
        weights[tier] = weights[tier]! + GameConfig.missionTierSpawnBoost;
      }
    }
    final total = weights.values.fold<double>(0, (a, b) => a + b);
    var r = rng.nextDouble() * total;
    for (final e in weights.entries) {
      r -= e.value;
      if (r <= 0) return e.key;
    }
    return weights.keys.last;
  }
}

class DessertSpec {
  final int tier;
  final String emoji;
  final double radius;
  final int score;
  final Color color;
  const DessertSpec(this.tier, this.emoji, this.radius, this.score, this.color);
}

const List<DessertSpec> kDesserts = [
  DessertSpec(0, '🍬', GameConfig.dessertRadius, 1, Color(0xffff8fb1)),
  DessertSpec(1, '🍪', GameConfig.dessertRadius, 3, Color(0xffd9a566)),
  DessertSpec(2, '🍩', GameConfig.dessertRadius, 6, Color(0xfff0a6c0)),
  DessertSpec(3, '🧁', GameConfig.dessertRadius, 12, Color(0xff9ad0ec)),
  DessertSpec(4, '🍰', GameConfig.dessertRadius, 30, Color(0xffffd6a5)),
];

const int kMaxTier = 4;
const List<int> kSpawnableTiers = [0, 1];

/// 합체 등급 — 당구 실력에 따른 보상 차등
enum MergeGrade {
  clean,
  bank,
  chain;

  String get label => switch (this) {
        MergeGrade.clean => 'CLEAN!',
        MergeGrade.bank => 'BANK!',
        MergeGrade.chain => 'CHAIN!',
      };

  Color get color => switch (this) {
        MergeGrade.clean => const Color(0xff80cbc4),
        MergeGrade.bank => const Color(0xff9ad0ec),
        MergeGrade.chain => const Color(0xffffd166),
      };
}

/// 디저트 티어 한글 이름 (미션 설명용)
const List<String> kDessertNames = ['사탕', '쿠키', '도넛', '컵케이크', '케이크'];

/// 합체 시 인벤토리 아이템 드롭 (필드 스폰·코인 보상 없음)
class MergeDrop {
  static const double powerShotChance = 0.055;
  static const int fromStage = 2;
}

/// 필드 벽 userData — Forge2D가 상대 userData 없을 때 contact 콜백을 전파하지 않음
class FieldWallTag {
  const FieldWallTag();
}

const fieldWallTag = FieldWallTag();

// 범퍼 — 디저트·벽과 동일 계열 (에너지 증폭 restitution>1 제거)
class Bumper {
  static const String emoji = '🍥';
  static const double radius = 1.6;
  /// 디저트 restitution과 동일 (1.04 등 >1 값 금지)
  static double get restitution => GameConfig.restitution;
  /// 접촉 후 속도 유지율 (디저트 간 감속과 동일)
  static double get contactSpeedRetain =>
      GameConfig.dessertContactEffectMult / GameConfig.dessertDecelBoost;
  static const int fromStage = 2;
  static const int maxCount = 1;
  static const double marginTop = 18.0;
  static const double marginBottom = 20.0;
}

/// 스테이지 난이도 (서서히 상승, 보스 사이클마다 완만하게만 증가)
class Difficulty {
  /// 1단계 보스(5) 클리어 후 ~ 2단계 보스(10) 전: Lv1 풀셋 기준 난이도
  static bool isPostFirstBossTier(int stage) =>
      stage > GameConfig.bossEvery && stage < GameConfig.bossEvery * 2;

  static int bumperCount(int stage) {
    if (stage < Bumper.fromStage) return 0;
    final steps = stage - Bumper.fromStage;
    final cycles = (stage - 1) ~/ GameConfig.bossEvery;
    var count = 1 + steps ~/ 4 + cycles ~/ 2;
    if (isPostFirstBossTier(stage)) count += 1;
    return count.clamp(1, Bumper.maxCount);
  }
}

// 파워샷 (인벤 → 다음 1발 물리 2배)
class PowerShot {
  static const String id = 'power';
  static const String emoji = '⚡';
  static const int shopCost = 50;
  static const double speedMult = 2.0;
  static const double physicsMult = 2.0;
}

// 황금
class Golden {
  static const String emoji = '✨';
  static const double chance = 0.09;
  static const int fromStage = 2;
  static const int scoreMult = 2;
  static const int shotBonus = 1;
}

// 잡동사니(보스 기믹)
class Junk {
  static const int tier = -3;
  static const String emoji = '🪨';
  static const double radius = 1.8;
}

// 보스
class BossPattern {
  const BossPattern({
    required this.junkEnabled,
    required this.stealEnabled,
    required this.smashEnabled,
    required this.junkInterval,
    required this.stealInterval,
    required this.smashInterval,
    required this.castMinShots,
  });

  final bool junkEnabled;
  final bool stealEnabled;
  final bool smashEnabled;
  final double junkInterval;
  final double stealInterval;
  final double smashInterval;
  final int castMinShots;

  static BossPattern forRound(int round) => switch (round) {
        1 => const BossPattern(
              junkEnabled: true,
              stealEnabled: false,
              smashEnabled: false,
              junkInterval: 12.0,
              stealInterval: 99.0,
              smashInterval: 99.0,
              castMinShots: 3,
            ),
        2 => const BossPattern(
              junkEnabled: true,
              stealEnabled: true,
              smashEnabled: false,
              junkInterval: 10.0,
              stealInterval: 18.0,
              smashInterval: 99.0,
              castMinShots: 3,
            ),
        3 => const BossPattern(
              junkEnabled: true,
              stealEnabled: true,
              smashEnabled: true,
              junkInterval: 9.0,
              stealInterval: 14.0,
              smashInterval: 20.0,
              castMinShots: 3,
            ),
        _ => const BossPattern(
              junkEnabled: true,
              stealEnabled: true,
              smashEnabled: true,
              junkInterval: 7.5,
              stealInterval: 11.0,
              smashInterval: 16.0,
              castMinShots: 2,
            ),
      };
}

class Boss {
  static const int baseHp = 11;
  static const int hpPerStage = 1;
  static const int weakMult = 3;
  static const double junkIntervalSec = 10.0;
  static const double stealIntervalSec = 15.0;
  static const double smashIntervalSec = 22.0;
  static const double castTelegraphSec = 1.2;
  static const int castMinShots = 3;
  static const int maxJunkOnField = 2;
  static const int duplicatePerkCoinsBase = 30;
  static const List<String> emojis = ['👹', '👾', '😈', '🐲', '🤖'];

  static int roundForStage(int stage) =>
      (stage / GameConfig.bossEvery).floor().clamp(1, 999);

  /// 보스 단계별 HP (1단계=12, 2단계=18 …)
  static int hpForRound(int round) {
    return switch (round) {
      1 => 12,
      2 => 18,
      3 => 24,
      4 => 30,
      _ => 12 + (round - 1) * 6,
    };
  }

  static int duplicateCoinsForRound(int round) =>
      duplicatePerkCoinsBase * round;
}

// 보스 영구 아이템(퍼크)
class PerkSpec {
  final String id;
  final String emoji;
  final String name;
  final String desc;
  const PerkSpec(this.id, this.emoji, this.name, this.desc);
}

const List<PerkSpec> kBossPerks = [
  PerkSpec('startShots', '🚀', '발사 +1', '스테이지 시작 발사 횟수 +1'),
  PerkSpec('powerMult', '💪', '파워 +10%', '충돌 후 밀치기·굴러감 +10% (중첩)'),
  PerkSpec('coinMult', '🪙', '코인 +20%', '코인 획득량 +20%'),
  PerkSpec('scoreMult', '⭐', '점수 +10%', '합체 점수 +10%'),
  PerkSpec('golden', '✨', '황금 +3%', '황금 디저트 등장 확률 +3%'),
  PerkSpec('magnet', '🧲', '자석', '같은 디저트끼리 서로 끌어당김'),
  PerkSpec('bombPower', '⚡', '파워샷 +20%', '파워샷 물리 배율 +20% (중첩)'),
  PerkSpec('shield', '🛡️', '방어막', '보스의 발사 차감 20% 확률 무효(중첩)'),
  PerkSpec('refund', '🎯', '환불 강화', '고티어 합체 시 발사 +1 추가 환불'),
  PerkSpec('startBoost', '⏳', '시작 부스트', '스테이지 첫 발사체 황금 디저트 확률 +25%'),
  PerkSpec('luck', '🍀', '파워샷 +1%', '합체 시 파워샷(⚡) 획득 확률 +1%'),
  PerkSpec('comboHold', '🔁', '콤보 유지', '콤보 유지 시간 +0.4초'),
];

// 코인
class Coins {
  static const int perStage = 3;
  static const int bossBonus = 30;
  static const int adReward = 50;
}

// 파워업
class PowerupSpec {
  final String id;
  final String emoji;
  final int cost;
  final String label;
  final int amount;
  const PowerupSpec(this.id, this.emoji, this.cost, this.label,
      {this.amount = 0});
}

const List<PowerupSpec> kPowerups = [
  PowerupSpec(PowerShot.id, PowerShot.emoji, PowerShot.shopCost, '파워샷'),
  PowerupSpec('shots', '🚀', 30, '발사 +5', amount: 5),
];

// 스킨
class SkinSpec {
  final String id;
  final String name;
  final int cost;
  final List<String> emojis;
  const SkinSpec(this.id, this.name, this.cost, this.emojis);
}

const List<SkinSpec> kSkins = [
  SkinSpec('default', '기본', 0, ['🍬', '🍪', '🍩', '🧁', '🍰']),
  SkinSpec('fruit', '과일', 150, ['🍓', '🍒', '🍑', '🍍', '🍉']),
  SkinSpec('animal', '애니멀', 250, ['🐣', '🐰', '🐱', '🐼', '🦄']),
];

// 테마 (배경 그라데이션)
class ThemeSpec {
  final String id;
  final String name;
  final int cost;
  final Color top;
  final Color bottom;
  const ThemeSpec(this.id, this.name, this.cost, this.top, this.bottom);
}

const List<ThemeSpec> kThemes = [
  ThemeSpec('default', '퍼플', 0, Color(0xff3b2a52), Color(0xff2c1f43)),
  ThemeSpec('ocean', '오션', 120, Color(0xff1e3a5f), Color(0xff0f2238)),
  ThemeSpec('sunset', '선셋', 120, Color(0xff5f2a3a), Color(0xff3a1f2c)),
  ThemeSpec('mint', '민트', 200, Color(0xff1f4f43), Color(0xff0f2d26)),
];
