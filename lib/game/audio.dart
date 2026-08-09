import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'bgm_composer.dart';
import 'config.dart';
import 'store.dart';

// 합성 사운드(런타임 WAV 생성) 기반 오디오. BGM·효과음 독립 음소거.
class AudioManager {
  AudioManager(this._store) {
    bgmMuted = _store.bgmMuted;
    sfxMuted = _store.sfxMuted;
    _buildSfx();
    _initAudio();
  }

  final Store _store;

  bool bgmMuted = false;
  bool sfxMuted = false;

  static const int _sr = 22050;
  static const double _sfxMaster = 0.42;
  static const double _bgmMaster = 0.52;

  final Map<String, Uint8List> _sfx = {};
  final Map<String, AudioPlayer> _players = {};
  final Map<int, Uint8List> _bgmCache = {};
  AudioPlayer? _bgmPlayer;
  int _bgmTrack = -1;
  bool _bgmPlaying = false;
  bool _audioReady = false;

  Future<void> _initAudio() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
      _bgmPlayer = AudioPlayer();
      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer!.setPlayerMode(PlayerMode.mediaPlayer);
      await _bgmPlayer!.setVolume(_bgmMaster);
      _audioReady = true;
      for (var t = 0; t < 6; t++) {
        _buildBgm(t);
      }
    } catch (_) {}
  }

  Future<void> _ensureReady() async {
    if (!_audioReady) await _initAudio();
  }

  /// 모바일 브라우저 오디오 잠금 해제 (사용자 탭 직후 1회 호출).
  Future<void> unlockForWeb() async {
    await _ensureReady();
    if (sfxMuted) return;
    launch();
  }

  void setBgmMuted(bool m) {
    bgmMuted = m;
    _store.bgmMuted = m;
    _store.saveAudioPrefs();
    if (m) {
      _bgmPlaying = false;
      _bgmPlayer?.pause();
    } else if (_bgmTrack >= 0) {
      _playBgm(_bgmTrack, force: true);
    }
  }

  void setSfxMuted(bool m) {
    sfxMuted = m;
    _store.sfxMuted = m;
    _store.saveAudioPrefs();
  }

  // ===== SFX =====
  void _buildSfx() {
    _sfx['launch'] = _wav(_tone(260, 70, wave: 'square', vol: 0.35));
    _sfx['bumper'] = _wav(_tone(680, 60, wave: 'square', vol: 0.3));
    _sfx['explode'] = _wav(_sweep(220, 60, 260, wave: 'square', vol: 0.45));
    _sfx['boss'] = _wav(_sweep(120, 90, 480, wave: 'sawtooth', vol: 0.4));
    _sfx['bossDown'] = _wav(_sweep(520, 110, 600, wave: 'square', vol: 0.4));
    _sfx['steal'] = _wav(_sweep(520, 90, 220, wave: 'sine', vol: 0.4));
    _sfx['junk'] = _wav(_tone(110, 110, wave: 'sawtooth', vol: 0.4));
    _sfx['gameOver'] =
        _wav(_seq([_n(392, 140), _n(330, 140), _n(262, 260)], 'triangle', 0.4));
    _sfx['stageStart'] =
        _wav(_seq([_n(523, 90), _n(659, 90), _n(784, 160)], 'triangle', 0.4));
    for (var t = 0; t < 5; t++) {
      final f = 330 * pow(1.12, t).toDouble();
      _sfx['merge$t'] = _wav(_tone(f, 90, wave: 'triangle', vol: 0.38));
    }
    _sfx['hit'] = _wav(_tone(440, 70, wave: 'square', vol: 0.4));
    _sfx['hitWeak'] = _wav(_tone(880, 90, wave: 'square', vol: 0.45));
  }

  AudioPlayer _sfxPlayer(String name) {
    return _players.putIfAbsent(name, () {
      final p = AudioPlayer();
      p.setPlayerMode(PlayerMode.lowLatency);
      p.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
      return p;
    });
  }

  void _play(String name, {double volume = 1.0}) {
    if (sfxMuted) return;
    final bytes = _sfx[name];
    if (bytes == null) return;
    try {
      final p = _sfxPlayer(name);
      p.stop();
      p.play(BytesSource(bytes), volume: volume * _sfxMaster);
    } catch (_) {}
  }

  void launch() => _play('launch');
  void merge(int tier) => _play('merge${tier.clamp(0, 4)}');
  void explode() => _play('explode');
  void bumper() => _play('bumper');
  void boss() => _play('boss');
  void bossHit(bool weak) => _play(weak ? 'hitWeak' : 'hit');
  void bossDown() => _play('bossDown');
  void steal() => _play('steal');
  void junk() => _play('junk');
  void stageStart() => _play('stageStart');
  void gameOver() => _play('gameOver');

  // ===== BGM (트랙 0~4 일반 · 5 보스, 각 ~30초 루프) =====
  void startBgm(int stage) {
    final isBoss = stage > 0 && stage % GameConfig.bossEvery == 0;
    final track = isBoss ? 5 : (stage - 1) % 5;
    if (track == _bgmTrack && _bgmPlaying && !bgmMuted) return;
    final changed = track != _bgmTrack;
    _bgmTrack = track;
    if (!bgmMuted) {
      _playBgm(track, force: changed || !_bgmPlaying);
    }
  }

  void stopBgm() {
    _bgmPlaying = false;
    _bgmPlayer?.pause();
    _bgmTrack = -1;
  }

  Future<void> _playBgm(int track, {bool force = false}) async {
    if (bgmMuted) return;
    try {
      await _ensureReady();
      final player = _bgmPlayer;
      if (player == null) return;

      if (!force && _bgmPlaying) {
        await player.resume();
        return;
      }

      await player.stop();
      await player.setVolume(_bgmMaster);
      await player.play(BytesSource(_buildBgm(track)), volume: _bgmMaster);
      _bgmPlaying = true;
    } catch (_) {
      _bgmPlaying = false;
    }
  }

  Uint8List _buildBgm(int track) {
    return _bgmCache.putIfAbsent(track, () {
      final samples = BgmComposer.compose(track, _sr);
      return _wav(samples);
    });
  }

  // ===== 합성 유틸 =====
  List<double> _n(double f, double ms) => [f, ms];

  List<double> _tone(double freq, double ms,
      {String wave = 'sine', double vol = 0.5}) {
    final n = (ms / 1000 * _sr).round();
    final out = List<double>.filled(n, 0);
    final atk = (n * 0.05).round().clamp(1, n);
    final rel = (n * 0.2).round().clamp(1, n);
    for (var i = 0; i < n; i++) {
      final t = i / _sr;
      var s = _osc(wave, freq, t);
      double env = 1;
      if (i < atk) env = i / atk;
      if (i > n - rel) env = (n - i) / rel;
      out[i] = s * vol * env;
    }
    return out;
  }

  List<double> _sweep(double f0, double ms, double f1,
      {String wave = 'sine', double vol = 0.5}) {
    final n = (ms / 1000 * _sr).round();
    final out = List<double>.filled(n, 0);
    final rel = (n * 0.2).round().clamp(1, n);
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final k = i / n;
      final f = f0 + (f1 - f0) * k;
      phase += 2 * pi * f / _sr;
      var s = _oscPhase(wave, phase);
      double env = 1;
      if (i > n - rel) env = (n - i) / rel;
      out[i] = s * vol * env;
    }
    return out;
  }

  List<double> _seq(List<List<double>> notes, String wave, double vol) {
    final out = <double>[];
    for (final nt in notes) {
      out.addAll(_tone(nt[0], nt[1], wave: wave, vol: vol));
    }
    return out;
  }

  double _osc(String wave, double freq, double t) =>
      _oscPhase(wave, 2 * pi * freq * t);

  double _oscPhase(String wave, double phase) {
    final p = phase % (2 * pi);
    switch (wave) {
      case 'square':
        return p < pi ? 1.0 : -1.0;
      case 'sawtooth':
        return (p / pi) - 1.0;
      case 'triangle':
        return p < pi ? (2 * p / pi - 1) : (3 - 2 * p / pi);
      default:
        return sin(p);
    }
  }

  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void s4(int off, String str) {
      for (var i = 0; i < 4; i++) {
        data.setUint8(off + i, str.codeUnitAt(i));
      }
    }

    s4(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    s4(8, 'WAVE');
    s4(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, _sr, Endian.little);
    data.setUint32(28, _sr * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    s4(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (var i = 0; i < n; i++) {
      final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
      data.setInt16(44 + i * 2, v, Endian.little);
    }
    return data.buffer.asUint8List();
  }
}
