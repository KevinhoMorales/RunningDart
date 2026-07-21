import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';
import 'haptic_controls.dart';

class RouterErrorScreen extends StatelessWidget {
  const RouterErrorScreen({
    super.key,
    this.error,
  });

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: palette.accentPrimary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No se pudo abrir esta pantalla',
                textAlign: TextAlign.center,
                style: AppTypography.title(context, weight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Ocurrió un problema al cargar la app. Puedes volver al inicio '
                'de sesión e intentar de nuevo.',
                textAlign: TextAlign.center,
                style: AppTypography.body(context, color: palette.textMuted),
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(context),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              HapticFilledButton(
                onPressed: AppHaptics.wrap(() => context.go('/login')),
                child: const Text('Ir al inicio de sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
