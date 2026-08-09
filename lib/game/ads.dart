// 보상형 광고 — 웹: Google H5 Games Ads, 그 외: stub.
import 'ads_stub.dart' if (dart.library.js_interop) 'ads_web.dart' as platform;

Future<void> initAds() => platform.initAds();

Future<void> showRewardedAd(
  void Function() onReward, {
  void Function()? onFail,
  void Function()? onStart,
}) =>
    platform.showRewardedAd(
      onReward,
      onFail: onFail,
      onStart: onStart,
    );
