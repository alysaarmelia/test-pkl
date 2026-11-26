import 'dart:ui';

import 'package:flutter/material.dart';

class OverviewCard extends StatelessWidget {
  const OverviewCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.delta,
    this.deltaIsPositive = true,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? delta;
  final bool deltaIsPositive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseText = colorScheme.brightness == Brightness.dark
        ? Colors.white
        : colorScheme.onSurface;
    final accentColor = deltaIsPositive
        ? colorScheme.primary
        : colorScheme.error;

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: const [
              BoxShadow(
                color: Color.fromARGB(32, 15, 23, 42),
                offset: Offset(0, 20),
                blurRadius: 42,
                spreadRadius: -14,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.35),
                          colorScheme.tertiary.withValues(alpha: 0.24),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white.withValues(alpha: 0.95),
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  if (delta != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            deltaIsPositive
                                ? Icons.north_east
                                : Icons.south_east,
                            size: 16,
                            color: accentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            delta!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: baseText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: baseText.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
