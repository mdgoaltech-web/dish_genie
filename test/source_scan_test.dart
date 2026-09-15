import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against the patterns that got sibling apps rejected under
/// Guideline 5.6: remote switches, ads, review-mode detection, platform
/// feature gating, Play Store links and hidden gestures.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.contains('/l10n/'))
      .toList();

  Map<String, String> sources() => {
    for (final f in dartFiles) f.path: f.readAsStringSync(),
  };

  test('lib/ contains no forbidden identifiers', () {
    const forbidden = [
      'firebase',
      'remote_config',
      'RemoteConfig',
      'google_mobile_ads',
      'GADApplication',
      'splash_sub',
      'weekly_sub_ios',
      'isReview',
      'play.google.com',
      'AdService',
      'InterstitialAd',
      'BannerAd',
      'NativeAd',
      'AppOpenAd',
      'permission_handler',
      'google_fonts',
      'maintenance_mode',
      'app_version_required',
      'lifetime_purchase_chef',
      '_forceShow',
    ];
    final offenders = <String>[];
    sources().forEach((path, src) {
      for (final word in forbidden) {
        if (src.contains(word)) offenders.add('$path: $word');
      }
    });
    expect(offenders, isEmpty);
  });

  test('no Platform checks gate features', () {
    final offenders = <String>[];
    sources().forEach((path, src) {
      if (src.contains('Platform.is') ||
          src.contains('Platform.operatingSystem') ||
          src.contains('defaultTargetPlatform')) {
        offenders.add(path);
      }
    });
    expect(offenders, isEmpty);
  });

  test('no feature is reachable only through a hidden gesture', () {
    final offenders = <String>[];
    sources().forEach((path, src) {
      if (src.contains('onDoubleTap') || src.contains('onSecondaryTap')) {
        offenders.add('$path: double/secondary tap');
      }
      // Long-press is allowed only as a shortcut for something that also has
      // a visible button: the chat message actions sheet.
      if (src.contains('onLongPress')) {
        final hasVisibleButton =
            src.contains('message-actions-') &&
            src.contains('onPressed: () => _showMessageActions');
        if (!hasVisibleButton) offenders.add('$path: onLongPress');
      }
    });
    expect(offenders, isEmpty);
  });

  test('the paywall is only opened through ProNavigation', () {
    final offenders = <String>[];
    sources().forEach((path, src) {
      if (path.endsWith('pro_navigation.dart') ||
          path.endsWith('app_router.dart')) {
        return;
      }
      if (src.contains("'/pro'") || src.contains('AppRouter.proRoute')) {
        offenders.add(path);
      }
    });
    expect(offenders, isEmpty);
  });

  test('ProNavigation is never called from initState or a timer', () {
    sources().forEach((path, src) {
      // A cheap structural check: every ProNavigation call must be inside a
      // callback (onTap/onPressed) or a limit check, never top-level init.
      final lines = src.split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('ProNavigation.tryOpen')) continue;
        final window = lines
            .sublist((i - 12).clamp(0, lines.length), i + 1)
            .join('\n');
        expect(
          window.contains('initState') || window.contains('Timer('),
          isFalse,
          reason: '$path:${i + 1} opens the paywall from init/timer',
        );
      }
    });
  });

  test('Info.plist carries no ad or tracking keys', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist.contains('GADApplicationIdentifier'), isFalse);
    expect(plist.contains('SKAdNetworkItems'), isFalse);
    expect(plist.contains('NSUserTrackingUsageDescription'), isFalse);
    expect(plist.contains('Recipe Keeper'), isTrue);
  });

  test('PrivacyInfo.xcprivacy declares no tracking', () {
    final privacy = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
    expect(privacy.contains('<key>NSPrivacyTracking</key>\n\t<false/>'), isTrue);
    expect(privacy.contains('CA92.1'), isTrue);
  });

  test('pubspec has no ad, analytics or remote-config packages', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final dep in [
      'google_mobile_ads',
      'firebase_core',
      'firebase_analytics',
      'firebase_remote_config',
      'google_fonts',
      'permission_handler',
    ]) {
      expect(pubspec.contains(dep), isFalse, reason: dep);
    }
    expect(pubspec.contains('in_app_purchase'), isTrue);
  });
}
