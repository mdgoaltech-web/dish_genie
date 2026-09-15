import 'package:dish_genie/app.dart';
import 'package:dish_genie/l10n/app_localizations.dart';
import 'package:dish_genie/providers/language_provider.dart';
import 'package:dish_genie/providers/premium_provider.dart';
import 'package:dish_genie/providers/theme_provider.dart';
import 'package:dish_genie/screens/premium/pro_screen.dart';
import 'package:dish_genie/screens/settings/settings_screen.dart';
import 'package:dish_genie/services/entitlement_store.dart';
import 'package:dish_genie/services/free_usage.dart';
import 'package:dish_genie/services/supabase_service.dart';
import 'package:dish_genie/widgets/premium/pro_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps a screen the way the app does (theme, localisation, providers).
Widget harness(Widget child, PremiumProvider premium) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<PremiumProvider>.value(value: premium),
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'dishgenie_language_selected': true,
      'app_language': 'en',
      'dishgenie_onboarding_complete': true,
      'dishgenie_first_launch': false,
    });
  });

  group('Paywall (ProScreen)', () {
    testWidgets('shows close, restore, terms and privacy even without products',
        (tester) async {
      final premium = PremiumProvider(autoInitialize: false);
      await tester.pumpWidget(harness(const ProScreen(), premium));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(ProScreen.closeButtonKey), findsOneWidget);
      expect(find.byKey(ProScreen.restoreButtonKey), findsOneWidget);
      expect(find.byKey(ProScreen.termsLinkKey), findsOneWidget);
      expect(find.byKey(ProScreen.privacyLinkKey), findsOneWidget);
      expect(find.byType(ProBadge), findsWidgets);
      // What Pro unlocks and what stays free are both stated.
      expect(find.textContaining('Unlimited AI recipe'), findsOneWidget);
      expect(find.textContaining('Free every day'), findsOneWidget);
      // No StoreKit in tests: an honest error + retry, never a hard-coded price.
      expect(find.textContaining('\$'), findsNothing);
      expect(find.byKey(ProScreen.continueButtonKey), findsNothing);
    });
  });

  group('Pro widgets', () {
    testWidgets('free usage chip shows the remaining count with a Pro badge',
        (tester) async {
      final premium = PremiumProvider(autoInitialize: false);
      await tester.pumpWidget(
        harness(
          const Scaffold(body: FreeUsageChip(feature: FreeFeature.scan)),
          premium,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProBadge), findsOneWidget);
      expect(
        find.text('${FreeLimits.scansPerDay} of ${FreeLimits.scansPerDay} free today'),
        findsOneWidget,
      );
      premium.recordUse(FreeFeature.scan);
      await tester.pumpAndSettle();
      expect(
        find.text('${FreeLimits.scansPerDay - 1} of ${FreeLimits.scansPerDay} free today'),
        findsOneWidget,
      );
    });

    testWidgets('Pro widgets disappear for Pro users', (tester) async {
      final premium = PremiumProvider(autoInitialize: false)
        ..grantForTest(ProProducts.lifetime);
      await tester.pumpWidget(
        harness(
          const Scaffold(
            body: Column(
              children: [ProButton(), FreeUsageChip(feature: FreeFeature.aiChat)],
            ),
          ),
          premium,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProBadge), findsNothing);
      expect(find.byIcon(Icons.workspace_premium), findsNothing);
    });

    testWidgets('limit banner names the feature and offers Upgrade',
        (tester) async {
      final premium = PremiumProvider(autoInitialize: false);
      await tester.pumpWidget(
        harness(
          const Scaffold(body: LimitReachedBanner(feature: FreeFeature.aiChat)),
          premium,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('chat messages'), findsOneWidget);
      expect(find.text('Upgrade to Pro'), findsOneWidget);
      expect(find.byType(ProBadge), findsOneWidget);
    });
  });

  group('Settings', () {
    testWidgets('has badged Upgrade, Restore Purchases and Manage Subscription',
        (tester) async {
      final premium = PremiumProvider(autoInitialize: false);
      await tester.pumpWidget(harness(const SettingsScreen(), premium));
      await tester.pumpAndSettle();
      expect(find.byKey(SettingsScreen.upgradeKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(SettingsScreen.upgradeKey),
          matching: find.byType(ProBadge),
        ),
        findsOneWidget,
      );
      expect(find.byKey(SettingsScreen.restoreKey), findsOneWidget);
      expect(find.byKey(SettingsScreen.manageSubscriptionKey), findsOneWidget);
      await tester.dragUntilVisible(
        find.textContaining('Version 1.0.9'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      expect(find.textContaining('Version 1.0.9'), findsOneWidget);
    });

    testWidgets('shows the active plan instead of Upgrade for Pro users',
        (tester) async {
      final premium = PremiumProvider(autoInitialize: false)
        ..grantForTest(ProProducts.lifetime);
      await tester.pumpWidget(harness(const SettingsScreen(), premium));
      await tester.pumpAndSettle();
      expect(find.byKey(SettingsScreen.upgradeKey), findsNothing);
      expect(find.text('Pro is active'), findsOneWidget);
    });
  });

  group('App launch', () {
    testWidgets(
        'fresh free install lands on Home with a badged crown and never auto-opens the paywall',
        (tester) async {
      final premium = PremiumProvider(autoInitialize: false);
      await tester.pumpWidget(App(premiumProvider: premium));
      // Splash animation + start-up timeout.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byType(ProScreen), findsNothing);
      expect(find.byType(ProButton), findsOneWidget);
      expect(find.byType(ProBadge), findsWidgets);
      expect(find.byType(FreeUsageChip), findsWidgets);

      // Idle for a long time: still no paywall.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byType(ProScreen), findsNothing);

      // Tapping the crown is the explicit path to the paywall.
      await tester.tap(find.byType(ProButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ProScreen), findsOneWidget);
      await tester.tap(find.byKey(ProScreen.closeButtonKey));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ProScreen), findsNothing);

      // Tab switches never open the paywall either.
      for (final icon in [
        Icons.calendar_month_outlined,
        Icons.shopping_cart_outlined,
        Icons.chat_bubble_outline,
        Icons.restaurant_menu_outlined,
      ]) {
        await tester.tap(find.byIcon(icon).first, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(ProScreen), findsNothing, reason: icon.toString());
      }

      await tester.pumpWidget(const SizedBox());
      await SupabaseService.dispose();
    });
  });
}
