/// 배포·인앤 업데이트 설정.
///
/// manifest JSON 예시는 [deploy/update_manifest.example.json] 참고.
/// 빌드 시 URL 지정:
/// `flutter build apk --dart-define=UPDATE_MANIFEST_URL=https://.../update.json`
class AppReleaseConfig {
  AppReleaseConfig._();

  static const String appName = 'Dessert Billiards Merge';

  /// 원격 업데이트 manifest URL (비어 있으면 자동 확인 생략)
  static const String updateManifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue: '',
  );

  /// 메인 메뉴 진입 시 자동 업데이트 확인
  static const bool autoCheckOnMenu = true;

  /// manifest 요청 타임아웃
  static const Duration manifestTimeout = Duration(seconds: 12);

  /// APK 다운로드 타임아웃
  static const Duration downloadTimeout = Duration(minutes: 10);
}
