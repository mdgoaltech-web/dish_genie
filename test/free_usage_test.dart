import 'package:dish_genie/services/free_usage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FreeLimits', () {
    test('limits are positive compile-time constants', () {
      for (final f in FreeFeature.values) {
        expect(FreeLimits.limitFor(f), greaterThan(0));
      }
      expect(FreeLimits.aiRecipesPerDay, 3);
      expect(FreeLimits.aiChatMessagesPerDay, 10);
      expect(FreeLimits.scansPerDay, 2);
      expect(FreeLimits.mealPlansPerDay, 1);
    });
  });

  group('FreeUsage', () {
    test('counts down to zero then blocks', () {
      final usage = FreeUsage(clock: () => DateTime(2026, 9, 15, 9));
      expect(usage.remaining(FreeFeature.scan), FreeLimits.scansPerDay);
      expect(usage.record(FreeFeature.scan), isTrue);
      expect(usage.record(FreeFeature.scan), isTrue);
      expect(usage.canUse(FreeFeature.scan), isFalse);
      expect(usage.record(FreeFeature.scan), isFalse);
      expect(usage.used(FreeFeature.scan), FreeLimits.scansPerDay);
      expect(usage.remaining(FreeFeature.scan), 0);
      // Other features are independent.
      expect(usage.canUse(FreeFeature.aiRecipe), isTrue);
    });

    test('resets when the calendar day changes', () {
      var now = DateTime(2026, 9, 15, 23, 59);
      final usage = FreeUsage(clock: () => now);
      usage.record(FreeFeature.mealPlan);
      expect(usage.canUse(FreeFeature.mealPlan), isFalse);
      now = DateTime(2026, 9, 16, 0, 1);
      expect(usage.canUse(FreeFeature.mealPlan), isTrue);
      expect(usage.used(FreeFeature.mealPlan), 0);
    });

    test('JSON round trip preserves same-day counts', () {
      final now = DateTime(2026, 9, 15, 12);
      final usage = FreeUsage(clock: () => now);
      usage.record(FreeFeature.aiChat);
      usage.record(FreeFeature.aiChat);
      final loaded = FreeUsage.fromJsonString(
        usage.toJsonString(),
        clock: () => now,
      );
      expect(loaded.used(FreeFeature.aiChat), 2);

      final nextDay = FreeUsage.fromJsonString(
        usage.toJsonString(),
        clock: () => DateTime(2026, 9, 16, 12),
      );
      expect(nextDay.used(FreeFeature.aiChat), 0);

      expect(
        FreeUsage.fromJsonString('{broken', clock: () => now)
            .used(FreeFeature.aiChat),
        0,
      );
    });
  });
}
