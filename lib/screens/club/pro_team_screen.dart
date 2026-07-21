import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/profile_action_tile.dart';

class ProTeamScreen extends StatelessWidget {
  const ProTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: const CustomAppBar(title: 'SAINTS Pro Team'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Tu espacio Pro Team',
            style: AppTypography.sectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Consulta horarios, sesiones e indicaciones del coach. '
            'El seguimiento de progreso estará disponible próximamente.',
            style: AppTypography.muted(context).copyWith(height: 1.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          ProfileActionTile(
            icon: Icons.schedule_rounded,
            title: 'Horarios Pro Team',
            subtitle: 'Lunes, miércoles y viernes · 7:00 p.m.',
            onTap: () => context.push('/training-schedule'),
          ),
          const SizedBox(height: AppSpacing.sm),
          ProfileActionTile(
            icon: Icons.fitness_center_rounded,
            title: 'Sesiones programadas',
            subtitle: 'Próximamente: calendario de entrenamientos',
            trailing: const SizedBox.shrink(),
            onTap: null,
          ),
          const SizedBox(height: AppSpacing.sm),
          ProfileActionTile(
            icon: Icons.menu_book_rounded,
            title: 'Indicaciones del coach',
            subtitle: 'Próximamente: instrucciones y tablas de trabajo',
            trailing: const SizedBox.shrink(),
            onTap: null,
          ),
          const SizedBox(height: AppSpacing.sm),
          ProfileActionTile(
            icon: Icons.trending_up_rounded,
            title: 'Progreso',
            subtitle: 'Próximamente: cumplimiento y métricas personales',
            trailing: const SizedBox.shrink(),
            onTap: null,
          ),
          if (auth.canManageSchedules) ...[
            const SizedBox(height: AppSpacing.lg),
            ProfileActionTile(
              icon: Icons.edit_calendar_rounded,
              title: 'Editar horarios',
              subtitle: 'Panel coach / administrador',
              onTap: () => context.push('/admin/training-schedule'),
            ),
          ],
        ],
      ),
    );
  }
}
