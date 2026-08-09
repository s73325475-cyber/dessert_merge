import 'config.dart';
import 'merge_game.dart';

enum DessertKind { normal, junk }

class Spawn {
  final DessertKind kind;
  final int tier;
  final bool golden;

  const Spawn._(this.kind, this.tier, this.golden);

  factory Spawn.normal(int tier, {bool golden = false}) =>
      Spawn._(DessertKind.normal, tier, golden);

  factory Spawn.junk() => const Spawn._(DessertKind.junk, Junk.tier, false);

  String get emoji {
    switch (kind) {
      case DessertKind.junk:
        return Junk.emoji;
      case DessertKind.normal:
        return MergeGame.skinEmoji(tier);
    }
  }

  double get radius {
    switch (kind) {
      case DessertKind.junk:
        return Junk.radius;
      case DessertKind.normal:
        return GameConfig.dessertRadius;
    }
  }
}
