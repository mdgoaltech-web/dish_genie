import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/theme/colors.dart';
import '../../providers/premium_provider.dart';
import '../../services/startup_service.dart';
import '../../services/storage_service.dart';

/// Launch screen. Waits for start-up work, then goes to language selection
/// (first run) or straight to Home. It never opens the paywall.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Duration _minSplashDuration = Duration(milliseconds: 1500);
  static const Duration _maxWait = Duration(seconds: 4);

  late AnimationController _stageController;
  late AnimationController _bounceController;
  late AnimationController _dotsController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _translateAnimation;
  int _stage = 0;

  @override
  void initState() {
    super.initState();

    _stageController = AnimationController(
      duration: _minSplashDuration,
      vsync: this,
    );
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _stageController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _stageController,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );
    _translateAnimation = Tween<double>(begin: 16.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _stageController,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _stage = 1);
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _stage = 2);
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _stage = 3);
    });

    _stageController.forward();
    unawaited(_navigateNext());
  }

  Future<void> _navigateNext() async {
    final premium = context.read<PremiumProvider>();

    // Start-up work and the StoreKit entitlement check run in parallel with
    // the splash animation; neither may block the user for long.
    final work = Future.wait<void>([
      StartupService.start(),
      premium.ready,
    ]).timeout(_maxWait, onTimeout: () => <void>[]);

    await Future.wait([Future.delayed(_minSplashDuration), work]);
    if (!mounted) return;

    bool languageSelected = false;
    try {
      languageSelected = await StorageService.isLanguageSelected();
    } catch (_) {}
    if (!mounted) return;

    context.go(languageSelected ? '/' : '/language-selection');
  }

  @override
  void dispose() {
    _stageController.dispose();
    _bounceController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.getGradientHero(context)),
        child: Stack(
          children: [
            ...List.generate(8, (i) {
              return Positioned(
                left: (10 + i * 12) * size.width / 100,
                top: (20 + (i % 3) * 25) * size.height / 100,
                child: AnimatedOpacity(
                  opacity: _stage >= 1 ? 0.4 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.geniePurple.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _scaleAnimation,
                      _bounceController,
                    ]),
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _stage >= 1 ? _scaleAnimation.value : 0.0,
                        child: Opacity(
                          opacity: _stage >= 1 ? 1.0 : 0.0,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 256,
                                height: 256,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.geniePurple.withValues(alpha: 
                                        _stage >= 2 ? 0.6 : 0.0,
                                      ),
                                      blurRadius: 72,
                                      spreadRadius: _stage >= 2 ? 36 : 0,
                                    ),
                                  ],
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(
                                  0,
                                  _stage >= 1
                                      ? math.sin(
                                              _bounceController.value *
                                                  2 *
                                                  math.pi,
                                            ) *
                                            8
                                      : 0,
                                ),
                                child: Image.asset(
                                  'assets/pro_top_new.png',
                                  width: 176,
                                  height: 176,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _stage >= 2 ? _fadeAnimation.value : 0.0,
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            _stage >= 2 ? (1 - _translateAnimation.value) : 16,
                          ),
                          child: Column(
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => AppColors
                                    .gradientPrimary
                                    .createShader(bounds),
                                child: Text(
                                  context.t('splashAppName'),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              AnimatedOpacity(
                                opacity: _stage >= 3 ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 500),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    context.t('splashSubtitle'),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  AnimatedOpacity(
                    opacity: _stage >= 3 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    child: AnimatedBuilder(
                      animation: _dotsController,
                      builder: (context, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (i) {
                            final wave = _dotsController.value * 4;
                            final distance = (wave - i).abs();
                            final active = distance < 1.0
                                ? (1.0 - distance).clamp(0.0, 1.0)
                                : 0.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Transform.scale(
                                scale: 0.6 + active * 0.4,
                                child: Opacity(
                                  opacity: 0.5 + active * 0.5,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.geniePurple,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
