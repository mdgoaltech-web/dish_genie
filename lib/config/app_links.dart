/// Static app facts and external links. Nothing here is fetched remotely.
class AppLinks {
  AppLinks._();

  /// Marketing version shown in Settings. Kept in sync with pubspec.yaml by
  /// `test/app_info_test.dart`.
  static const String version = '1.0.9';

  static const String appStoreId = '6757077403';
  static const String appStoreUrl = 'https://apps.apple.com/app/id$appStoreId';

  static const String supportEmail = 'md.goaltech@gmail.com';

  static const String privacyPolicyUrl =
      'https://sites.google.com/view/dodishgenie/home';

  /// Apple's standard Licensed Application End User License Agreement.
  static const String termsOfUseUrl =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

  static const String manageSubscriptionsUrl =
      'itms-apps://apps.apple.com/account/subscriptions';
}
