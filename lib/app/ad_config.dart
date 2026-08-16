/// Google AdSense H5 Games Ads (Ad Placement API) 설정.
///
/// 빌드 시 `--dart-define=AD_PUBLISHER_ID=ca-pub-XXXXXXXX` 로 Publisher ID 지정.
/// GitHub Actions에서는 repository secret `AD_PUBLISHER_ID` 사용.
///
/// H5 Games Ads 베타 승인 전에는 `AD_TEST_MODE=true` 로 테스트 광고 사용.
/// 설정 방법: [deploy/ADS_SETUP.md](../../deploy/ADS_SETUP.md)
/// Secret 등록 스크립트: `deploy/configure-ads.ps1`
abstract final class AdConfig {
  /// AdSense Publisher ID (`ca-pub-…` 또는 숫자만)
  static const String publisherId = String.fromEnvironment(
    'AD_PUBLISHER_ID',
    defaultValue: '',
  );

  /// 네이버·카카오 WebView 등 앱 내 환경용 AdMob 보상형 슬롯 (선택)
  static const String admobRewardedSlot = String.fromEnvironment(
    'ADMOB_REWARDED_SLOT',
    defaultValue: '',
  );

  /// 앱 내 WebView용 AdMob 전면 슬롯 (선택)
  static const String admobInterstitialSlot = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_SLOT',
    defaultValue: '',
  );

  /// `true` → AdSense 테스트 광고 (`data-adbreak-test=on`)
  static const bool testMode = bool.fromEnvironment(
    'AD_TEST_MODE',
    defaultValue: true,
  );

  /// stub 경로에서 보상을 줄지 여부.
  /// 릴리스+false 이면 Publisher 미설정 시 보상 없이 실패 처리.
  static const bool allowStubReward = bool.fromEnvironment(
    'AD_ALLOW_STUB_REWARD',
    defaultValue: true,
  );

  static bool get isConfigured => publisherId.trim().isNotEmpty;

  /// [adSense.initialize] 에 전달할 Publisher ID (ca-pub- 접두사 제거)
  static String get normalizedPublisherId {
    final id = publisherId.trim();
    if (id.startsWith('ca-pub-')) return id.substring('ca-pub-'.length);
    return id;
  }
}
