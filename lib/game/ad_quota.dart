import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ad_types.dart';
import 'config.dart';

/// 슬롯별 일일 시청 한도 (한국 날짜 YYYY-MM-DD)
class AdQuota {
  AdQuota(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'dbm_ad_quota_v1';

  String _todayKey() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Map<String, int> _loadDay() {
    final raw = _prefs.getString(_key);
    if (raw == null) return {};
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (map['date'] != _todayKey()) return {};
      final counts = Map<String, dynamic>.from(map['counts'] as Map? ?? {});
      return counts.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  void _saveDay(Map<String, int> counts) {
    _prefs.setString(
      _key,
      jsonEncode({'date': _todayKey(), 'counts': counts}),
    );
  }

  int limitFor(AdPlacement placement) => switch (placement) {
        AdPlacement.continueGame => GameConfig.adDailyContinueLimit,
        AdPlacement.bossExtra => GameConfig.adDailyBossLimit,
        AdPlacement.coins => GameConfig.adDailyCoinsLimit,
      };

  int used(AdPlacement placement) => _loadDay()[placement.debugName] ?? 0;

  int remaining(AdPlacement placement) {
    final left = limitFor(placement) - used(placement);
    return left < 0 ? 0 : left;
  }

  bool canWatch(AdPlacement placement) => remaining(placement) > 0;

  void recordWatch(AdPlacement placement) {
    final counts = _loadDay();
    final key = placement.debugName;
    counts[key] = (counts[key] ?? 0) + 1;
    _saveDay(counts);
  }
}
