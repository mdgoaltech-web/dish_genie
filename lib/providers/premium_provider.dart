import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/billing_service.dart';
import '../services/entitlement_store.dart';
import '../services/free_usage.dart';
import '../services/storage_service.dart';

/// Single source of truth for "is this user Pro" and for the free tier's
/// daily allowances.
///
/// Startup: the last verified entitlement is read from local storage so the
/// UI is correct immediately, then StoreKit is asked for its current
/// entitlements and the cache is replaced with whatever it reports. If a
/// subscription has lapsed, StoreKit no longer lists it and Pro ends.
class PremiumProvider with ChangeNotifier {
  PremiumProvider({
    bool autoInitialize = true,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _entitlements = EntitlementStore(clock: clock),
       _usage = FreeUsage(clock: clock) {
    if (autoInitialize) {
      unawaited(_init());
    } else {
      _ready.complete();
    }
  }

  static const String entitlementCacheKey = 'recipe_keeper_entitlements';
  static const String usageKey = 'recipe_keeper_free_usage';

  final DateTime Function() _clock;
  EntitlementStore _entitlements;
  FreeUsage _usage;
  StreamSubscription<PurchaseDetails>? _billingEvents;
  final Completer<void> _ready = Completer<void>();
  bool _verified = false;
  bool _purchaseInProgress = false;
  String? _lastPurchaseError;
  DateTime? _lastVerification;

  bool get isPro => _entitlements.isPro;
  ProEntitlement? get activeEntitlement => _entitlements.activeEntitlement;

  /// True once StoreKit has answered at least once this session.
  bool get isVerified => _verified;
  bool get purchaseInProgress => _purchaseInProgress;
  String? get lastPurchaseError => _lastPurchaseError;

  /// Completes when the cached state is loaded and the first StoreKit
  /// verification has finished (or failed).
  Future<void> get ready => _ready.future;

  // ---------------------------------------------------------------- limits

  int limitFor(FreeFeature feature) => _usage.limit(feature);
  int usedToday(FreeFeature feature) => _usage.used(feature);
  int remainingToday(FreeFeature feature) => _usage.remaining(feature);

  /// Pro users are never limited.
  bool canUse(FreeFeature feature) => isPro || _usage.canUse(feature);

  /// Counts one use for free users. Returns false when the allowance is
  /// exhausted. Pro users always get true and nothing is counted.
  bool recordUse(FreeFeature feature) {
    if (isPro) return true;
    final ok = _usage.record(feature);
    if (ok) {
      unawaited(StorageService.setValue(usageKey, _usage.toJsonString()));
      notifyListeners();
    }
    return ok;
  }

  // -------------------------------------------------------------- lifecycle

  Future<void> _init() async {
    try {
      await StorageService.initialize();
      final cachedEntitlements = await StorageService.getValue<String>(
        PremiumProvider.entitlementCacheKey,
        null,
      );
      final cachedUsage = await StorageService.getValue<String>(
        PremiumProvider.usageKey,
        null,
      );
      _entitlements = EntitlementStore.fromJsonString(
        cachedEntitlements,
        clock: _clock,
      );
      _usage = FreeUsage.fromJsonString(cachedUsage, clock: _clock);
      notifyListeners();

      await BillingService.initialize();
      _billingEvents ??= BillingService.events.listen(_onBillingEvent);
      await refreshEntitlements();
    } catch (e) {
      if (kDebugMode) debugPrint('[Premium] init failed: $e');
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  /// Ask StoreKit for its current entitlements and adopt the answer.
  /// Keeps the cached state when StoreKit cannot be queried.
  Future<void> refreshEntitlements() async {
    final verified = await BillingService.verifyEntitlements();
    if (verified != null) {
      _entitlements.replaceWith(verified);
      // Purchases completed in this session but not yet listed by StoreKit's
      // entitlement enumeration (rare, right after buying) stay granted.
      for (final e in BillingService.liveEntitlements.entitlements) {
        _entitlements.grant(e.productId, expiresAt: e.expiresAt);
      }
      _verified = true;
      _lastVerification = _clock();
      await _persist();
    }
    notifyListeners();
  }

  /// Cheap re-check when the app returns to the foreground (throttled).
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(minutes: 15),
  }) async {
    final last = _lastVerification;
    if (last != null && _clock().difference(last) < maxAge) return;
    await refreshEntitlements();
  }

  void _onBillingEvent(PurchaseDetails purchase) {
    switch (purchase.status) {
      case PurchaseStatus.purchased:
        _entitlements.grant(
          purchase.productID,
          expiresAt: BillingService.expirationOf(purchase),
        );
        _purchaseInProgress = false;
        _lastPurchaseError = null;
        unawaited(_persist());
        break;
      case PurchaseStatus.restored:
        // Restores outside an explicit verification also grant.
        _entitlements.grant(
          purchase.productID,
          expiresAt: BillingService.expirationOf(purchase),
        );
        unawaited(_persist());
        break;
      case PurchaseStatus.error:
        _purchaseInProgress = false;
        _lastPurchaseError = purchase.error?.message ?? 'Purchase failed';
        break;
      case PurchaseStatus.canceled:
        _purchaseInProgress = false;
        _lastPurchaseError = null;
        break;
      case PurchaseStatus.pending:
        _purchaseInProgress = true;
        break;
    }
    notifyListeners();
  }

  /// Starts a purchase from the paywall.
  Future<bool> purchase(ProductDetails product) async {
    _lastPurchaseError = null;
    _purchaseInProgress = true;
    notifyListeners();
    final started = await BillingService.purchase(product);
    if (!started) {
      _purchaseInProgress = false;
      _lastPurchaseError = BillingService.lastError ?? 'Purchase failed';
      notifyListeners();
    }
    return started;
  }

  /// "Restore Purchases" from the paywall or Settings. Returns true when a
  /// Pro entitlement was found.
  Future<bool> restorePurchases() async {
    final restored = await BillingService.restorePurchases();
    if (restored != null) {
      _entitlements.replaceWith(restored);
      _verified = true;
      _lastVerification = _clock();
      await _persist();
    }
    notifyListeners();
    return isPro;
  }

  /// Used by tests and by billing-free environments to seed state.
  @visibleForTesting
  void applyVerifiedEntitlements(EntitlementStore store) {
    _entitlements.replaceWith(store);
    _verified = true;
    notifyListeners();
  }

  @visibleForTesting
  void grantForTest(String productId, {DateTime? expiresAt}) {
    _entitlements.grant(productId, expiresAt: expiresAt);
    notifyListeners();
  }

  Future<void> _persist() async {
    await StorageService.setValue(
      entitlementCacheKey,
      _entitlements.toJsonString(),
    );
  }

  @override
  void dispose() {
    _billingEvents?.cancel();
    super.dispose();
  }
}
