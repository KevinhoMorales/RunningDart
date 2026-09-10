import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../utils/constants.dart';

class AppStartupLoading extends StatelessWidget {
  const AppStartupLoading({super.key});

  @override
  Widget build(BuildContext context) {
    // Match native splash: SAINTS surface + brand mark (not a generic run icon).
    const surface = AppConstants.surfaceColor;

    return const ColoredBox(
      color: surface,
      child: Center(
        child: _StartupBrand(),
      ),
    );
  }
}

class _StartupBrand extends StatelessWidget {
  const _StartupBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Image.asset(
            AppConstants.saintsMarkAsset,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) => Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppConstants.primaryColor,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              alignment: Alignment.center,
              child: const Text(
                'SAINTS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          AppConstants.appName,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppPalette.light.textPrimary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppConstants.primaryColor,
          ),
        ),
      ],
    );
  }
}
