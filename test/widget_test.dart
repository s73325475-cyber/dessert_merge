import 'package:flutter_test/flutter_test.dart';

import 'package:dessert_merge/game/config.dart';

void main() {
  test('dessert tiers configured', () {
    expect(kDesserts.length, 5);
    expect(kMaxTier, 4);
  });
}
