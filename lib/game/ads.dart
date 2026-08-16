import '../app/ad_config.dart';
import 'ad_quota.dart';
import 'ad_types.dart';
import 'ads_stub.dart' if (dart.library.js_interop) 'ads_web.dart' as platform;

export 'ad_types.dart';

Future<void> initAds() => platform.initAds();

/// 현재 실광고 SDK 사용 중이면 false, stub이면 true
bool get adsUsingStub => platform.adsUsingStub;

/// [placement] 일일 한도 확인 후 보상형 광고 표시.
/// 보상은 시청 완료 콜백에서만 [onReward] 호출.
Future<void> showRewardedAd(
  void Function() onReward, {
  required AdPlacement placement,
  AdQuota? quota,
  void Function(AdFailReason reason)? onFail,
  void Function({required bool stub})? onStart,
}) async {
  if (quota != null && !quota.canWatch(placement)) {
    onFail?.call(AdFailReason.dailyLimit);
    return;
  }

  await platform.showRewardedAd(
    () {
      quota?.recordWatch(placement);
      onReward();
    },
    placement: placement,
    onFail: onFail,
    onStart: onStart,
  );
}

String adModeLabel() {
  if (adsUsingStub) {
    return AdConfig.allowStubReward ? 'AD STUB' : 'AD OFF';
  }
  return AdConfig.testMode ? 'AD TEST' : 'AD LIVE';
}
