import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/premium_provider.dart';
import '../router/app_router.dart';

/// The only way the paywall is opened.
///
/// Callers are explicit user taps (Pro badge, Home crown, Settings > Upgrade)
/// or a free daily limit being hit. Nothing opens it on launch, after
/// onboarding, on a timer or on tab switch.
class ProNavigation {
  ProNavigation._();

  /// Opens the paywall. Returns false when the user is already Pro.
  static Future<bool> tryOpen(
    BuildContext context, {
    bool replace = false,
  }) async {
    if (!context.mounted) return false;
    if (context.read<PremiumProvider>().isPro) return false;
    if (replace) {
      context.go(AppRouter.proRoute);
    } else {
      context.push(AppRouter.proRoute);
    }
    return true;
  }
}
