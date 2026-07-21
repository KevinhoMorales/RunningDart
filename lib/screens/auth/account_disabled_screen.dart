import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/modern_text_field.dart';

class AccountDisabledScreen extends StatelessWidget {
  const AccountDisabledScreen({super.key});

  Future<void> _handleRefresh(BuildContext context) async {
    await context.read<AuthProvider>().refreshAccountStatus();
    if (!context.mounted) {
      return;
    }

    final auth = context.read<AuthProvider>();
    if (auth.canAccessApp) {
      context.go('/home');
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (context.mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final palette = context.palette;
    final user = auth.user;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthHero(),
                  const SizedBox(height: AppSpacing.xl),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: palette.accentPrimary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.block_rounded,
                            size: 40,
                            color: palette.accentPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'cuenta desactivada',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: palette.textPrimary,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Tu cuenta fue desactivada y no puedes usar SAINTS en este momento. Si crees que es un error, contacta al administrador del club.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: palette.textMuted,
                                height: 1.5,
                              ),
                        ),
                        if (user != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: palette.infoBannerBackground,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
                              border: Border.all(color: palette.cardBorder),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  user.displayName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: palette.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  user.email,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: palette.textMuted,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        PrimaryButton(
                          label: 'Revisar estado',
                          isLoading: auth.isLoading,
                          onPressed: auth.isLoading
                              ? null
                              : AppHaptics.wrap(() => _handleRefresh(context)),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton(
                          onPressed: auth.isLoading
                              ? null
                              : AppHaptics.wrap(() => _handleLogout(context)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            side: BorderSide(color: palette.cardBorder),
                          ),
                          child: Text(
                            'Cerrar sesión',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
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
