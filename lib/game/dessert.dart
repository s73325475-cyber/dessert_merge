import 'dart:math';

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/widgets.dart';

import 'bumper.dart';
import 'config.dart';
import 'merge_game.dart';
import 'spawn.dart';

class Dessert extends BodyComponent<MergeGame> with ContactCallbacks {
  Dessert({
    required this.kind,
    required this.tier,
    required this.spawnPosition,
    this.golden = false,
    this.bullet = false,
    this.powerShot = false,
    this.launchPowerMult = 1.0,
    this.initialVelocity,
    this.missionEpoch = 0,
    this.spawnFireId = 0,
  }) : super(renderBody: false);

  factory Dessert.fromSpawn(
    Spawn s,
    Vector2 position, {
    bool bullet = false,
    bool powerShot = false,
    double launchPowerMult = 1.0,
    Vector2? initialVelocity,
    int missionEpoch = 0,
    int spawnFireId = 0,
  }) =>
      Dessert(
        kind: s.kind,
        tier: s.tier,
        spawnPosition: position,
        golden: s.golden,
        bullet: bullet,
        powerShot: powerShot,
        launchPowerMult: launchPowerMult,
        initialVelocity: initialVelocity,
        missionEpoch: missionEpoch,
        spawnFireId: spawnFireId,
      );

  DessertKind kind;
  int tier;
  bool golden;
  final bool bullet;
  final bool powerShot;
  final double launchPowerMult;
  final Vector2 spawnPosition;
  final Vector2? initialVelocity;
  /// 미션 공지 이후 생성분만 현재 `_missionEpoch`와 일치
  int missionEpoch;
  /// 이번 발사(`_activeFireId`)에서 나온 디저트 — CHAIN 판정용
  int spawnFireId;

  bool merging = false;
  bool precisionMerge = false;
  double _age = 0;
  bool _bulletSettled = false;
  bool _firstContactChecked = false;
  Vector2? _approachVelocitySnapshot;
  double? _savedSelfRestitution;
  double? _savedPartnerRestitution;
  Dessert? _restitutionPartner;
  int _wallHitCount = 0;
  double _settledAt = -1;
  int get wallHitCount => _wallHitCount;

  bool get canMergeAsBullet {
    if (!bullet) return true;
    if (!_bulletSettled) return false;
    if (_wallHitCount >= GameConfig.bulletMergeMinWallHits) return true;
    if (_settledAt >= 0 && _age - _settledAt >= GameConfig.bulletMergeDelaySec) {
      return true;
    }
    return false;
  }

  bool canMergeWith(Dessert other) {
    if (merging || other.merging) return false;
    if (isJunk || other.isJunk) return false;
    if (!canMergeAsBullet || !other.canMergeAsBullet) return false;
    return true;
  }

  /// 발사대 보호 — 최종 정지 여부
  bool get isAtRest {
    if (!isMounted || merging) return false;
    if (bullet && !_bulletSettled) return false;
    final threshold = bullet
        ? GameConfig.bulletSleepSpeedFor(
            powerShot: powerShot,
            wallHit: _wallHitCount > 0,
          )
        : GameConfig.fieldRestSpeed;
    return body.linearVelocity.length < threshold;
  }

  double _relocateCooldown = 0;
  double get age => _age;

  bool get isBulletInFlight => bullet && !_bulletSettled;
  bool get canRelocateFromLaunch => _relocateCooldown <= 0;

  void tickRelocateCooldown(double dt) {
    if (_relocateCooldown > 0) _relocateCooldown -= dt;
  }

  void markLaunchRelocated() => _relocateCooldown = 0.6;

  bool get isNormal => kind == DessertKind.normal;
  bool get isJunk => kind == DessertKind.junk;

  double get radius {
    switch (kind) {
      case DessertKind.junk:
        return Junk.radius;
      case DessertKind.normal:
        return GameConfig.dessertRadius;
    }
  }

  String get emoji {
    switch (kind) {
      case DessertKind.junk:
        return Junk.emoji;
      case DessertKind.normal:
        return MergeGame.skinEmoji(tier);
    }
  }

  @override
  Body createBody() {
    final shape = CircleShape()..radius = radius;
    final fixture = FixtureDef(
      shape,
      restitution:
          bullet ? GameConfig.bulletFlightRestitution : GameConfig.restitution,
      friction: GameConfig.friction,
      density: GameConfig.density,
    );
    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: spawnPosition,
      linearDamping: bullet
          ? GameConfig.bulletLinearDamping
          : GameConfig.linearDamping,
      bullet: bullet,
    );
    final b = world.createBody(bodyDef)..createFixture(fixture);
    b.userData = this;
    return b;
  }

  @override
  void onMount() {
    super.onMount();
    if (initialVelocity != null) {
      body.setAwake(true);
      body.linearVelocity = initialVelocity!.clone();
    }
  }

  void _noteFirstContact(Dessert other) {
    if (!bullet || _firstContactChecked) return;
    _firstContactChecked = true;
    if (isNormal && other.isNormal && other.tier == tier) {
      precisionMerge = true;
    }
  }

  double get _launchSpeed => initialVelocity?.length ?? 0;

  /// MergeGame에서 물리 스텝 직전 호출 — damping·감속 실제 적용
  void tickBulletFlight(double dt) {
    if (!bullet || _bulletSettled || !isMounted || dt <= 0) return;

    final postGrace = _wallHitCount > GameConfig.bulletWallFreeHits;
    body.linearDamping = postGrace
        ? GameConfig.bulletPostWallFlightDamping
        : GameConfig.bulletWallFlightDamping;

    final retain = postGrace
        ? GameConfig.bulletPostWallRetainPerSec
        : GameConfig.bulletFlightRetainPerSec;
    final decay = pow(retain, dt).toDouble();
    final v = body.linearVelocity;
    if (v.length2 > 0.01) {
      body.linearVelocity = v * decay;
    }
    _applyFlightSpeedLimits();
  }

  /// 벽 뱅크 — 3벽까지 유지, 이후 매 충돌마다 감속
  void _onWallContact() {
    if (!bullet || _bulletSettled) return;

    _wallHitCount++;

    if (_wallHitCount > GameConfig.bulletWallFreeHits) {
      final v = body.linearVelocity;
      final len = v.length;
      if (len > 0.05) {
        body.linearVelocity = v * GameConfig.bulletWallDecelMult;
      }
    }

    body.linearDamping = _wallHitCount > GameConfig.bulletWallFreeHits
        ? GameConfig.bulletPostWallFlightDamping
        : GameConfig.bulletWallFlightDamping;
    for (final f in body.fixtures) {
      f.restitution = GameConfig.bulletFlightRestitution;
    }
    _applyFlightSpeedLimits();
  }

  /// 비행 중 속도 상한 (3벽까지 launch, 이후 launch×0.9)
  void _applyFlightSpeedLimits() {
    if (!bullet || _bulletSettled) return;
    final launch = _launchSpeed;
    if (launch <= 0.08) return;

    final maxSpeed = _wallHitCount > GameConfig.bulletWallFreeHits
        ? launch * GameConfig.bulletPostWallSpeedCeilingMult
        : launch;

    final v = body.linearVelocity;
    final len = v.length;
    if (len > maxSpeed) {
      body.linearVelocity = (v / len) * maxSpeed;
    }
  }

  /// 디저트(·범퍼) 첫 충돌 — 단일 settle + 충돌 법선 반영(관통 방지)
  void _applyDessertSettle({
    Contact? contact,
    Dessert? partner,
  }) {
    if (!bullet || _bulletSettled) return;

    final approach = _approachVelocitySnapshot?.clone() ??
        body.linearVelocity.clone();
    _approachVelocitySnapshot = null;

    final launch = _launchSpeed;
    if (launch <= 0.08) return;

    _bulletSettled = true;
    _settledAt = _age;
    body.linearDamping = GameConfig.bulletSettleDampingFor(
      launchPowerMult,
      powerShot: powerShot,
      wallHit: false,
    );

    final mult = GameConfig.bulletSettleSpeedMultFor(
      launchPowerMult,
      powerShot: powerShot,
      wallHit: false,
    );
    final cap = GameConfig.bulletMaxSettleSpeedFor(
      launchPowerMult,
      powerShot: powerShot,
      wallHit: false,
    );
    final approachLen = approach.length;
    final launchSettle = launch * mult;
    final targetSpeed = min(
      min(approachLen > 0.08 ? approachLen * mult : launchSettle, launchSettle),
      cap,
    );

    final Vector2 settleVel;
    if (partner != null && contact != null && approachLen > 0.08) {
      settleVel = _settleVelocityFromDessertContact(
        approach: approach,
        contact: contact,
        partner: partner,
        targetSpeed: targetSpeed,
        cap: cap,
      );
    } else {
      final dir = approachLen > 0.08
          ? approach / approachLen
          : initialVelocity!.normalized();
      settleVel = dir * targetSpeed;
    }

    body.linearVelocity.setFrom(settleVel);
    for (final f in body.fixtures) {
      f.restitution = GameConfig.bulletSettleRestitution(
        wallHit: false,
        powerShot: powerShot,
      );
    }
    _restoreContactRestitution(partner);

    if (partner != null && contact != null) {
      _impartPartnerPush(partner, contact, launch);
    }

    if (powerShot) {
      game.shake(10);
      game.onPowerShotImpact(body.position.clone());
    }
  }

  /// 충돌 법선 기준 — 상대 쪽 법선 성분 제거, 접선으로 미끄러짐
  Vector2 _settleVelocityFromDessertContact({
    required Vector2 approach,
    required Contact contact,
    required Dessert partner,
    required double targetSpeed,
    required double cap,
  }) {
    final n = _contactNormalToward(contact, partner);
    final vn = approach.dot(n);
    final vt = approach - n * vn;
    final tLen = vt.length;

    Vector2 vel;
    if (vn > 0.08) {
      if (tLen > 0.08) {
        final keep = GameConfig.bulletSettleTangentKeep;
        vel = vt * keep;
      } else {
        var tangent = Vector2(-n.y, n.x);
        if (tangent.dot(approach) < 0) tangent.negate();
        vel = tangent * (targetSpeed * GameConfig.bulletSettleHeadOnSlideMult);
      }
    } else {
      vel = approach.normalized() * targetSpeed;
    }

    if (!vel.x.isFinite ||
        !vel.y.isFinite ||
        vel.length2 < 1e-8) {
      vel = approach.length2 > 1e-8
          ? approach.normalized() * targetSpeed
          : Vector2.zero();
    }

    final len = vel.length;
    if (len > 0.08) {
      if (len > cap) {
        vel *= cap / len;
      } else if (len > targetSpeed) {
        vel *= targetSpeed / len;
      }
    }
    return vel;
  }

  Vector2 _contactNormalToward(Contact contact, Dessert partner) {
    final manifold = WorldManifold();
    contact.getWorldManifold(manifold);
    var n = Vector2(manifold.normal.x, manifold.normal.y);
    if (n.length2 < 1e-8) {
      final toPartner = partner.body.position - body.position;
      if (toPartner.length2 < 1e-8) return Vector2(0, -1);
      return toPartner.normalized();
    }
    final toPartner = partner.body.position - body.position;
    if (n.dot(toPartner) < 0) n.negate();
    return n;
  }

  void _suppressSolverRestitution(Object other, Contact contact) {
    _savedSelfRestitution ??= body.fixtures.first.restitution;
    body.fixtures.first.restitution = 0;

    if (other is Dessert) {
      _restitutionPartner ??= other;
      _savedPartnerRestitution ??= other.body.fixtures.first.restitution;
      other.body.fixtures.first.restitution = 0;
    } else if (other is BumperComponent) {
      _savedPartnerRestitution ??= other.body.fixtures.first.restitution;
      other.body.fixtures.first.restitution = 0;
    }
    contact.resetRestitution();
  }

  void _restoreContactRestitution(Dessert? partner) {
    if (_savedSelfRestitution != null) {
      body.fixtures.first.restitution = _bulletSettled
          ? GameConfig.bulletSettleRestitution(
              wallHit: false,
              powerShot: powerShot,
            )
          : _savedSelfRestitution!;
      _savedSelfRestitution = null;
    }

    final p = partner ?? _restitutionPartner;
    if (p != null &&
        p.isMounted &&
        _savedPartnerRestitution != null) {
      p.body.fixtures.first.restitution = GameConfig.restitution;
      _savedPartnerRestitution = null;
    }
    _restitutionPartner = null;
  }

  void _impartPartnerPush(
    Dessert partner,
    Contact contact,
    double launchSpeed,
  ) {
    if (!partner.isMounted) return;

    final n = _contactNormalToward(contact, partner);
    final pushMult = GameConfig.dessertPartnerPushMult *
        (powerShot ? PowerShot.physicsMult.clamp(1.0, 2.5) : 1.0);
    partner.body.setAwake(true);
    partner.body.linearVelocity += n * (launchSpeed * pushMult);
  }

  void _enforceSettleCap() {
    if (!bullet || !_bulletSettled) return;
    final cap = GameConfig.bulletMaxSettleSpeedFor(
      launchPowerMult,
      powerShot: powerShot,
      wallHit: false,
    );
    final v = body.linearVelocity;
    final len = v.length;
    if (len > cap) {
      body.linearVelocity = v * (cap / len);
    }
  }

  void _handleBumperContact() {
    if (bullet) {
      if (!_bulletSettled) {
        _applyDessertSettle();
        return;
      }
      final v = body.linearVelocity;
      final len = v.length;
      if (len < 0.05) return;
      body.linearVelocity = v * Bumper.contactSpeedRetain;
      _enforceSettleCap();
      final sleepAt = GameConfig.bulletSleepSpeedFor(
        powerShot: powerShot,
        wallHit: false,
      );
      if (body.linearVelocity.length < sleepAt) {
        body.setAwake(false);
      }
      return;
    }

    final v = body.linearVelocity;
    if (v.length < 0.05) return;
    body.linearVelocity = v * Bumper.contactSpeedRetain;
  }

  void _applyTailDecel() {
    if (!isMounted || merging) return;
    final v = body.linearVelocity;
    final len = v.length;
    if (len < 0.02) return;

    if (bullet && _bulletSettled) {
      final sleepAt = GameConfig.bulletSleepSpeedFor(
        powerShot: powerShot,
        wallHit: _wallHitCount > 0,
      );
      if (len < sleepAt * 3) {
        body.linearVelocity = v * GameConfig.fieldTailDecay;
      }
      return;
    }

    if (!bullet) {
      final sleepAt = GameConfig.fieldSleepSpeed;
      if (len < sleepAt * 3) {
        body.linearVelocity = v * GameConfig.fieldTailDecay;
      }
    }
  }

  void _trySleep() {
    if (!isMounted || merging) return;
    final sleepAt = bullet
        ? GameConfig.bulletSleepSpeedFor(
            powerShot: powerShot,
            wallHit: _wallHitCount > 0,
          )
        : GameConfig.fieldSleepSpeed;
    if (body.linearVelocity.length < sleepAt) {
      body.linearVelocity.setZero();
      body.angularVelocity = 0;
      body.setAwake(false);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    _applyTailDecel();
    _trySleep();

    if (bullet && _bulletSettled) {
      _enforceSettleCap();
    }
  }

  double get _popScale {
    const popT = 0.18;
    if (_age >= popT) return 1.0;
    final t = _age / popT;
    return 0.4 + 0.6 * t * (2 - t);
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is Dessert) {
      game.onDessertContact(this, other);
    }
    if (bullet &&
        !_bulletSettled &&
        (other is Dessert || other is BumperComponent)) {
      _approachVelocitySnapshot = body.linearVelocity.clone();
    }
  }

  @override
  void preSolve(Object other, Contact contact, Manifold oldManifold) {
    if (!bullet || _bulletSettled) return;
    if (other is Dessert || other is BumperComponent) {
      _suppressSolverRestitution(other, contact);
    }
  }

  @override
  void postSolve(Object other, Contact contact, ContactImpulse impulse) {
    if (other is BumperComponent) {
      _handleBumperContact();
      return;
    }
    if (!bullet) return;
    if (other is FieldWallTag) {
      _onWallContact();
      return;
    }
    if (other is Dessert) {
      _noteFirstContact(other);
      if (!_bulletSettled && !other.merging && !merging) {
        _applyDessertSettle(contact: contact, partner: other);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final s = _popScale;
    if (powerShot) {
      final pulse = 0.85 + 0.15 * sin(_age * 14);
      final ringPaint = Paint()
        ..color = const Color(0xffffd54f).withValues(alpha: 0.95 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.42;
      canvas.drawCircle(Offset.zero, radius * 1.08 * s, ringPaint);
    }
    if (golden) {
      final ringPaint = Paint()
        ..color = const Color(0xffffd700).withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.35;
      canvas.drawCircle(Offset.zero, radius * 1.02 * s, ringPaint);
    }
    drawEmoji(canvas, emoji, radius * 1.7 * s, Offset.zero);
  }

  static void drawEmoji(Canvas canvas, String emoji, double size, Offset at,
      {double opacity = 1.0}) {
    const up = 6.0;
    final tp = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: size * up,
          color: const Color(0xffffffff).withValues(alpha: opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(1 / up);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }
}
