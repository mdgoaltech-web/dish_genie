import 'package:dish_genie/providers/premium_provider.dart';
import 'package:dish_genie/services/entitlement_store.dart';
import 'package:dish_genie/services/free_usage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PremiumProvider entitlement state machine', () {
    test('starts free with the full daily allowance', () {
      final p = PremiumProvider(autoInitialize: false);
      expect(p.isPro, isFalse);
      for (final f in FreeFeature.values) {
        expect(p.remainingToday(f), FreeLimits.limitFor(f));
        expect(p.canUse(f), isTrue);
      }
    });

    test('purchase grants Pro and removes limits', () {
      final now = DateTime(2026, 9, 15);
      final p = PremiumProvider(autoInitialize: false, clock: () => now);
      p.grantForTest(
        ProProducts.weekly,
        expiresAt: now.add(const Duration(days: 7)),
      );
      expect(p.isPro, isTrue);
      for (var i = 0; i < 50; i++) {
        expect(p.recordUse(FreeFeature.aiChat), isTrue);
      }
      expect(p.canUse(FreeFeature.aiChat), isTrue);
    });

    test('subscription expiry ends Pro and restores the free limits', () {
      var now = DateTime(2026, 9, 15);
      final p = PremiumProvider(autoInitialize: false, clock: () => now);
      p.grantForTest(
        ProProducts.yearly,
        expiresAt: now.add(const Duration(days: 365)),
      );
      expect(p.isPro, isTrue);
      now = now.add(const Duration(days: 366));
      expect(p.isPro, isFalse);
      expect(p.canUse(FreeFeature.scan), isTrue);
      expect(p.remainingToday(FreeFeature.scan), FreeLimits.scansPerDay);
    });

    test('restore of the non-consumable grants Pro permanently', () {
      var now = DateTime(2026, 9, 15);
      final p = PremiumProvider(autoInitialize: false, clock: () => now);
      final fromStoreKit = EntitlementStore(clock: () => now)
        ..grant(ProProducts.lifetime);
      p.applyVerifiedEntitlements(fromStoreKit);
      expect(p.isPro, isTrue);
      expect(p.isVerified, isTrue);
      now = now.add(const Duration(days: 5000));
      expect(p.isPro, isTrue);
    });

    test('verification that returns nothing revokes a cached entitlement', () {
      final now = DateTime(2026, 9, 15);
      final p = PremiumProvider(autoInitialize: false, clock: () => now);
      p.grantForTest(
        ProProducts.weekly,
        expiresAt: now.add(const Duration(days: 7)),
      );
      expect(p.isPro, isTrue);
      p.applyVerifiedEntitlements(EntitlementStore(clock: () => now));
      expect(p.isPro, isFalse);
    });

    test('free counters block at the limit and persist', () async {
      final now = DateTime(2026, 9, 15, 10);
      final p = PremiumProvider(autoInitialize: false, clock: () => now);
      var notifications = 0;
      p.addListener(() => notifications++);
      expect(p.recordUse(FreeFeature.mealPlan), isTrue);
      expect(p.recordUse(FreeFeature.mealPlan), isFalse);
      expect(p.canUse(FreeFeature.mealPlan), isFalse);
      expect(p.remainingToday(FreeFeature.mealPlan), 0);
      expect(notifications, 1);
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PremiumProvider.usageKey), contains('mealPlan'));
    });
  });
}
