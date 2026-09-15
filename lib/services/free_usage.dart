import 'dart:convert';

/// Features that free users can use a limited number of times per day.
enum FreeFeature { aiRecipe, aiChat, scan, mealPlan }

/// Daily allowances for the free tier. These are compile-time constants:
/// nothing remote, no platform or date switch can change them.
class FreeLimits {
  FreeLimits._();

  static const int aiRecipesPerDay = 3;
  static const int aiChatMessagesPerDay = 10;
  static const int scansPerDay = 2;
  static const int mealPlansPerDay = 1;

  static int limitFor(FreeFeature feature) {
    switch (feature) {
      case FreeFeature.aiRecipe:
        return aiRecipesPerDay;
      case FreeFeature.aiChat:
        return aiChatMessagesPerDay;
      case FreeFeature.scan:
        return scansPerDay;
      case FreeFeature.mealPlan:
        return mealPlansPerDay;
    }
  }
}

/// Pure, testable daily usage counters for the free tier.
///
/// Counts reset automatically when the calendar day (device local time)
/// changes. Serialises to JSON so [PremiumProvider] can persist it.
class FreeUsage {
  FreeUsage({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<FreeFeature, int> _counts = {};
  String _day = '';

  static String dayKey(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  void _rollDayIfNeeded() {
    final today = dayKey(_clock());
    if (_day != today) {
      _day = today;
      _counts.clear();
    }
  }

  int used(FreeFeature feature) {
    _rollDayIfNeeded();
    return _counts[feature] ?? 0;
  }

  int limit(FreeFeature feature) => FreeLimits.limitFor(feature);

  int remaining(FreeFeature feature) =>
      (limit(feature) - used(feature)).clamp(0, limit(feature));

  bool canUse(FreeFeature feature) => remaining(feature) > 0;

  /// Records one use. Returns false (and records nothing) when the daily
  /// allowance is already exhausted.
  bool record(FreeFeature feature) {
    if (!canUse(feature)) return false;
    _counts[feature] = used(feature) + 1;
    return true;
  }

  String toJsonString() {
    _rollDayIfNeeded();
    return jsonEncode({
      'day': _day,
      'counts': {for (final e in _counts.entries) e.key.name: e.value},
    });
  }

  static FreeUsage fromJsonString(String? json, {DateTime Function()? clock}) {
    final usage = FreeUsage(clock: clock);
    if (json == null || json.isEmpty) return usage;
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) {
        final day = decoded['day'];
        final counts = decoded['counts'];
        if (day is String && counts is Map) {
          usage._day = day;
          for (final entry in counts.entries) {
            final feature = FreeFeature.values
                .where((f) => f.name == entry.key)
                .firstOrNull;
            final value = entry.value;
            if (feature != null && value is int && value >= 0) {
              usage._counts[feature] = value;
            }
          }
        }
      }
    } catch (_) {
      // Corrupt data: start the day fresh.
    }
    usage._rollDayIfNeeded();
    return usage;
  }
}
