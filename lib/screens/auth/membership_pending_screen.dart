import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/modern_text_field.dart';

class MembershipPendingScreen extends StatefulWidget {
  const MembershipPendingScreen({super.key});

  @override
  State<MembershipPendingScreen> createState() =>
      _MembershipPendingScreenState();
}

class _MembershipPendingScreenState extends State<MembershipPendingScreen> {
  Future<void> _handleRefresh() async {
    await context.read<AuthProvider>().refreshAccountStatus();
    if (!mounted) {
      return;
    }

    final auth = context.read<AuthProvider>();
    if (!auth.isMembershipPending && auth.canAccessApp) {
      context.go('/home');
    }
  }

  Future<void> _handleLogout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: const CustomAppBar(title: 'Solicitud en revisión'),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: palette.cardBackground,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                boxShadow: palette.softShadow,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    size: 56,
                    color: palette.accentPrimary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Estamos esperando tu activación',
                    textAlign: TextAlign.center,
                    style: AppTypography.sectionTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    user?.membershipModality.displayName ?? 'Membresía SAINTS',
                    textAlign: TextAlign.center,
                    style: AppTypography.title(context),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'SAINTS revisará tu solicitud y activará tu membresía. '
                    'Te avisaremos cuando tu credencial digital con QR esté lista.',
                    textAlign: TextAlign.center,
                    style: AppTypography.muted(context).copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Revisar estado',
              isLoading: auth.isLoading,
              onPressed: auth.isLoading ? null : _handleRefresh,
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: auth.isLoading ? null : AppHaptics.wrap(_handleLogout),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
