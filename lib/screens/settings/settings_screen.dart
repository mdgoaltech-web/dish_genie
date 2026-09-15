import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_links.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/localization/language_config.dart';
import '../../core/navigation/pro_navigation.dart';
import '../../core/theme/colors.dart';
import '../../providers/language_provider.dart';
import '../../providers/premium_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/entitlement_store.dart';
import '../../widgets/common/rtl_icon.dart';
import '../../widgets/common/sticky_header.dart';
import '../../widgets/premium/pro_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const Key upgradeKey = Key('settings-upgrade');
  static const Key restoreKey = Key('settings-restore');
  static const Key manageSubscriptionKey = Key('settings-manage-subscription');

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _restoring = false;

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.destructive : AppColors.primary,
      ),
    );
  }

  /// Opens the mail app with the support address pre-filled.
  Future<void> _openFeedbackEmail() async {
    final emailUri = Uri.parse(
      'mailto:${AppLinks.supportEmail}?subject=${Uri.encodeComponent('Recipe Keeper feedback')}',
    );
    try {
      if (await launchUrl(emailUri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
    _snack(
      '${context.t('settings.feedback')}: ${AppLinks.supportEmail}',
      error: true,
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('settings.faq.title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final i in [1, 2, 3, 4]) ...[
                Text(
                  context.t('settings.faq$i.q'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t('settings.faq$i.a'),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (i != 4) const SizedBox(height: 16),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('common.close')),
          ),
        ],
      ),
    );
  }

  Future<void> _shareApp() async {
    try {
      final size = MediaQuery.of(context).size;
      await Share.share(
        'Recipe Keeper: AI meal ideas from the ingredients you already have. ${AppLinks.appStoreUrl}',
        subject: 'Recipe Keeper',
        sharePositionOrigin: Rect.fromLTWH(0, 0, size.width, size.height),
      );
    } catch (e) {
      _snack(context.t('commonErrorMessage', {'error': e.toString()}),
          error: true);
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    _snack(context.t('commonCouldNotOpenUrl', {'url': url}), error: true);
  }

  Future<void> _restorePurchases() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    final found = await context.read<PremiumProvider>().restorePurchases();
    if (!mounted) return;
    setState(() => _restoring = false);
    _snack(
      found
          ? context.t('premium.purchases.restored')
          : context.t('paywall.nothing.to.restore'),
      error: !found,
    );
  }

  Future<void> _showRateUsDialog() async {
    var rating = 5;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        const gradientA = Color(0xFF40CFB2);
        const gradientB = Color(0xFF57A2F3);
        const starOn = Color(0xFFFFC107);
        const starOff = Color(0xFFD6D6D6);

        Future<void> handlePrimary(int currentRating) async {
          Navigator.of(ctx).pop();
          if (currentRating <= 3) {
            await _openFeedbackEmail();
          } else {
            await _launchURL(AppLinks.appStoreUrl);
          }
        }

        return StatefulBuilder(
          builder: (context, setLocal) {
            final primaryText = rating <= 3
                ? ctx.t('rate.dialog.feedback')
                : ctx.t('rate.dialog.rate.now');
            final screenW = MediaQuery.sizeOf(ctx).width;
            final starIconSize = screenW < 340 ? 30.0 : 38.0;

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    color: isDark ? theme.cardColor : Colors.white,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [gradientA, gradientB],
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.restaurant,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                ctx.t('rate.dialog.title'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                ctx.t('rate.dialog.subtitle'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                          child: Column(
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(5, (i) {
                                    final idx = i + 1;
                                    final active = idx <= rating;
                                    return IconButton(
                                      onPressed: () =>
                                          setLocal(() => rating = idx),
                                      icon: Icon(
                                        active ? Icons.star : Icons.star_border,
                                        color: active ? starOn : starOff,
                                        size: starIconSize,
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                ctx.t('rate.dialog.body'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF3E484D),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: () => handlePrimary(rating),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: gradientB,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child: Text(
                                    primaryText,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: Text(ctx.t('rate.dialog.maybe.later')),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _planName(BuildContext context, ProEntitlement e) {
    switch (e.productId) {
      case ProProducts.weekly:
        return context.t('premium.plan.weekly');
      case ProProducts.yearly:
        return context.t('premium.plan.yearly');
      default:
        return context.t('premium.plan.lifetime');
    }
  }

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumProvider>();
    final active = premium.activeEntitlement;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.gradientHeroDark
                  : AppColors.gradientHero,
            ),
          ),
          Column(
            children: [
              StickyHeader(
                title: context.t('settings.title'),
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                backgroundColor: Colors.transparent,
                statusBarColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1A1F35)
                    : AppColors.genieBlush,
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(
                    top: 12,
                    bottom: 12 + MediaQuery.of(context).padding.bottom,
                  ),
                  children: [
                    _section(context.t('settings.pro.section')),
                    if (!premium.isPro)
                      _item(
                        key: SettingsScreen.upgradeKey,
                        icon: Icons.workspace_premium,
                        title: context.t('settings.upgrade'),
                        subtitle: context.t('settings.upgrade.subtitle'),
                        rightElement: const ProBadge(),
                        onTap: () => ProNavigation.tryOpen(context),
                      )
                    else
                      _item(
                        icon: Icons.verified,
                        title: context.t('settings.pro.active'),
                        subtitle: active == null
                            ? null
                            : [
                                context.t('settings.pro.active.subtitle', {
                                  'plan': _planName(context, active),
                                }),
                                if (active.expiresAt != null)
                                  context.t('settings.pro.expires', {
                                    'date': DateFormat.yMMMd(
                                      Localizations.localeOf(
                                        context,
                                      ).toString(),
                                    ).format(active.expiresAt!),
                                  }),
                              ].join('\n'),
                        rightElement: const ProBadge(),
                      ),
                    _gap(),
                    _item(
                      key: SettingsScreen.restoreKey,
                      icon: Icons.restore,
                      title: context.t('premium.restore.purchases'),
                      subtitle: context.t('settings.restore.purchases.subtitle'),
                      rightElement: _restoring
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      onTap: _restorePurchases,
                    ),
                    _gap(),
                    _item(
                      key: SettingsScreen.manageSubscriptionKey,
                      icon: Icons.autorenew,
                      title: context.t('settings.manage.subscription'),
                      subtitle: context.t(
                        'settings.manage.subscription.subtitle',
                      ),
                      onTap: () => _launchURL(AppLinks.manageSubscriptionsUrl),
                    ),
                    const SizedBox(height: 16),
                    _item(
                      icon: Icons.favorite_border,
                      title: context.t('common.favorites'),
                      subtitle: context.t('favorites.subtitle'),
                      onTap: () => context.push('/favorites'),
                    ),
                    const SizedBox(height: 12),
                    _section(context.t('settings.language')),
                    Consumer<LanguageProvider>(
                      builder: (context, languageProvider, _) {
                        final code = languageProvider.locale.languageCode;
                        final name =
                            LanguageConfig.getLanguageByCode(code)?.name ??
                            'English';
                        return _item(
                          icon: Icons.language,
                          title: context.t('settings.language'),
                          subtitle: name,
                          onTap: () => context.push('/language-picker'),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _section(context.t('settingsAppearance')),
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, _) {
                        return Column(
                          children: [
                            for (final entry in {
                              ThemeMode.light: (
                                context.t('settingsThemeLight'),
                                Icons.light_mode,
                              ),
                              ThemeMode.dark: (
                                context.t('settingsThemeDark'),
                                Icons.dark_mode,
                              ),
                              ThemeMode.system: (
                                context.t('settingsThemeSystem'),
                                Icons.brightness_auto,
                              ),
                            }.entries) ...[
                              _themeOption(
                                label: entry.value.$1,
                                icon: entry.value.$2,
                                isSelected: themeProvider.themeMode == entry.key,
                                onTap: () =>
                                    themeProvider.setThemeMode(entry.key),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _section(context.t('settings.support')),
                    _item(
                      icon: Icons.feedback,
                      title: context.t('settings.feedback'),
                      subtitle: context.t('settings.feedback.subtitle'),
                      onTap: _openFeedbackEmail,
                    ),
                    _gap(),
                    _item(
                      icon: Icons.star,
                      title: context.t('settings.rate.us'),
                      subtitle: context.t('settings.rate.us.subtitle'),
                      onTap: _showRateUsDialog,
                    ),
                    _gap(),
                    _item(
                      icon: Icons.share,
                      title: context.t('settings.share.app'),
                      subtitle: context.t('settings.share.app.subtitle'),
                      onTap: _shareApp,
                    ),
                    _gap(),
                    _item(
                      icon: Icons.help_outline,
                      title: context.t('settings.help.support'),
                      subtitle: context.t('settings.help.support.subtitle'),
                      onTap: _showHelpDialog,
                    ),
                    const SizedBox(height: 16),
                    _section(context.t('settings.legal')),
                    _item(
                      icon: Icons.privacy_tip,
                      title: context.t('settings.privacy.policy'),
                      onTap: () => _launchURL(AppLinks.privacyPolicyUrl),
                    ),
                    _gap(),
                    _item(
                      icon: Icons.description,
                      title: context.t('premium.terms.of.use'),
                      onTap: () => _launchURL(AppLinks.termsOfUseUrl),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '${context.t('common.version')} ${AppLinks.version}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 6);

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _themeOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: _cardDecoration(),
            child: Row(
              children: [
                _iconBox(icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.muted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 16,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _item({
    Key? key,
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? rightElement,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: _cardDecoration(),
            child: Row(
              children: [
                _iconBox(icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                rightElement ??
                    (onTap == null
                        ? const SizedBox.shrink()
                        : RtlChevronRight(
                            size: 20,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
