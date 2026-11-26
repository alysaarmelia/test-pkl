import 'dart:async';

import 'dart:math' as math;

import 'package:cipta_vera_mandiri_digital/app/constants/assets.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/app/routes/app_routes.dart';
import 'package:cipta_vera_mandiri_digital/repositories/auth_flow_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/auth_flow_view_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key, this.repository, this.viewModel});

  final AuthFlowRepository? repository;
  final AuthFlowViewModel? viewModel;

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView>
    with TickerProviderStateMixin {
  late final AuthFlowViewModel _viewModel;
  late final String _viewModelTag;
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideAnimation;
  late final AnimationController _portalController;
  late final Animation<double> _rotationAnimation;
  Timer? _timer;
  String _friendlyName = 'Pengguna';

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'welcome-auth-${identityHashCode(this)}';
    _viewModel = Get.put(
        widget.viewModel ??
            AuthFlowViewModel(
              repository: widget.repository ?? AuthFlowRepositoryImpl(),
            ),
        tag: _viewModelTag,
    );
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
    _portalController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _rotationAnimation = CurvedAnimation(
      parent: _portalController,
      curve: Curves.linear,
    );
    _loadFriendlyName();
    _timer = Timer(const Duration(milliseconds: 2200), () async {
      if (!mounted) return;
      Get.offAllNamed(Routes.HOME);
    });
  }

  Future<void> _loadFriendlyName() async {
    final resolved = await _viewModel.resolveFriendlyName();

    if (!mounted) return;
    setState(() {
      _friendlyName = resolved;
    });
  }

  @override
  void dispose() {
    if (Get.isRegistered<AuthFlowViewModel>(tag: _viewModelTag)) {
      Get.delete<AuthFlowViewModel>(tag: _viewModelTag, force: true);
    }
    _timer?.cancel();
    _controller.dispose();
    _portalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: HomeGlassTheme.background(
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _slideAnimation,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _rotationAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotationAnimation.value * 2 * math.pi,
                              child: Container(
                                width: 190,
                                height: 190,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: SweepGradient(
                                    colors: const [
                                      Color(0xFF48D9F3),
                                      Color(0xFF7C5CFF),
                                      Color(0xFF48D9F3),
                                    ],
                                    stops: const [0.0, 0.6, 1.0],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF48D9F3,
                                      ).withOpacity(0.35),
                                      blurRadius: 42,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        AnimatedBuilder(
                          animation: _rotationAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: -_rotationAnimation.value * 2 * math.pi,
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1.6,
                                  ),
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.16),
                                      Colors.white.withOpacity(0.02),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        RepaintBoundary(
                          child: Image.asset(
                            AppAssets.cvmLogo,
                            height: 120,
                            width: 120,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(_slideAnimation),
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFF7DD3FC),
                              Color(0xFF38BDF8),
                              Color(0xFF2563EB),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            'Selamat Datang',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.3,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  offset: Offset(0, 2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFFFDE68A),
                              Color(0xFFFCA5A5),
                              Color(0xFFFFF7AE),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ).createShader(bounds),
                          child: Text(
                            _friendlyName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
