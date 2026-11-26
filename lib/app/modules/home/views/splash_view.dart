import 'dart:async';

import 'package:cipta_vera_mandiri_digital/app/constants/assets.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/bindings/shared_preferences.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/app/routes/app_routes.dart';
import 'package:cipta_vera_mandiri_digital/repositories/auth_flow_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/auth_flow_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key, this.repository, this.viewModel});

  final AuthFlowRepository? repository;
  final AuthFlowViewModel? viewModel;

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AuthFlowViewModel _viewModel;
  late final String _viewModelTag;
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _glowAnimation;
  late final ImageProvider _logoProvider;
  bool _navigated = false;
  late final Future<bool> _goHomeFuture;

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'splash-auth-${identityHashCode(this)}';
    _viewModel = Get.put(
        widget.viewModel ??
            AuthFlowViewModel(
              repository: widget.repository ?? AuthFlowRepositoryImpl(),
            ),
        tag: _viewModelTag,
    );
    _logoProvider = const AssetImage(AppAssets.cvmLogo);
    _goHomeFuture = _resolveNextRoute();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
    );
    _glowAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuad,
    );
    _playSplashSequence();
  }

  @override
  void dispose() {
    if (Get.isRegistered<AuthFlowViewModel>(tag: _viewModelTag)) {
      Get.delete<AuthFlowViewModel>(tag: _viewModelTag, force: true);
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _precacheLogo() async {
    try {
      await precacheImage(_logoProvider, context);
    } catch (_) {
      // Ignore caching failures; splash will still show the asset.
    }
  }

  Future<void> _playSplashSequence() async {
    final minDisplay = Future.delayed(const Duration(milliseconds: 400));
    await _precacheLogo();
    await _controller.forward();

    bool goHome;
    try {
      goHome = await _goHomeFuture.timeout(
        const Duration(milliseconds: 1600),
        onTimeout: () => false,
      );
    } catch (_) {
      goHome = false;
    }

    await minDisplay;
    if (_navigated || !mounted) return;
    _navigated = true;
    
    if (AppPreferences.isFirstTimeRun()) {
      Get.offAllNamed(Routes.ONBOARDING);
    } else {
      Get.offAllNamed(goHome ? Routes.HOME : Routes.LOGIN);
    }
  }

  Future<bool> _resolveNextRoute() async {
    if (_navigated) return false;
    return _viewModel.shouldAutoLogin();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: HomeGlassTheme.background(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (context, child) {
                        final glow = _glowAnimation.value;
                        final basePadding = 28.0;
                        return Container(
                          padding: EdgeInsets.all(basePadding - glow * 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(
                                0.08 + glow * 0.1,
                              ),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF48D9F3,
                                ).withOpacity(0.35 * glow),
                                blurRadius: 60 * glow + 12,
                                spreadRadius: 6 * glow,
                              ),
                            ],
                          ),
                          child: child,
                        );
                      },
                      child: RepaintBoundary(
                        child: Image(
                          image: _logoProvider,
                          height: 140,
                          width: 140,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Cipta Vera Mandiri Digital',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Empowering modern workforce',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 4,
                      width: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Color(0xFF48D9F3)),
                          backgroundColor: Color(0x22FFFFFF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
