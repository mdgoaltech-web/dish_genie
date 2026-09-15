import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

import 'entitlement_store.dart';

/// Thin StoreKit wrapper around `in_app_purchase`.
///
/// Responsibilities:
///  * load the three Pro products and expose their store prices;
///  * start purchases;
///  * listen to the purchase stream and translate verified transactions into
///    [EntitlementStore] grants;
///  * re-verify the entitlement from StoreKit's current entitlements on
///    demand ([verifyEntitlements]) and on explicit "Restore Purchases".
///
/// No receipt is sent to any server. StoreKit 2 only reports transactions it
/// has verified itself, and `restorePurchases` enumerates
/// `Transaction.currentEntitlements`, which excludes expired subscriptions.
class BillingService {
  BillingService._();

  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static bool _initialized = false;
  static bool _available = false;
  static List<ProductDetails> _products = const [];
  static String? _lastError;

  /// Entitlements granted by events observed while the app runs (purchases
  /// and restores). Merged into the provider's store.
  static final EntitlementStore _live = EntitlementStore();

  /// Collects restore events during [verifyEntitlements].
  static EntitlementStore? _verifying;

  static final StreamController<PurchaseDetails> _events =
      StreamController<PurchaseDetails>.broadcast();

  /// Every purchase-stream event for Pro products, after entitlement
  /// bookkeeping has been applied.
  static Stream<PurchaseDetails> get events => _events.stream;

  static bool get isAvailable => _available;
  static bool get isInitialized => _initialized;
  static List<ProductDetails> get products => _products;
  static String? get lastError => _lastError;
  static EntitlementStore get liveEntitlements => _live;

  static ProductDetails? product(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _available = await _iap.isAvailable();
      _subscription ??= _iap.purchaseStream.listen(
        (purchases) {
          for (final p in purchases) {
            _handle(p);
          }
        },
        onError: (Object error) {
          _lastError = error.toString();
        },
      );
    } catch (e) {
      // No StoreKit (e.g. unit tests): the app keeps working as free tier.
      _available = false;
      _lastError = e.toString();
    }
    if (_available) {
      await loadProducts();
    }
  }

  static Future<bool> loadProducts() async {
    if (!_available) return false;
    try {
      final response = await _iap.queryProductDetails(ProProducts.all);
      if (response.error != null) {
        _lastError = response.error!.message;
      }
      _products = response.productDetails;
      if (kDebugMode && response.notFoundIDs.isNotEmpty) {
        debugPrint('[Billing] products not found: ${response.notFoundIDs}');
      }
      return _products.isNotEmpty;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  /// Starts a StoreKit purchase. Returns false if the sheet could not be
  /// presented; the outcome arrives on [events].
  static Future<bool> purchase(ProductDetails product) async {
    if (!_available) {
      _lastError = 'In-App Purchase is not available on this device.';
      return false;
    }
    try {
      _lastError = null;
      final param = PurchaseParam(productDetails: product);
      // Subscriptions and the non-consumable lifetime unlock both go through
      // buyNonConsumable; StoreKit decides the product type.
      return await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  /// Re-reads StoreKit's current entitlements. Returns a store containing
  /// only what StoreKit reports right now, or null when StoreKit could not
  /// be queried (caller should then keep its cached state).
  static Future<EntitlementStore?> verifyEntitlements({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (!_initialized) await initialize();
    if (!_available) return null;
    final collector = EntitlementStore();
    _verifying = collector;
    try {
      await _iap.restorePurchases().timeout(timeout);
      // Transactions are delivered on the purchase stream slightly after the
      // restore call returns; give them a moment to land.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return collector;
    } catch (e) {
      _lastError = e.toString();
      return null;
    } finally {
      if (identical(_verifying, collector)) _verifying = null;
    }
  }

  /// User-initiated "Restore Purchases". Syncs with the App Store (may ask
  /// the user to sign in) and then re-verifies.
  static Future<EntitlementStore?> restorePurchases() async {
    if (!_initialized) await initialize();
    if (!_available) return null;
    try {
      await InAppPurchaseStoreKitPlatformAddition().sync();
    } catch (e) {
      // sync() is best effort; verification below still works offline.
      if (kDebugMode) debugPrint('[Billing] sync failed: $e');
    }
    return verifyEntitlements();
  }

  static void _handle(PurchaseDetails purchase) {
    final id = purchase.productID;
    if (!ProProducts.isPro(id)) {
      _finishIfNeeded(purchase);
      return;
    }
    switch (purchase.status) {
      case PurchaseStatus.purchased:
        _live.grant(id, expiresAt: expirationOf(purchase));
        break;
      case PurchaseStatus.restored:
        final expires = expirationOf(purchase);
        final target = _verifying;
        if (target != null) {
          target.grant(id, expiresAt: expires);
        } else {
          _live.grant(id, expiresAt: expires);
        }
        break;
      case PurchaseStatus.error:
        _lastError = purchase.error?.message;
        break;
      case PurchaseStatus.pending:
      case PurchaseStatus.canceled:
        break;
    }
    _finishIfNeeded(purchase);
    _events.add(purchase);
  }

  static void _finishIfNeeded(PurchaseDetails purchase) {
    if (purchase.pendingCompletePurchase) {
      unawaited(_iap.completePurchase(purchase));
    }
  }

  /// Subscription expiry as reported by StoreKit 2, null for the lifetime
  /// purchase or when StoreKit gives no date.
  static DateTime? expirationOf(PurchaseDetails purchase) {
    if (purchase is SK2PurchaseDetails) {
      return parseExpiration(purchase.expirationDate);
    }
    return null;
  }

  /// StoreKit 2 reports the expiry as milliseconds since epoch in a string.
  @visibleForTesting
  static DateTime? parseExpiration(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final asNumber = double.tryParse(raw);
    if (asNumber != null) {
      // Values around 1e12 are milliseconds; around 1e9 are seconds.
      final ms = asNumber > 1e11 ? asNumber : asNumber * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms.round(), isUtc: true)
          .toLocal();
    }
    return DateTime.tryParse(raw);
  }

  /// True only when StoreKit reports a free-trial introductory offer for the
  /// product. Used to decide whether trial wording may be shown at all.
  static bool hasFreeTrial(ProductDetails product) {
    if (product is AppStoreProduct2Details) {
      final offers = product.sk2Product.subscription?.promotionalOffers ?? [];
      return offers.any(
        (o) =>
            o.type == SK2SubscriptionOfferType.introductory &&
            o.paymentMode == SK2SubscriptionOfferPaymentMode.freeTrial,
      );
    }
    if (product is AppStoreProductDetails) {
      final intro = product.skProduct.introductoryPrice;
      return intro != null &&
          intro.paymentMode == SKProductDiscountPaymentMode.freeTrail;
    }
    return false;
  }

  /// Human-readable trial length ("3 days") when [hasFreeTrial] is true.
  static String? freeTrialDescription(ProductDetails product) {
    if (product is AppStoreProduct2Details) {
      final offers = product.sk2Product.subscription?.promotionalOffers ?? [];
      for (final o in offers) {
        if (o.type == SK2SubscriptionOfferType.introductory &&
            o.paymentMode == SK2SubscriptionOfferPaymentMode.freeTrial) {
          final n = o.period.value * o.periodCount;
          final unit = o.period.unit.name;
          return '$n $unit${n == 1 ? '' : 's'}';
        }
      }
    }
    if (product is AppStoreProductDetails) {
      final intro = product.skProduct.introductoryPrice;
      if (intro != null &&
          intro.paymentMode == SKProductDiscountPaymentMode.freeTrail) {
        final n = intro.subscriptionPeriod.numberOfUnits *
            intro.numberOfPeriods;
        final unit = intro.subscriptionPeriod.unit.name;
        return '$n $unit${n == 1 ? '' : 's'}';
      }
    }
    return null;
  }

  static Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
