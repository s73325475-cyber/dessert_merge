// 보상형 광고 인터페이스(stub). 지금은 즉시 보상.
// 추후 실제 광고 SDK 연동 시 이 함수 내부만 교체.
void showRewardedAd(void Function() onReward, {void Function()? onFail}) {
  try {
    onReward();
  } catch (_) {
    onFail?.call();
  }
}
