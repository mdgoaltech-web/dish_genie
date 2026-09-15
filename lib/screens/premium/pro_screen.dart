import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_links.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/theme/colors.dart';
import '../../providers/premium_provider.dart';
import '../../services/billing_service.dart';
import '../../services/entitlement_store.dart';
import '../../services/free_usage.dart';
import '../../widgets/premium/pro_widgets.dart';

/// The paywall. Prices always come from StoreKit; trial wording appears only
/// when StoreKit reports a free-trial introductory offer.
class ProScreen extends StatefulWidget {
  const ProScreen({super.key});

  static const Key closeButtonKey = Key('paywall-close');
  static const Key restoreButtonKey = Key('paywall-restore');
  static const Key continueButtonKey = Key('paywall-continue');
  static const Key termsLinkKey = Key('paywall-terms');
  static const Key privacyLinkKey = Key('paywall-privacy');

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  bool _loadingProducts = true;
  bool _restoring = false;
  String _selectedId = ProProducts.yearly;
  PremiumProvider? _premium;
  bool _wasPro = false;
  String? _lastShownError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _premium = context.read<PremiumProvider>();
      _wasPro = _premium!.isPro;
      _premium!.addListener(_onPremiumChanged);
    });
    unawaited(_loadProducts());
  }

  @override
  void dispose() {
    _premium?.removeListener(_onPremiumChanged);
    super.dispose();
  }

  Future<void> _loadProducts() async {
    if (mounted) setState(() => _loadingProducts = true);
    await BillingService.initialize();
    if (BillingService.products.isEmpty) {
      await BillingService.loadProducts();
    }
    if (!mounted) return;
    if (BillingService.product(_selectedId) == null &&
        BillingService.products.isNotEmpty) {
      _selectedId = BillingService.products.first.id;
    }
    setState(() => _loadingProducts = false);
  }

  void _onPremiumChanged() {
    final premium = _premium;
    if (premium == null || !mounted) return;
    if (premium.isPro && !_wasPro) {
      _wasPro = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('premium.welcome.message')),
          backgroundColor: AppColors.primary,
        ),
      );
      _close();
      return;
    }
    final error = premium.lastPurchaseError;
    if (error != null && error != _lastShownError) {
      _lastShownError = error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.destructive),
      );
    }
    setState(() {});
  }

  void _close() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _buy() async {
    final product = BillingService.product(_selectedId);
    if (product == null) return;
    await context.read<PremiumProvider>().purchase(product);
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    final found = await context.read<PremiumProvider>().restorePurchases();
    if (!mounted) return;
    setState(() => _restoring = false);
    if (!found) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('paywall.nothing.to.restore'))),
      );
    }
    // A successful restore flips isPro and _onPremiumChanged closes the
    // screen with the welcome message.
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('commonCouldNotOpenUrl', {'url': url})),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumProvider>();
    final theme = Theme.of(context);
    final products = BillingService.products;
    final selected = BillingService.product(_selectedId);
    final busy = premium.purchaseInProgress || _restoring;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.getGradientHero(context)),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 36),
                    Center(
                      child: Image.asset(
                        'assets/pro_top_new.png',
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            context.t('paywall.title'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const ProBadge(),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.t('paywall.subtitle'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _FeatureRow(text: context.t('paywall.feature.recipes')),
                    _FeatureRow(text: context.t('paywall.feature.chat')),
                    _FeatureRow(text: context.t('paywall.feature.scans')),
                    _FeatureRow(text: context.t('paywall.feature.plans')),
                    const SizedBox(height: 8),
                    Text(
                      context.t('paywall.free.tier.note', {
                        'recipes': '${FreeLimits.aiRecipesPerDay}',
                        'chat': '${FreeLimits.aiChatMessagesPerDay}',
                        'scans': '${FreeLimits.scansPerDay}',
                        'plans': '${FreeLimits.mealPlansPerDay}',
                      }),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_loadingProducts)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (products.isEmpty)
                      _LoadError(onRetry: _loadProducts)
                    else ...[
                      for (final product in _ordered(products))
                        _PlanCard(
                          product: product,
                          selected: product.id == _selectedId,
                          onTap: busy
                              ? null
                              : () =>
                                    setState(() => _selectedId = product.id),
                        ),
                      const SizedBox(height: 8),
                      if (selected != null &&
                          BillingService.hasFreeTrial(selected))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            context.t('paywall.trial.then', {
                              'trial':
                                  BillingService.freeTrialDescription(
                                    selected,
                                  ) ??
                                  '',
                              'price': selected.price,
                            }),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          key: ProScreen.continueButtonKey,
                          onPressed: busy || selected == null ? null : _buy,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: premium.purchaseInProgress
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  selected == null
                                      ? context.t('paywall.continue')
                                      : '${context.t('paywall.continue')} · ${selected.price}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        selected != null &&
                                ProProducts.isSubscription(selected.id)
                            ? context.t('paywall.auto.renew.disclosure')
                            : context.t('paywall.lifetime.disclosure'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11.5,
                          height: 1.35,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      runSpacing: 0,
                      children: [
                        TextButton(
                          key: ProScreen.restoreButtonKey,
                          onPressed: busy ? null : _restore,
                          child: _restoring
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(context.t('premium.restore.purchases')),
                        ),
                        TextButton(
                          key: ProScreen.termsLinkKey,
                          onPressed: () => _open(AppLinks.termsOfUseUrl),
                          child: Text(context.t('premium.terms.of.use')),
                        ),
                        TextButton(
                          key: ProScreen.privacyLinkKey,
                          onPressed: () => _open(AppLinks.privacyPolicyUrl),
                          child: Text(context.t('premium.privacy.policy')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PositionedDirectional(
                top: 4,
                end: 8,
                child: IconButton(
                  key: ProScreen.closeButtonKey,
                  tooltip: context.t('common.close'),
                  icon: const Icon(Icons.close),
                  onPressed: _close,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Weekly, yearly, lifetime – in that order, whichever StoreKit returned.
  static List<ProductDetails> _ordered(List<ProductDetails> products) {
    const order = [
      ProProducts.weekly,
      ProProducts.yearly,
      ProProducts.lifetime,
    ];
    final byId = {for (final p in products) p.id: p};
    return [
      for (final id in order)
        if (byId[id] != null) byId[id]!,
    ];
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              gradient: kProGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.product,
    required this.selected,
    required this.onTap,
  });

  final ProductDetails product;
  final bool selected;
  final VoidCallback? onTap;

  String _name(BuildContext context) {
    switch (product.id) {
      case ProProducts.weekly:
        return context.t('premium.plan.weekly');
      case ProProducts.yearly:
        return context.t('premium.plan.yearly');
      default:
        return context.t('premium.plan.lifetime');
    }
  }

  String _period(BuildContext context) {
    switch (product.id) {
      case ProProducts.weekly:
        return context.t('paywall.per.week');
      case ProProducts.yearly:
        return context.t('paywall.per.year');
      default:
        return context.t('paywall.one.time');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('plan-${product.id}'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : theme.dividerColor.withValues(alpha: 0.5),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected
                      ? AppColors.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name(context),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _period(context),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  product.price,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
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

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          Icons.cloud_off,
          size: 40,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 8),
        Text(
          context.t('paywall.load.error'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRetry,
          child: Text(context.t('paywall.retry')),
        ),
      ],
    );
  }
}
