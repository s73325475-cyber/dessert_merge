import 'dart:async';

import 'package:google_adsense/google_adsense.dart';
import 'package:google_adsense/h5.dart';

import '../app/ad_config.dart';
import 'ad_types.dart';
import 'ads_stub.dart' as stub;

bool _sdkInitialized = false;

bool get adsUsingStub => !AdConfig.isConfigured || !_sdkInitialized;

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
  AdPlacement placement = AdPlacement.coins,
  void Function(AdFailReason reason)? onFail,
  void Function({required bool stub})? onStart,
}) async {
  if (!AdConfig.isConfigured || !_sdkInitialized) {
    return stub.showRewardedAd(
      onReward,
      placement: placement,
      onFail: onFail,
      onStart: onStart,
    );
  }

  onStart?.call(stub: false);

  final completer = Completer<BreakStatus?>();
  var settled = false;

  void settle(BreakStatus? status) {
    if (settled) return;
    settled = true;
    if (!completer.isCompleted) completer.complete(status);
  }

  try {
    h5GamesAds.adBreak(
      AdBreakPlacement.rewarded(
        name: 'dessert-reward-${placement.debugName}',
        beforeAd: () {},
        // 유저가 보상 광고를 요청한 뒤이므로 show 진행
        beforeReward: (showAdFn) => showAdFn(),
        adDismissed: () {},
        adViewed: () {},
        afterAd: () {},
        adBreakDone: (info) {
          settle(info.breakStatus);
        },
      ),
    );
  } catch (_) {
    onFail?.call(AdFailReason.error);
    return;
  }

  final status = await completer.future.timeout(
    const Duration(seconds: 120),
    onTimeout: () => null,
  );

  if (status == BreakStatus.viewed) {
    onReward();
    return;
  }

  if (status == null) {
    onFail?.call(AdFailReason.timeout);
  } else {
    onFail?.call(AdFailReason.dismissed);
  }
}
