import 'dart:math';

/// 런타임 합성 BGM — 트랙 0~4 일반(약 30초), 5 보스(비장한 분위기)
class BgmComposer {
  BgmComposer._();

  static const targetDurationSec = 30.0;

  static List<double> compose(int track, int sampleRate) {
    return switch (track) {
      0 => _cafeCheer(sampleRate),
      1 => _playfulBounce(sampleRate),
      2 => _cozyWarm(sampleRate),
      3 => _mysteryCandy(sampleRate),
      4 => _sweetRush(sampleRate),
      5 => _bossEpic(sampleRate),
      _ => _cafeCheer(sampleRate),
    };
  }

  // ── 트랙 0: 밝은 카페 분위기 (C major, 120 BPM) ──
  static List<double> _cafeCheer(int sr) {
    const bpm = 120.0;
    const bars = 16;
    const roots = [60, 67, 69, 65, 60, 65, 67, 64, 69, 65, 60, 67, 64, 65, 60, 60];
    final melody = [
      72, 0, 74, 0, 76, 74, 72, 0,
      69, 0, 72, 0, 74, 0, 76, 74,
      77, 0, 76, 0, 74, 72, 69, 0,
      72, 0, 74, 76, 77, 76, 74, 72,
      76, 0, 77, 0, 79, 0, 77, 76,
      74, 0, 72, 0, 69, 0, 67, 0,
      69, 72, 74, 76, 74, 72, 69, 67,
      72, 0, 76, 0, 79, 77, 76, 72,
    ];
    return _render(
      sr: sr,
      bpm: bpm,
      bars: bars,
      roots: roots,
      melody: melody,
      bassWave: 'triangle',
      bassVol: 0.14,
      arpWave: 'sine',
      arpVol: 0.07,
      melWave: 'triangle',
      melVol: 0.11,
      kickVol: 0.06,
      hihatVol: 0.025,
    );
  }

  // ── 트랙 1: 통통 튀는 플레이풀 (G major, 128 BPM) ──
  static List<double> _playfulBounce(int sr) {
    const bpm = 128.0;
    const bars = 16;
    const roots = [55, 62, 59, 57, 55, 57, 59, 62, 55, 59, 62, 57, 55, 57, 59, 55];
    final melody = [
      67, 0, 67, 69, 0, 71, 69, 67,
      0, 66, 0, 67, 0, 69, 71, 0,
      74, 0, 74, 76, 0, 74, 72, 0,
      71, 69, 67, 0, 66, 67, 69, 0,
      79, 0, 77, 0, 76, 74, 72, 0,
      71, 0, 69, 0, 67, 66, 67, 0,
      69, 71, 74, 76, 74, 71, 69, 67,
      71, 0, 74, 0, 76, 74, 71, 67,
    ];
    return _render(
      sr: sr,
      bpm: bpm,
      bars: bars,
      roots: roots,
      melody: melody,
      bassWave: 'square',
      bassVol: 0.08,
      arpWave: 'triangle',
      arpVol: 0.09,
      melWave: 'square',
      melVol: 0.07,
      melStaccato: true,
      kickVol: 0.08,
      hihatVol: 0.035,
    );
  }

  // ── 트랙 2: 아늑한 오후 (F major, 92 BPM) ──
  static List<double> _cozyWarm(int sr) {
    const bpm = 92.0;
    const bars = 12;
    const roots = [53, 60, 55, 57, 53, 55, 60, 57, 55, 53, 60, 53];
    final melody = [
      65, 0, 0, 67, 69, 0, 67, 65,
      0, 62, 0, 65, 0, 0, 67, 69,
      72, 0, 0, 74, 72, 0, 69, 67,
      0, 65, 0, 0, 62, 65, 0, 0,
      69, 0, 67, 65, 0, 62, 0, 65,
      0, 69, 72, 0, 74, 72, 69, 67,
    ];
    return _render(
      sr: sr,
      bpm: bpm,
      bars: bars,
      roots: roots,
      melody: melody,
      bassWave: 'sine',
      bassVol: 0.16,
      arpWave: 'sine',
      arpVol: 0.06,
      melWave: 'sine',
      melVol: 0.13,
      padWave: 'sine',
      padVol: 0.05,
      kickVol: 0.04,
      hihatVol: 0.015,
      soft: true,
    );
  }

  // ── 트랙 3: 몽환적 캔디 (A minor, 108 BPM) ──
  static List<double> _mysteryCandy(int sr) {
    const bpm = 108.0;
    const bars = 14;
    const roots = [57, 53, 55, 52, 57, 53, 50, 52, 57, 55, 53, 52, 55, 57];
    final melody = [
      69, 0, 72, 0, 74, 72, 69, 0,
      67, 0, 0, 69, 72, 0, 74, 76,
      74, 0, 72, 69, 0, 67, 0, 69,
      72, 74, 76, 74, 72, 69, 67, 0,
      76, 0, 74, 0, 72, 0, 69, 0,
      72, 74, 76, 77, 76, 74, 72, 69,
      0, 69, 72, 74, 72, 69, 67, 0,
      69, 0, 72, 74, 76, 74, 72, 69,
    ];
    return _render(
      sr: sr,
      bpm: bpm,
      bars: bars,
      roots: roots,
      melody: melody,
      bassWave: 'triangle',
      bassVol: 0.12,
      arpWave: 'triangle',
      arpVol: 0.06,
      melWave: 'sine',
      melVol: 0.12,
      padWave: 'triangle',
      padVol: 0.04,
      echoMix: 0.22,
      kickVol: 0.05,
      hihatVol: 0.02,
    );
  }

  // ── 트랙 4: 달콤한 러시 (E major, 138 BPM) ──
  static List<double> _sweetRush(int sr) {
    const bpm = 138.0;
    const bars = 16;
    const roots = [52, 59, 56, 54, 52, 54, 56, 59, 52, 56, 59, 54, 52, 54, 56, 52];
    final melody = [
      64, 68, 71, 0, 73, 71, 68, 64,
      66, 68, 71, 73, 76, 73, 71, 68,
      76, 0, 73, 71, 0, 68, 71, 73,
      76, 78, 76, 73, 71, 68, 66, 64,
      71, 73, 76, 78, 80, 78, 76, 73,
      71, 0, 68, 0, 64, 66, 68, 71,
      73, 76, 78, 76, 73, 71, 68, 64,
      68, 71, 73, 76, 73, 71, 68, 64,
    ];
    return _render(
      sr: sr,
      bpm: bpm,
      bars: bars,
      roots: roots,
      melody: melody,
      bassWave: 'square',
      bassVol: 0.1,
      arpWave: 'square',
      arpVol: 0.05,
      melWave: 'triangle',
      melVol: 0.1,
      kickVol: 0.09,
      hihatVol: 0.04,
    );
  }

  // ── 트랙 5: 보스 — 비장·영웅적 (D minor, 88 BPM) ──
  static List<double> _bossEpic(int sr) {
    const bpm = 88.0;
    const bars = 12;
    const roots = [50, 57, 55, 53, 50, 53, 55, 57, 50, 55, 57, 50];
    final melody = [
      62, 0, 65, 0, 69, 67, 65, 62,
      0, 60, 0, 62, 65, 67, 69, 72,
      74, 0, 72, 69, 67, 65, 62, 0,
      65, 67, 69, 72, 74, 72, 69, 65,
      69, 0, 72, 0, 74, 72, 69, 67,
      65, 62, 60, 62, 65, 67, 69, 72,
    ];
    final out = _render(
      sr: sr,
      bpm: bpm,
      bars: bars,
      roots: roots,
      melody: melody,
      bassWave: 'sawtooth',
      bassVol: 0.11,
      arpWave: 'sawtooth',
      arpVol: 0.04,
      melWave: 'sawtooth',
      melVol: 0.09,
      padWave: 'triangle',
      padVol: 0.06,
      brassWave: 'square',
      brassVol: 0.05,
      kickVol: 0.12,
      snareVol: 0.07,
      hihatVol: 0.025,
      dark: true,
    );
    return _padToDuration(out, sr, targetDurationSec);
  }

  // ── 렌더링 엔진 ──

  static List<double> _render({
    required int sr,
    required double bpm,
    required int bars,
    required List<int> roots,
    required List<int> melody,
    String bassWave = 'triangle',
    double bassVol = 0.12,
    String arpWave = 'triangle',
    double arpVol = 0.08,
    String melWave = 'triangle',
    double melVol = 0.1,
    String? padWave,
    double padVol = 0.0,
    String? brassWave,
    double brassVol = 0.0,
    bool melStaccato = false,
    bool soft = false,
    bool dark = false,
    double echoMix = 0.0,
    double kickVol = 0.06,
    double snareVol = 0.0,
    double hihatVol = 0.02,
  }) {
    final beatSec = 60.0 / bpm;
    final barSec = beatSec * 4;
    final totalSec = barSec * bars;
    final totalSamples = (totalSec * sr).round();
    final out = List<double>.filled(totalSamples, 0);

    final eighthSec = beatSec / 2;
    final eighthSamples = (eighthSec * sr).round();

    for (var bar = 0; bar < bars; bar++) {
      final root = roots[bar % roots.length];
      final barStart = (bar * barSec * sr).round();
      final chord = [root, root + 4, root + 7, root + 12];

      // 베이스 — 1·3박
      for (final beat in [0.0, 2.0]) {
        final start = barStart + (beat * beatSec * sr).round();
        _inject(
          out,
          start,
          _note(_midi(root - 12), beatSec * 1.8, sr,
              wave: bassWave, vol: bassVol, soft: soft),
        );
      }

      // 패드 — 마디 전체 화음
      if (padWave != null && padVol > 0) {
        for (final n in [root, root + 4, root + 7]) {
          _inject(
            out,
            barStart,
            _note(_midi(n), barSec * 0.95, sr,
                wave: padWave, vol: padVol, soft: true),
          );
        }
      }

      // 브라스 — 보스용 장음
      if (brassWave != null && brassVol > 0 && bar % 2 == 0) {
        _inject(
          out,
          barStart,
          _note(_midi(root + 12), barSec * 0.9, sr,
              wave: brassWave, vol: brassVol, soft: false),
        );
      }

      // 아르페지오 — 8분음
      for (var e = 0; e < 8; e++) {
        final n = chord[e % chord.length];
        final start = barStart + e * eighthSamples;
        _inject(
          out,
          start,
          _note(_midi(n), eighthSec * 0.85, sr,
              wave: arpWave, vol: arpVol, soft: soft),
        );
      }

      // 멜로디 — 8분음표 그리드
      for (var e = 0; e < 8; e++) {
        final idx = bar * 8 + e;
        if (idx >= melody.length) break;
        final note = melody[idx];
        if (note <= 0) continue;
        final start = barStart + e * eighthSamples;
        final dur = melStaccato ? eighthSec * 0.45 : eighthSec * 0.9;
        _inject(
          out,
          start,
          _note(_midi(note), dur, sr,
              wave: melWave, vol: melVol, soft: soft || dark),
        );
      }

      // 킥 — 1·3박
      for (final beat in [0.0, 2.0]) {
        final start = barStart + (beat * beatSec * sr).round();
        _inject(out, start, _kick(beatSec * 0.12, sr, vol: kickVol, dark: dark));
      }

      // 스네어 — 2·4박 (보스)
      if (snareVol > 0) {
        for (final beat in [1.0, 3.0]) {
          final start = barStart + (beat * beatSec * sr).round();
          _inject(out, start, _snare(beatSec * 0.1, sr, vol: snareVol));
        }
      }

      // 하이햇 — 8분
      if (hihatVol > 0) {
        for (var e = 0; e < 8; e++) {
          if (soft && e.isOdd) continue;
          final start = barStart + e * eighthSamples;
          _inject(out, start, _hihat(eighthSec * 0.06, sr, vol: hihatVol));
        }
      }
    }

    var mixed = _normalize(out);

    if (echoMix > 0) {
      mixed = _applyEcho(mixed, sr, echoMix, delayMs: 280);
    }

    return _padToDuration(mixed, sr, targetDurationSec);
  }

  static List<double> _padToDuration(List<double> samples, int sr, double sec) {
    final target = (sec * sr).round();
    if (samples.length >= target) return samples.sublist(0, target);
    final out = List<double>.filled(target, 0);
    for (var i = 0; i < samples.length; i++) {
      out[i] = samples[i];
    }
    // 루프 크로스페이드 — 끝 0.5초를 처음과 부드럽게 연결
    final fade = (0.5 * sr).round();
    if (samples.length > fade * 2) {
      for (var i = 0; i < fade; i++) {
        final t = i / fade;
        final tail = samples[samples.length - fade + i];
        final head = samples[i];
        out[i] = head * t + tail * (1 - t);
      }
    }
    return out;
  }

  static List<double> _normalize(List<double> samples) {
    var peak = 0.0;
    for (final v in samples) {
      final a = v.abs();
      if (a > peak) peak = a;
    }
    if (peak < 1e-6) return samples;
    final scale = 0.88 / peak;
    return [for (final v in samples) v * scale];
  }

  static List<double> _applyEcho(
    List<double> samples,
    int sr,
    double mix,
    {required double delayMs}
  ) {
    final delay = (delayMs / 1000 * sr).round();
    final out = List<double>.from(samples);
    for (var i = delay; i < out.length; i++) {
      out[i] += samples[i - delay] * mix;
    }
    return _normalize(out);
  }

  static void _inject(List<double> buf, int start, List<double> note) {
    for (var i = 0; i < note.length; i++) {
      final idx = start + i;
      if (idx >= 0 && idx < buf.length) buf[idx] += note[i];
    }
  }

  static double _midi(int n) => 440.0 * pow(2, (n - 69) / 12).toDouble();

  static List<double> _note(
    double freq,
    double sec,
    int sr, {
    required String wave,
    required double vol,
    bool soft = false,
  }) {
    final n = max(1, (sec * sr).round());
    final out = List<double>.filled(n, 0);
    final atk = soft ? (n * 0.12).round() : (n * 0.04).round();
    final rel = soft ? (n * 0.35).round() : (n * 0.18).round();
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      phase += 2 * pi * freq / sr;
      var s = _osc(wave, phase);
      if (wave == 'sawtooth' && soft) {
        s = s * 0.7 + _osc('sine', phase) * 0.3;
      }
      double env = 1;
      if (i < atk) env = i / max(1, atk);
      if (i > n - rel) env = (n - i) / max(1, rel);
      out[i] = s * vol * env;
    }
    return out;
  }

  static List<double> _kick(double sec, int sr,
      {required double vol, bool dark = false}) {
    final n = max(1, (sec * sr).round());
    final out = List<double>.filled(n, 0);
    final f0 = dark ? 85.0 : 110.0;
    final f1 = dark ? 38.0 : 52.0;
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final k = i / n;
      final f = f0 + (f1 - f0) * k;
      phase += 2 * pi * f / sr;
      final env = pow(1 - k, 2.2).toDouble();
      out[i] = sin(phase) * vol * env;
    }
    return out;
  }

  static List<double> _snare(double sec, int sr, {required double vol}) {
    final n = max(1, (sec * sr).round());
    final rng = Random(42);
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final k = i / n;
      final env = pow(1 - k, 1.8).toDouble();
      final noise = (rng.nextDouble() * 2 - 1);
      final tone = sin(2 * pi * 180 * i / sr) * 0.35;
      out[i] = (noise * 0.65 + tone) * vol * env;
    }
    return out;
  }

  static List<double> _hihat(double sec, int sr, {required double vol}) {
    final n = max(1, (sec * sr).round());
    final rng = Random(7);
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final k = i / n;
      final env = pow(1 - k, 3.5).toDouble();
      out[i] = (rng.nextDouble() * 2 - 1) * vol * env;
    }
    return out;
  }

  static double _osc(String wave, double phase) {
    final p = phase % (2 * pi);
    return switch (wave) {
      'square' => p < pi ? 1.0 : -1.0,
      'sawtooth' => (p / pi) - 1.0,
      'triangle' => p < pi ? (2 * p / pi - 1) : (3 - 2 * p / pi),
      _ => sin(p),
    };
  }
}
