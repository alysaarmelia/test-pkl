import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'bottom_nav_constants.dart';

/// Floating navbar khusus Android.
/// Glassmorphism custom dengan gesture long-press hover tooltip
/// dan efek chromatic aberration. Tidak ada CNTabBar.
class AndroidNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const AndroidNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<AndroidNavBar> createState() => _AndroidNavBarState();
}

class _AndroidNavBarState extends State<AndroidNavBar>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  int? _hoveredIndex;
  late Size _navBarSize;
  late Offset _navBarOffset;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _updateHoveredIndex(Offset localPosition) {
    if (_navBarSize.width == 0) return;
    final double itemWidth = _navBarSize.width / 5;
    final int index = (localPosition.dx / itemWidth).clamp(0, 4).floor();
    if (_hoveredIndex != index) {
      if (_hoveredIndex != null) HapticFeedback.selectionClick();
      setState(() => _hoveredIndex = index);
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _showOverlay(BuildContext context, Offset localPosition) {
    if (_overlayEntry != null) return;
    HapticFeedback.heavyImpact();

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    _navBarSize = renderBox.size;
    _navBarOffset = renderBox.localToGlobal(Offset.zero);

    _updateHoveredIndex(localPosition);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        if (_hoveredIndex == null) return const SizedBox.shrink();
        final itemWidth = _navBarSize.width / 5;
        final itemCenterX = (_hoveredIndex! * itemWidth) + (itemWidth / 2);

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          left: _navBarOffset.dx + itemCenterX - 70,
          top: _navBarOffset.dy - 120,
          child: Material(
            color: Colors.transparent,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildGlassTooltip(
                  BottomNav.iconFor(_hoveredIndex!),
                  BottomNav.labelFor(_hoveredIndex!),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward(from: 0.0);
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _animationController.reverse().then((_) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      });
      setState(() => _hoveredIndex = null);
    }
  }

  Widget _buildGlassTooltip(IconData icon, String label) {
    return Container(
      width: 140,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFFFF0000).withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(-4, -4),
          ),
          BoxShadow(
            color: const Color(0xFF00FF00).withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(4, -4),
          ),
          BoxShadow(
            color: const Color(0xFF0000FF).withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E).withOpacity(0.4),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.0),
                  Colors.white.withOpacity(0.1),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF0000).withOpacity(0.2),
                          blurStyle: BlurStyle.inner,
                          blurRadius: 12,
                          offset: const Offset(-3, 0),
                        ),
                        BoxShadow(
                          color: const Color(0xFF00FFFF).withOpacity(0.2),
                          blurStyle: BlurStyle.inner,
                          blurRadius: 12,
                          offset: const Offset(3, 0),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Column(
                    key: ValueKey<String>(label),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: -2,
                            child: Icon(icon, color: const Color(0xFFFF0000).withOpacity(0.8), size: 42),
                          ),
                          Positioned(
                            left: 2,
                            child: Icon(icon, color: const Color(0xFF00FFFF).withOpacity(0.8), size: 42),
                          ),
                          Icon(icon, color: Colors.white, size: 42),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: -1,
                            child: Text(
                              label,
                              style: TextStyle(
                                color: const Color(0xFFFF0000).withOpacity(0.8),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 1,
                            child: Text(
                              label,
                              style: TextStyle(
                                color: const Color(0xFF00FFFF).withOpacity(0.8),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
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
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    
    return SizedBox(
      height: 110 + bottomInset,
      child: Stack(
        children: [
          // ── Navbar Content ──
          Positioned(
            left: 20,
            right: 20,
            bottom: 16 + (bottomInset > 0 ? bottomInset / 2 : 0),
            child: GestureDetector(
              onLongPressStart: (details) =>
                  _showOverlay(context, details.localPosition),
              onLongPressMoveUpdate: (details) =>
                  _updateHoveredIndex(details.localPosition),
              onLongPressEnd: (details) {
                if (_hoveredIndex != null) widget.onTap?.call(_hoveredIndex!);
                _removeOverlay();
              },
              onLongPressCancel: _removeOverlay,
              child: _buildNav(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNav() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A).withOpacity(0.5),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.2),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                final icon = BottomNav.iconFor(index);
                final label = BottomNav.labelFor(index);
                final selected = index == widget.currentIndex;
                final isHovered = index == _hoveredIndex;
                final color = selected
                    ? const Color(0xFF48D9F3)
                    : const Color.fromARGB(255, 208, 208, 208);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onTap?.call(index),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      transform: Matrix4.identity()
                        ..scale(isHovered ? 0.7 : 1.0),
                      transformAlignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              color: color,
                              size: 26,
                              shadows: selected
                                  ? [
                                      Shadow(
                                        color: const Color(0xFF48D9F3).withOpacity(0.6),
                                        blurRadius: 12,
                                        offset: const Offset(0, 0),
                                      ),
                                    ]
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              label,
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
