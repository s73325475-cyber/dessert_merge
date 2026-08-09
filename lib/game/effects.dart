import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';

// 월드 좌표계에 떠오르며 사라지는 점수 팝업
class ScorePopup extends Component {
  ScorePopup(this.pos, this.text, this.color, {this.size = 2.2});

  final Vector2 pos;
  final String text;
  final Color color;
  final double size;
  double _t = 0;
  static const double life = 0.9;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / life).clamp(0.0, 1.0);
    final alpha = (1 - p);
    final dy = -p * 4.0;
    const up = 6.0;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size * up,
          fontWeight: FontWeight.w800,
          color: color.withValues(alpha: alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(pos.x, pos.y + dy);
    canvas.scale(1 / up);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }
}

class _BurstParticle {
  _BurstParticle(this.vel, this.life, this.radius);
  Vector2 pos = Vector2.zero();
  Vector2 vel;
  double life;
  final double radius;
}

/// 가벼운 파티클 버스트 (ParticleSystem 누적 방지)
class SimpleBurst extends Component {
  SimpleBurst(Vector2 at, this.color, int count) : _origin = at.clone() {
    final rng = Random();
    final n = count.clamp(4, 12);
    for (var i = 0; i < n; i++) {
      final ang = rng.nextDouble() * pi * 2;
      final spd = 4 + rng.nextDouble() * 8;
      _parts.add(_BurstParticle(
        Vector2(cos(ang), sin(ang)) * spd,
        0.4 + rng.nextDouble() * 0.25,
        0.28 + rng.nextDouble() * 0.35,
      ));
    }
  }

  final Vector2 _origin;
  final Color color;
  final _parts = <_BurstParticle>[];

  @override
  void update(double dt) {
    for (final p in _parts) {
      p.life -= dt;
      p.pos += p.vel * dt;
      p.vel *= 0.96;
    }
    _parts.removeWhere((p) => p.life <= 0);
    if (_parts.isEmpty) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    for (final p in _parts) {
      final a = (p.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(_origin.x + p.pos.x, _origin.y + p.pos.y),
        p.radius,
        Paint()..color = color.withValues(alpha: a),
      );
    }
  }
}

Component burst(Vector2 at, Color color, int count) =>
    SimpleBurst(at, color, count);
