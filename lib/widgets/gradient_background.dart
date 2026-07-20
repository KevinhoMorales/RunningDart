import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../utils/constants.dart';

class GradientBackground extends StatelessWidget {
  const GradientBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.gradientStart,
                palette.gradientEnd,
              ],
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -60,
          child: _BlurCircle(
            size: 220,
            color: AppConstants.primaryColor.withValues(alpha: 0.15),
          ),
        ),
        Positioned(
          bottom: 120,
          left: -40,
          child: _BlurCircle(
            size: 160,
            color: AppConstants.secondaryColor.withValues(alpha: 0.12),
          ),
        ),
        Positioned(
          top: 200,
          left: 40,
          child: _BlurCircle(
            size: 80,
            color: AppConstants.accentColor.withValues(alpha: 0.1),
          ),
        ),
        child,
      ],
    );
  }
}

class _BlurCircle extends StatelessWidget {
  const _BlurCircle({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class AuthHero extends StatelessWidget {
  const AuthHero({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppConstants.brandGradientColors,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            boxShadow: [
              BoxShadow(
                color: AppConstants.primaryColor.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_run_rounded,
            size: 44,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          AppConstants.appName,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppConstants.appTagline,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: palette.textMuted,
              ),
        ),
      ],
    );
  }
}
