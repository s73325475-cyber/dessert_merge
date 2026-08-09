// 비웹·Publisher ID 미설정 시 stub 보상형 광고.

Future<void> initAds() async {}

Future<void> showRewardedAd(
  void Function() onReward, {
  void Function()? onFail,
  void Function()? onStart,
}) async {
  try {
    onStart?.call();
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    onReward();
  } catch (_) {
    onFail?.call();
  }
}
