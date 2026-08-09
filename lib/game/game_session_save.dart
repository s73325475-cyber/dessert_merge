import 'stage.dart';
import 'spawn.dart';

/// 진행 중인 판 저장/복원 직렬화
class GameSessionSave {
  GameSessionSave._();

  static Map<String, dynamic> spawnToJson(Spawn s) => {
        'k': s.kind.name,
        't': s.tier,
        'g': s.golden,
      };

  static Spawn spawnFromJson(Map<String, dynamic> m) {
    final kind = DessertKind.values.byName(m['k'] as String);
    final tier = (m['t'] as num).toInt();
    final golden = m['g'] as bool? ?? false;
    return switch (kind) {
      DessertKind.junk => Spawn.junk(),
      DessertKind.normal => Spawn.normal(tier, golden: golden),
    };
  }

  static Map<String, dynamic> missionToJson(Mission m) => {
        'type': m.type.name,
        'order': m.order
            .map((o) => {'tier': o.tier, 'need': o.need, 'have': o.have})
            .toList(),
        'target': m.target,
        'have': m.have,
        'hp': m.hp,
        'maxHp': m.maxHp,
        'weakTier': m.weakTier,
        'emoji': m.emoji,
      };

  static Mission missionFromJson(Map<String, dynamic> j) {
    final type = MissionType.values.byName(j['type'] as String);
    final m = Mission(type);
    applyMission(m, j);
    return m;
  }

  static void applyMission(Mission m, Map<String, dynamic> j) {
    m.order = (j['order'] as List)
        .map((e) {
          final o = e as Map<String, dynamic>;
          final item = OrderItem(
            (o['tier'] as num).toInt(),
            (o['need'] as num).toInt(),
          );
          item.have = (o['have'] as num).toInt();
          return item;
        })
        .toList();
    m.target = (j['target'] as num?)?.toInt() ?? 0;
    m.have = (j['have'] as num?)?.toInt() ?? 0;
    m.hp = (j['hp'] as num?)?.toInt() ?? 0;
    m.maxHp = (j['maxHp'] as num?)?.toInt() ?? 0;
    m.weakTier = (j['weakTier'] as num?)?.toInt() ?? 1;
    m.emoji = j['emoji'] as String? ?? '👹';
  }
}
