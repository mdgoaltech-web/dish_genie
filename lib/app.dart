import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'providers/chat_provider.dart';
import 'providers/grocery_provider.dart';
import 'providers/language_provider.dart';
import 'providers/meal_plan_provider.dart';
import 'providers/premium_provider.dart';
import 'providers/recipe_provider.dart';
import 'providers/theme_provider.dart';

class App extends StatefulWidget {
  const App({super.key, this.premiumProvider});

  /// Injected by tests; the app creates its own when null.
  final PremiumProvider? premiumProvider;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  GoRouter? _router;
  PremiumProvider? _premium;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check the subscription when coming back to the foreground so a
    // lapsed subscription ends Pro without a relaunch.
    if (state == AppLifecycleState.resumed) {
      _premium?.refreshIfStale();
    }
  }

  GoRouter _getOrCreateRouter(LanguageProvider languageProvider) {
    return _router ??= AppRouter.createRouter(languageProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => GroceryProvider()),
        ChangeNotifierProvider<PremiumProvider>(
          create: (_) => _premium = widget.premiumProvider ?? PremiumProvider(),
        ),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => MealPlanProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: Consumer2<LanguageProvider, ThemeProvider>(
        builder: (context, languageProvider, themeProvider, _) {
          final router = _getOrCreateRouter(languageProvider);

          return MaterialApp.router(
            title: 'Recipe Keeper',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            locale: languageProvider.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
            builder: (context, child) {
              final theme = Theme.of(context);
              final isDark = theme.brightness == Brightness.dark;

              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: theme.scaffoldBackgroundColor,
                  statusBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                  statusBarBrightness: isDark
                      ? Brightness.dark
                      : Brightness.light,
                  systemStatusBarContrastEnforced: false,
                ),
                child: Directionality(
                  textDirection: languageProvider.textDirection,
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
