import 'dart:io';

import 'package:dish_genie/config/app_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppLinks.version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)', multiLine: true)
        .firstMatch(pubspec);
    expect(match, isNotNull);
    expect(match!.group(1), AppLinks.version);
    expect(match.group(1), '1.1.0');
    expect(match.group(2), '21');
  });

  test('legal links are the agreed URLs', () {
    expect(
      AppLinks.termsOfUseUrl,
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
    );
    expect(
      AppLinks.privacyPolicyUrl,
      'https://sites.google.com/view/dodishgenie/home',
    );
    expect(
      AppLinks.manageSubscriptionsUrl,
      'itms-apps://apps.apple.com/account/subscriptions',
    );
  });
}
