import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';
import 'profile_screen.dart';

/// Membresía del socio: credencial, horarios y datos de club. El perfil social
/// (foto, bio, publicaciones) vive en `/profile`.
class MembershipScreen extends StatelessWidget {
  const MembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: CustomAppBar(
        title: 'Membresía',
        leading: HapticIconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          HapticIconButton(
            onPressed: () => context.push('/settings'),
            tooltip: 'Ajustes',
            icon: Icon(Icons.settings_rounded, color: palette.textPrimary),
          ),
        ],
      ),
      body: user == null
          ? Center(
              child: Text(
                'No hay sesión activa',
                style: AppTypography.muted(context),
              ),
            )
          : HapticRefreshIndicator(
              onRefresh: () =>
                  context.read<AuthProvider>().refreshAccountStatus(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  AccountSections(user: user),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
