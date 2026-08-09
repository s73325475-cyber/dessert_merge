import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/widgets.dart';

import 'config.dart';
import 'dessert.dart';
import 'merge_game.dart';

class BumperComponent extends BodyComponent<MergeGame> with ContactCallbacks {
  BumperComponent(this.spawnPosition) : super(renderBody: false);

  final Vector2 spawnPosition;

  @override
  Body createBody() {
    final shape = CircleShape()..radius = Bumper.radius;
    final fixture = FixtureDef(shape,
        restitution: Bumper.restitution, friction: 0.0, density: 1.0);
    final body = world.createBody(
      BodyDef(type: BodyType.static, position: spawnPosition),
    );
    body.createFixture(fixture);
    body.userData = this;
    return body;
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is Dessert) game.audio.bumper();
  }

  @override
  void render(Canvas canvas) {
    Dessert.drawEmoji(canvas, Bumper.emoji, Bumper.radius * 1.8, Offset.zero);
  }
}
