import 'package:dish_genie/services/entitlement_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 15, 12);
  DateTime clock() => now;

  group('ProProducts', () {
    test('only the three shipped product ids count as Pro', () {
      expect(ProProducts.all, {
        'weekly_sub_chef',
        'yearly_sub_chef',
        'recipe_lifetime_purchase',
      });
      expect(ProProducts.isPro('lifetime_purchase_chef'), isFalse);
      expect(ProProducts.isSubscription(ProProducts.lifetime), isFalse);
      expect(ProProducts.isSubscription(ProProducts.weekly), isTrue);
    });
  });

  group('EntitlementStore', () {
    test('fresh install is not Pro', () {
      final store = EntitlementStore(clock: clock);
      expect(store.isPro, isFalse);
      expect(store.activeEntitlement, isNull);
    });

    test('a purchased subscription grants Pro until it expires', () {
      final store = EntitlementStore(clock: clock);
      expect(
        store.grant(
          ProProducts.weekly,
          expiresAt: now.add(const Duration(days: 7)),
        ),
        isTrue,
      );
      expect(store.isPro, isTrue);
      expect(store.activeEntitlement?.productId, ProProducts.weekly);
    });

    test('an expired subscription is ignored', () {
      final store = EntitlementStore(clock: clock);
      expect(
        store.grant(
          ProProducts.yearly,
          expiresAt: now.subtract(const Duration(minutes: 1)),
        ),
        isFalse,
      );
      expect(store.isPro, isFalse);
    });

    test('Pro ends when the clock passes the expiry (subscription lapse)', () {
      var current = now;
      final store = EntitlementStore(clock: () => current);
      store.grant(ProProducts.weekly, expiresAt: now.add(const Duration(days: 7)));
      expect(store.isPro, isTrue);
      current = now.add(const Duration(days: 8));
      expect(store.isPro, isFalse);
    });

    test('the non-consumable lifetime purchase never expires', () {
      var current = now;
      final store = EntitlementStore(clock: () => current);
      store.grant(ProProducts.lifetime);
      current = now.add(const Duration(days: 3650));
      expect(store.isPro, isTrue);
      expect(store.activeEntitlement?.expiresAt, isNull);
    });

    test('non-Pro product ids are rejected', () {
      final store = EntitlementStore(clock: clock);
      expect(store.grant('some_other_product'), isFalse);
      expect(store.isPro, isFalse);
    });

    test('re-verification replaces the cached state (restore / revoke)', () {
      final cached = EntitlementStore(clock: clock)
        ..grant(ProProducts.weekly, expiresAt: now.add(const Duration(days: 1)));
      final fromStoreKit = EntitlementStore(clock: clock);
      cached.replaceWith(fromStoreKit);
      expect(cached.isPro, isFalse, reason: 'StoreKit no longer lists it');

      final restored = EntitlementStore(clock: clock)..grant(ProProducts.lifetime);
      cached.replaceWith(restored);
      expect(cached.isPro, isTrue);
    });

    test('lifetime wins over subscriptions as the active entitlement', () {
      final store = EntitlementStore(clock: clock)
        ..grant(ProProducts.yearly, expiresAt: now.add(const Duration(days: 300)))
        ..grant(ProProducts.lifetime);
      expect(store.activeEntitlement?.productId, ProProducts.lifetime);
    });

    test('JSON round trip keeps expiry and drops garbage', () {
      final store = EntitlementStore(clock: clock)
        ..grant(ProProducts.yearly, expiresAt: now.add(const Duration(days: 30)));
      final json = store.toJsonString();
      final loaded = EntitlementStore.fromJsonString(json, clock: clock);
      expect(loaded.isPro, isTrue);
      expect(
        loaded.activeEntitlement?.expiresAt,
        now.add(const Duration(days: 30)),
      );

      expect(EntitlementStore.fromJsonString('not json', clock: clock).isPro,
          isFalse);
      expect(
        EntitlementStore.fromJsonString(
          '[{"productId":"hacked","expiresAt":"2999-01-01T00:00:00.000"}]',
          clock: clock,
        ).isPro,
        isFalse,
      );
    });
  });
}
