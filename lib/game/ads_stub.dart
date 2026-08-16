import 'package:flutter/foundation.dart';

import '../app/ad_config.dart';
import 'ad_types.dart';

// 비웹·Publisher ID 미설정 시 stub 보상형 광고.

bool get adsUsingStub => true;

Future<void> initAds() async {}

Future<void> showRewardedAd(
  void Function() onReward, {
  AdPlacement placement = AdPlacement.coins,
  void Function(AdFailReason reason)? onFail,
  void Function({required bool stub})? onStart,
}) async {
  try {
    onStart?.call(stub: true);

    // 릴리스에서 stub 보상 금지(실광고 미연동 시 공짜 보상 방지)
    if (kReleaseMode && !AdConfig.allowStubReward) {
      onFail?.call(AdFailReason.notReady);
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    onReward();
  } catch (_) {
    onFail?.call(AdFailReason.error);
  }
}
