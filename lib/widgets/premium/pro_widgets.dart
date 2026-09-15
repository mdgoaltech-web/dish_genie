import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/navigation/pro_navigation.dart';
import '../../core/theme/colors.dart';
import '../../providers/premium_provider.dart';
import '../../services/free_usage.dart';

const LinearGradient kProGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFFFFB301), Color(0xFFFD5C17)],
);

/// Crown + "PRO" pill. Every Pro-related element carries one so users can
/// see, before tapping, that it relates to the paid tier.
class ProBadge extends StatelessWidget {
  const ProBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        gradient: kProGradient,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium,
            size: compact ? 12 : 14,
            color: Colors.white,
          ),
          if (!compact) ...[
            const SizedBox(width: 3),
            Text(
              context.t('premium.pro'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
                height: 1.0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Crown button in the Home header for free users. Tapping it is one of the
/// explicit paths to the paywall. Hidden for Pro users.
class ProButton extends StatelessWidget {
  const ProButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.watch<PremiumProvider>().isPro) return const SizedBox.shrink();
    return Semantics(
      button: true,
      label: context.t('settings.upgrade'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => ProNavigation.tryOpen(context),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: kProGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.workspace_premium,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  context.t('premium.pro'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.0,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "N of M free today" chip. Shown to free users *before* they hit a limit
/// so the allowance is never a surprise. Tapping opens the paywall.
class FreeUsageChip extends StatelessWidget {
  const FreeUsageChip({super.key, required this.feature, this.compact = false});

  final FreeFeature feature;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumProvider>();
    if (premium.isPro) return const SizedBox.shrink();

    final remaining = premium.remainingToday(feature);
    final limit = premium.limitFor(feature);
    final theme = Theme.of(context);
    final label = context.t('free.left.today', {
      'remaining': '$remaining',
      'limit': '$limit',
    });

    return Semantics(
      button: true,
      label: '$label. ${context.t('settings.upgrade')}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => ProNavigation.tryOpen(context),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 5 : 8,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: remaining == 0
                    ? AppColors.primary.withValues(alpha: 0.6)
                    : theme.dividerColor.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ProBadge(compact: true),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner shown in place of a feature once the day's free allowance is used.
class LimitReachedBanner extends StatelessWidget {
  const LimitReachedBanner({super.key, required this.feature});

  final FreeFeature feature;

  static String featureLabel(BuildContext context, FreeFeature feature) {
    switch (feature) {
      case FreeFeature.aiRecipe:
        return context.t('free.feature.recipes');
      case FreeFeature.aiChat:
        return context.t('free.feature.chat');
      case FreeFeature.scan:
        return context.t('free.feature.scans');
      case FreeFeature.mealPlan:
        return context.t('free.feature.plans');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = FreeLimits.limitFor(feature);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.geniePurple.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: kProGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('free.limit.reached.title'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t('free.limit.reached.message', {
                        'limit': '$limit',
                        'feature': featureLabel(context, feature),
                      }),
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => ProNavigation.tryOpen(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const ProBadge(compact: true),
                  const SizedBox(width: 8),
                  Text(
                    context.t('settings.upgrade'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
