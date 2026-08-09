import 'dart:math';

enum DailyMissionKind {
  bankMerge,
  chainMerge,
  bossClear,
  stageClear,
  playRuns,
}

class DailyMissionEntry {
  DailyMissionEntry({
    required this.id,
    required this.kind,
    required this.target,
    required this.coinReward,
    this.progress = 0,
    this.claimed = false,
  });

  final String id;
  final DailyMissionKind kind;
  final int target;
  final int coinReward;
  int progress;
  bool claimed;

  bool get done => progress >= target;
  bool get claimable => done && !claimed;

  String get title => switch (kind) {
        DailyMissionKind.bankMerge => 'BANK 합체 ×$target',
        DailyMissionKind.chainMerge => 'CHAIN 합체 ×$target',
        DailyMissionKind.bossClear => '보스 격파 ×$target',
        DailyMissionKind.stageClear => '스테이지 클리어 ×$target',
        DailyMissionKind.playRuns => '플레이 $target판',
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'target': target,
        'coinReward': coinReward,
        'progress': progress,
        'claimed': claimed,
      };

  factory DailyMissionEntry.fromJson(Map<String, dynamic> j) =>
      DailyMissionEntry(
        id: j['id'] as String,
        kind: DailyMissionKind.values.byName(j['kind'] as String),
        target: (j['target'] as num).toInt(),
        coinReward: (j['coinReward'] as num).toInt(),
        progress: (j['progress'] as num?)?.toInt() ?? 0,
        claimed: j['claimed'] as bool? ?? false,
      );
}

/// 날짜 키 기준 일일 미션 (메인 메뉴)
class DailyMissionState {
  DailyMissionState({this.dateKey = '', List<DailyMissionEntry>? entries})
      : entries = entries ?? [];

  String dateKey;
  List<DailyMissionEntry> entries;

  static String todayKey(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  void ensureToday(DateTime now, Random rng) {
    final key = todayKey(now);
    if (dateKey == key && entries.isNotEmpty) return;
    dateKey = key;
    entries = _roll(rng);
  }

  List<DailyMissionEntry> _roll(Random rng) {
    final pool = <DailyMissionEntry Function()>[
      () => DailyMissionEntry(
            id: 'bank',
            kind: DailyMissionKind.bankMerge,
            target: 2 + rng.nextInt(3),
            coinReward: 25,
          ),
      () => DailyMissionEntry(
            id: 'chain',
            kind: DailyMissionKind.chainMerge,
            target: 1 + rng.nextInt(2),
            coinReward: 35,
          ),
      () => DailyMissionEntry(
            id: 'boss',
            kind: DailyMissionKind.bossClear,
            target: 1,
            coinReward: 45,
          ),
      () => DailyMissionEntry(
            id: 'stage',
            kind: DailyMissionKind.stageClear,
            target: 2 + rng.nextInt(2),
            coinReward: 30,
          ),
      () => DailyMissionEntry(
            id: 'runs',
            kind: DailyMissionKind.playRuns,
            target: 2 + rng.nextInt(2),
            coinReward: 20,
          ),
    ];
    pool.shuffle(rng);
    return pool.take(3).map((f) => f()).toList();
  }

  void bump(DailyMissionKind kind, [int amount = 1]) {
    for (final e in entries) {
      if (e.claimed || e.kind != kind) continue;
      e.progress = min(e.target, e.progress + amount);
    }
  }

  int? claim(String id) {
    for (final e in entries) {
      if (e.id != id || !e.claimable) continue;
      e.claimed = true;
      return e.coinReward;
    }
    return null;
  }

  int get unclaimedCount =>
      entries.where((e) => e.claimable).length;

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory DailyMissionState.fromJson(Map<String, dynamic> j) =>
      DailyMissionState(
        dateKey: j['dateKey'] as String? ?? '',
        entries: (j['entries'] as List? ?? [])
            .map((e) =>
                DailyMissionEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
