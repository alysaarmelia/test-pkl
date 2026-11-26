import 'dart:ui';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../view_models/onboarding_view_model.dart';

class OnboardingView extends GetView<OnboardingViewModel> {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: HomeGlassTheme.background(
          child: Stack(
            children: [
              // Hero Image Section (Top 55%)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).size.height * 0.40,
                child: PageView.builder(
                  controller: controller.pageController,
                  onPageChanged: controller.onPageChanged,
                  itemCount: controller.contents.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    return Obx(() {
                      final isActive = index == controller.currentIndex.value;
                      return _AnimatedImageContent(
                        content: controller.contents[index],
                        isActive: isActive,
                      );
                    });
                  },
                ),
              ),

              // Skip Button
              Positioned(
                top: 60,
                right: 24,
                child: _buildSkipButton(),
              ),

              // Bottom Glass Panel (Bottom 45%)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.45,
                child: _buildBottomCard(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return TextButton(
      onPressed: controller.skip,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        backgroundColor: Colors.black.withOpacity(0.2),
      ),
      child: const Text(
        'Lewati',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildBottomCard(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(40),
        topRight: Radius.circular(40),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text Content mapped to current index
              Expanded(
                child: Obx(() {
                  final index = controller.currentIndex.value;
                  return _AnimatedTextContent(
                    content: controller.contents[index],
                    key: ValueKey(index),
                  );
                }),
              ),
              // Navigation Dots and Next Button
              _buildBottomNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Obx(
          () => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              controller.contents.length,
              (index) => _buildDot(index: index),
            ),
          ),
        ),
        Obx(
          () {
            final isLast = controller.currentIndex.value == controller.contents.length - 1;
            return GestureDetector(
              onTap: controller.next,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                height: 64,
                width: isLast ? 180 : 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF48D9F3), Color(0xFF28A8D8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF48D9F3).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child));
                  },
                  child: isLast
                      ? const Text(
                          "Mulai Sekarang",
                          key: ValueKey('text'),
                          style: TextStyle(
                            color: Color(0xFF0D1B2A),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_forward_rounded,
                          key: ValueKey('icon'),
                          color: Color(0xFF0D1B2A),
                          size: 28,
                        ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDot({required int index}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 8),
      height: 8,
      width: controller.currentIndex.value == index ? 32 : 8,
      decoration: BoxDecoration(
        color: controller.currentIndex.value == index
            ? const Color(0xFF48D9F3)
            : Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _AnimatedImageContent extends StatefulWidget {
  final OnboardingContent content;
  final bool isActive;

  const _AnimatedImageContent({
    required this.content,
    required this.isActive,
  });

  @override
  State<_AnimatedImageContent> createState() => _AnimatedImageContentState();
}

class _AnimatedImageContentState extends State<_AnimatedImageContent>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _entranceController;
  late Animation<double> _floatYAnimation;
  late Animation<double> _tiltXAnimation;
  late Animation<double> _tiltYAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    // Continuous complex floating animation
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _floatYAnimation = Tween<double>(begin: -15, end: 15).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );
    
    _tiltXAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutQuad),
    );
    
    _tiltYAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );
    
    _glowAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // Entrance animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.isActive) {
      _entranceController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedImageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _entranceController.forward(from: 0.0);
    } else if (!widget.isActive && oldWidget.isActive) {
      _entranceController.reverse();
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          final matrix = Matrix4.identity()
            ..setEntry(3, 2, 0.002) // perspective
            ..rotateX(_tiltXAnimation.value)
            ..rotateY(_tiltYAnimation.value)
            ..translate(0.0, _floatYAnimation.value, 0.0);
            
          return Transform(
            transform: matrix,
            alignment: FractionalOffset.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glowing Aura behind the image
                Container(
                  width: MediaQuery.of(context).size.width * 0.5,
                  height: MediaQuery.of(context).size.width * 0.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF48D9F3).withOpacity(_glowAnimation.value * 0.4),
                        blurRadius: 80,
                        spreadRadius: 20 * _glowAnimation.value,
                      ),
                      BoxShadow(
                        color: const Color(0xFF28A8D8).withOpacity(_glowAnimation.value * 0.2),
                        blurRadius: 120,
                        spreadRadius: 40 * _glowAnimation.value,
                      ),
                    ],
                  ),
                ),
                child!,
              ],
            ),
          );
        },
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(
            CurvedAnimation(
              parent: _entranceController,
              curve: Curves.elasticOut,
            ),
          ),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: _entranceController,
                curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
              ),
            ),
            child: widget.content.imageAsset != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      widget.content.imageAsset!,
                      width: MediaQuery.of(context).size.width * 0.85,
                      fit: BoxFit.contain,
                    ),
                  )
                : Icon(
                    widget.content.icon,
                    size: 150,
                    color: const Color(0xFF48D9F3),
                  ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedTextContent extends StatelessWidget {
  final OnboardingContent content;

  const _AnimatedTextContent({required this.content, super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 40 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content.title,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            content.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.75),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
