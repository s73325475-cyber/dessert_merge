import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'daily_missions.dart';
import 'game_run_mode.dart';

// 코인 / 인벤토리 / 스킨·테마 / 영구 퍼크 영속 저장
class Store {
  Store(this._prefs) {
    _load();
    daily.ensureToday(DateTime.now(), Random());
  }

  final SharedPreferences _prefs;
  SharedPreferences get prefs => _prefs;
  static const _key = 'dbm_store_v1';
  static const _gameKey = 'dbm_game_v1';
  static const _dailyKey = 'dbm_daily_v1';

  int coins = 0;
  int best = 0;
  /// 클리어한 최고 스테이지 (스테이지 선택·보스 파밍)
  int highestStage = 0;
  Map<String, int> inv = {'power': 0, 'shots': 0};
  Set<String> skins = {'default'};
  Set<String> themes = {'default'};
  String skin = 'default';
  String theme = 'default';
  Map<String, int> perks = {};
  bool bgmMuted = false;
  bool sfxMuted = false;
  DailyMissionState daily = DailyMissionState();

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      coins = (m['coins'] ?? 0) as int;
      best = (m['best'] ?? 0) as int;
      highestStage = (m['highestStage'] ?? 0) as int;
      final oldInv = Map<String, dynamic>.from(m['inv'] ?? {});
      inv = {
        'power': ((oldInv['power'] ?? 0) as num).toInt() +
            ((oldInv['bomb'] ?? 0) as num).toInt() +
            ((oldInv['wild'] ?? 0) as num).toInt(),
        'shots': ((oldInv['shots'] ?? 0) as num).toInt(),
      };
      skins = Set<String>.from(m['skins'] ?? ['default']);
      themes = Set<String>.from(m['themes'] ?? ['default']);
      skin = (m['skin'] ?? 'default') as String;
      theme = (m['theme'] ?? 'default') as String;
      perks = Map<String, int>.from(m['perks'] ?? {});
      bgmMuted = m['bgmMuted'] as bool? ?? false;
      sfxMuted = m['sfxMuted'] as bool? ?? false;
    } catch (_) {}
    _loadDaily();
  }

  void _loadDaily() {
    final raw = _prefs.getString(_dailyKey);
    if (raw == null) return;
    try {
      daily = DailyMissionState.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {}
  }

  void _saveDaily() {
    _prefs.setString(_dailyKey, jsonEncode(daily.toJson()));
  }

  void refreshDailyMissions() {
    daily.ensureToday(DateTime.now(), Random());
    _saveDaily();
  }

  void dailyBump(DailyMissionKind kind, [int amount = 1]) {
    daily.ensureToday(DateTime.now(), Random());
    daily.bump(kind, amount);
    _saveDaily();
  }

  int? claimDailyMission(String id) {
    daily.ensureToday(DateTime.now(), Random());
    final reward = daily.claim(id);
    if (reward != null) {
      addCoins(reward);
    } else {
      _saveDaily();
    }
    return reward;
  }

  void saveAudioPrefs() {
    _save();
  }

  void _save() {
    _prefs.setString(
      _key,
      jsonEncode({
        'coins': coins,
        'best': best,
        'highestStage': highestStage,
        'inv': inv,
        'skins': skins.toList(),
        'themes': themes.toList(),
        'skin': skin,
        'theme': theme,
        'perks': perks,
        'bgmMuted': bgmMuted,
        'sfxMuted': sfxMuted,
      }),
    );
  }

  void addCoins(int n) {
    coins += n;
    _save();
  }

  void setBest(int v) {
    if (v > best) {
      best = v;
      _save();
    }
  }

  bool spend(int n) {
    if (coins < n) return false;
    coins -= n;
    _save();
    return true;
  }

  int invCount(String type) => inv[type] ?? 0;
  void addInv(String type, [int n = 1]) {
    inv[type] = (inv[type] ?? 0) + n;
    _save();
  }

  bool useInv(String type) {
    if ((inv[type] ?? 0) <= 0) return false;
    inv[type] = inv[type]! - 1;
    _save();
    return true;
  }

  bool hasSkin(String id) => skins.contains(id);
  void unlockSkin(String id) {
    skins.add(id);
    _save();
  }

  void selectSkin(String id) {
    skin = id;
    _save();
  }

  bool hasTheme(String id) => themes.contains(id);
  void unlockTheme(String id) {
    themes.add(id);
    _save();
  }

  void selectTheme(String id) {
    theme = id;
    _save();
  }

  int getPerk(String id) => perks[id] ?? 0;

  void setPerkLevel(String id, int level) {
    if (level <= 0) {
      perks.remove(id);
    } else {
      perks[id] = level;
    }
    _save();
  }

  void addPerk(String id, [int n = 1]) {
    perks[id] = (perks[id] ?? 0) + n;
    _save();
  }

  void recordStageClear(int stage) {
    if (stage > highestStage) {
      highestStage = stage;
      _save();
    }
  }

  /// 저장된 클리어 기록 + 현재 세션 진행을 합산
  int selectableMaxStage(int sessionCleared) =>
      sessionCleared > highestStage ? sessionCleared : highestStage;

  /// 이어하기 저장에서 클리어 스테이지 추정 (앱 재실행 후 메뉴용)
  int savedSessionClearedStage() {
    final data = loadGameSession();
    if (data == null) return 0;
    final explicit = (data['clearedStage'] as num?)?.toInt();
    if (explicit != null && explicit > 0) return explicit;
    final st = (data['stage'] as num?)?.toInt() ?? 1;
    return st > 1 ? st - 1 : 0;
  }

  /// 메인 메뉴·스테이지 선택에서 사용할 최대 선택 가능 스테이지
  int menuSelectableMax(int sessionCleared) =>
      selectableMaxStage(
          max(sessionCleared, savedSessionClearedStage()));

  void clearPerks() {
    if (perks.isEmpty) return;
    perks.clear();
    _save();
  }

  void clearDailyMissions() {
    daily = DailyMissionState();
    _prefs.remove(_dailyKey);
  }

  bool get hasGameSave => _prefs.getString(_gameKey) != null;

  /// 저장된 판의 모드 (구버전 저장은 캠페인으로 간주)
  GameRunMode? get savedRunMode {
    final data = loadGameSession();
    if (data == null) return null;
    final name = data['runMode'] as String?;
    if (name == null) return GameRunMode.campaign;
    return GameRunMode.values.byName(name);
  }

  Future<void> saveGameSession(Map<String, dynamic> data) async {
    await _prefs.setString(_gameKey, jsonEncode(data));
  }

  Map<String, dynamic>? loadGameSession() {
    final raw = _prefs.getString(_gameKey);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  void clearGameSession() {
    _prefs.remove(_gameKey);
  }

  /// 개발자 — 영속 데이터·이어하기 전부 초기화
  void resetAllProgress() {
    coins = 0;
    best = 0;
    highestStage = 0;
    inv = {'power': 0, 'shots': 0};
    skins = {'default'};
    themes = {'default'};
    skin = 'default';
    theme = 'default';
    perks.clear();
    bgmMuted = false;
    sfxMuted = false;
    clearGameSession();
    _save();
  }
}
