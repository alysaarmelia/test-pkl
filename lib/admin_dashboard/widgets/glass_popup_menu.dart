import 'package:flutter/material.dart';

import 'glass.dart';

class GlassPopupMenuEntry<T> extends PopupMenuEntry<T> {
  const GlassPopupMenuEntry({
    super.key,
    required this.child,
    this.height = 48,
    this.gradientColors,
    this.borderColor,
    this.textColor,
    this.iconColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  final Widget child;
  @override
  final double height;
  final List<Color>? gradientColors;
  final Color? borderColor;
  final Color? textColor;
  final Color? iconColor;
  final EdgeInsetsGeometry padding;

  @override
  bool represents(T? value) => true;

  @override
  State<GlassPopupMenuEntry<T>> createState() => _GlassPopupMenuEntryState<T>();
}

class _GlassPopupMenuEntryState<T> extends State<GlassPopupMenuEntry<T>> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultTextColor = theme.colorScheme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.9);
    final resolvedTextColor = widget.textColor ?? defaultTextColor;
    final resolvedIconColor =
        widget.iconColor ?? resolvedTextColor.withValues(alpha: 0.9);

    return GlassContainer(
      borderRadius: 18,
      blur: 18,
      gradientColors:
          widget.gradientColors ??
          [Color.fromARGB(170, 18, 20, 36), Color.fromARGB(110, 11, 13, 28)],
      borderColor: widget.borderColor ?? Colors.white.withValues(alpha: 0.32),
      boxShadow: const [
        BoxShadow(
          color: Color.fromARGB(55, 6, 10, 30),
          offset: Offset(0, 18),
          blurRadius: 40,
          spreadRadius: -18,
        ),
      ],
      padding: widget.padding,
      child: DefaultTextStyle(
        style:
            theme.textTheme.bodyMedium?.copyWith(
              color: resolvedTextColor,
              fontWeight: FontWeight.w600,
            ) ??
            TextStyle(color: resolvedTextColor),
        child: IconTheme(
          data: IconThemeData(color: resolvedIconColor, size: 20),
          child: widget.child,
        ),
      ),
    );
  }
}
