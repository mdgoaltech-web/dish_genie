import 'dart:convert';

/// App Store product identifiers for Recipe Keeper Pro.
///
/// These are the only products the app sells. All three unlock the same
/// "Pro" entitlement; they differ only in how long it lasts.
class ProProducts {
  ProProducts._();

  /// Auto-renewable subscription, 1 week.
  static const String weekly = 'weekly_sub_chef';

  /// Auto-renewable subscription, 1 year.
  static const String yearly = 'yearly_sub_chef';

  /// Non-consumable one-time purchase.
  static const String lifetime = 'recipe_lifetime_purchase';

  static const Set<String> all = {weekly, yearly, lifetime};

  static bool isPro(String productId) => all.contains(productId);

  static bool isSubscription(String productId) =>
      productId == weekly || productId == yearly;
}

/// One active Pro entitlement as reported by StoreKit.
class ProEntitlement {
  const ProEntitlement({required this.productId, this.expiresAt});

  final String productId;

  /// Null for the non-consumable lifetime purchase.
  final DateTime? expiresAt;

  bool isActiveAt(DateTime now) =>
      expiresAt == null || expiresAt!.isAfter(now);

  Map<String, dynamic> toJson() => {
    'productId': productId,
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
  };

  static ProEntitlement? fromJson(Map<String, dynamic> json) {
    final id = json['productId'];
    if (id is! String || !ProProducts.isPro(id)) return null;
    final raw = json['expiresAt'];
    DateTime? expires;
    if (raw is String) expires = DateTime.tryParse(raw);
    return ProEntitlement(productId: id, expiresAt: expires);
  }
}

/// Pure, testable entitlement state machine.
///
/// It knows nothing about StoreKit: [BillingService] feeds it purchase and
/// restore events, and [PremiumProvider] persists/reads it. A user is Pro when
/// at least one entitlement is active *now* – a lifetime purchase, or a
/// subscription whose expiry is in the future. When a subscription lapses the
/// entitlement simply stops being active; a fresh verification against
/// StoreKit (which only reports current entitlements) will drop it entirely.
class EntitlementStore {
  EntitlementStore({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, ProEntitlement> _entitlements = {};

  /// All entitlements currently held, active or not.
  List<ProEntitlement> get entitlements =>
      List.unmodifiable(_entitlements.values);

  /// True when any held entitlement is active at the current time.
  bool get isPro =>
      _entitlements.values.any((e) => e.isActiveAt(_clock()));

  /// The entitlement that grants Pro right now, if any. Lifetime wins over
  /// subscriptions; otherwise the latest-expiring subscription.
  ProEntitlement? get activeEntitlement {
    final now = _clock();
    final active = _entitlements.values.where((e) => e.isActiveAt(now));
    ProEntitlement? best;
    for (final e in active) {
      if (e.expiresAt == null) return e;
      if (best == null || e.expiresAt!.isAfter(best.expiresAt!)) best = e;
    }
    return best;
  }

  /// Record a verified purchase or restore. Ignores non-Pro products and
  /// subscriptions that are already expired.
  bool grant(String productId, {DateTime? expiresAt}) {
    if (!ProProducts.isPro(productId)) return false;
    if (expiresAt != null && !expiresAt.isAfter(_clock())) return false;
    _entitlements[productId] = ProEntitlement(
      productId: productId,
      expiresAt: expiresAt,
    );
    return true;
  }

  /// Drop everything (used before re-verifying from StoreKit).
  void clear() => _entitlements.clear();

  /// Replace the current contents with [other]'s.
  void replaceWith(EntitlementStore other) {
    _entitlements
      ..clear()
      ..addAll(other._entitlements);
  }

  String toJsonString() =>
      jsonEncode(_entitlements.values.map((e) => e.toJson()).toList());

  /// Loads a snapshot previously written by [toJsonString]. Malformed input
  /// yields an empty store.
  static EntitlementStore fromJsonString(
    String? json, {
    DateTime Function()? clock,
  }) {
    final store = EntitlementStore(clock: clock);
    if (json == null || json.isEmpty) return store;
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final e = ProEntitlement.fromJson(item);
            if (e != null) store._entitlements[e.productId] = e;
          }
        }
      }
    } catch (_) {
      // Corrupt cache: start empty; StoreKit verification will rebuild it.
    }
    return store;
  }
}
