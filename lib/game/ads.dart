// 보상형 광고 인터페이스(stub). 지금은 짧은 대기 후 보상.
// 추후 실제 광고 SDK 연동 시 이 함수 내부만 교체.
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
