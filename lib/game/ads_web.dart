import 'dart:async';

import 'package:google_adsense/google_adsense.dart';
import 'package:google_adsense/h5.dart';

import '../app/ad_config.dart';
import 'ads_stub.dart' as stub;

bool _sdkInitialized = false;

Future<void> initAds() async {
  if (!AdConfig.isConfigured || _sdkInitialized) return;

  await adSense.initialize(
    AdConfig.normalizedPublisherId,
    adSenseCodeParameters: AdSenseCodeParameters(
      adbreakTest: AdConfig.testMode ? 'on' : null,
      adFrequencyHint: '30s',
      admobRewardedSlot:
          AdConfig.admobRewardedSlot.isEmpty ? null : AdConfig.admobRewardedSlot,
      admobInterstitialSlot: AdConfig.admobInterstitialSlot.isEmpty
          ? null
          : AdConfig.admobInterstitialSlot,
    ),
  );
  _sdkInitialized = true;

  h5GamesAds.adConfig(
    AdConfigParameters(
      sound: SoundEnabled.on,
      preloadAdBreaks: PreloadAdBreaks.on,
    ),
  );
}

Future<void> showRewardedAd(
  void Function() onReward, {
  void Function()? onFail,
  void Function()? onStart,
}) async {
  if (!AdConfig.isConfigured || !_sdkInitialized) {
    return stub.showRewardedAd(onReward, onFail: onFail, onStart: onStart);
  }

  onStart?.call();

  final completer = Completer<bool>();
  var settled = false;

  void settle(bool viewed) {
    if (settled) return;
    settled = true;
    if (!completer.isCompleted) completer.complete(viewed);
  }

  h5GamesAds.adBreak(
    AdBreakPlacement.rewarded(
      name: 'dessert-reward',
      beforeAd: () {},
      beforeReward: (showAdFn) => showAdFn(),
      adDismissed: () {},
      adViewed: () {},
      afterAd: () {},
      adBreakDone: (info) {
        settle(info.breakStatus == BreakStatus.viewed);
      },
    ),
  );

  final viewed = await completer.future.timeout(
    const Duration(seconds: 120),
    onTimeout: () => false,
  );

  if (viewed) {
    onReward();
  } else {
    onFail?.call();
  }
}
