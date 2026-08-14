import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_provider.dart';
import '../../services/user_service.dart';
import '../../services/visit_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/haptic_controls.dart';

class AdminStatsTab extends StatefulWidget {
  const AdminStatsTab({
    super.key,
    this.onNavigateToUsers,
  });

  final void Function(AdminUserFilter filter)? onNavigateToUsers;

  @override
  State<AdminStatsTab> createState() => _AdminStatsTabState();
}

class _AdminStatsTabState extends State<AdminStatsTab> {
  int _totalValidations = 0;
  int _approvedValidations = 0;
  int _totalUsers = 0;
  int _pendingUsers = 0;
  int _activeMembers = 0;
  int _operators = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final visitStats = await VisitService().countValidationStats();
      final userStats = await UserService().countAdminUserStats();
      if (mounted) {
        setState(() {
          _totalValidations = visitStats.total;
          _approvedValidations = visitStats.approved;
          _totalUsers = userStats.total;
          _pendingUsers = userStats.pending;
          _activeMembers = userStats.activeMembers;
          _operators = userStats.operators;
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  void _openValidations({required bool approvedOnly}) {
    context.push(
      '/admin/validations${approvedOnly ? '?approved=true' : ''}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final admin = context.watch<AdminProvider>();

    return HapticRefreshIndicator(
      onRefresh: () async {
        await admin.refresh();
        await _loadStats();
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(
            'Resumen del club',
            style: AppTypography.sectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_isLoadingStats)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _StatCard(
              icon: Icons.people_rounded,
              label: 'Usuarios registrados',
              value: '$_totalUsers',
              onTap: widget.onNavigateToUsers == null
                  ? null
                  : () => widget.onNavigateToUsers!(AdminUserFilter.all),
            ),
            _StatCard(
              icon: Icons.hourglass_top_rounded,
              label: 'Solicitudes pendientes',
              value: '$_pendingUsers',
              onTap: widget.onNavigateToUsers == null
                  ? null
                  : () => widget.onNavigateToUsers!(AdminUserFilter.pending),
            ),
            _StatCard(
              icon: Icons.verified_rounded,
              label: 'Miembros activos',
              value: '$_activeMembers',
              onTap: widget.onNavigateToUsers == null
                  ? null
                  : () =>
                      widget.onNavigateToUsers!(AdminUserFilter.activeMembers),
            ),
            _StatCard(
              icon: Icons.storefront_rounded,
              label: 'Operadores de marcas',
              value: '$_operators',
              onTap: widget.onNavigateToUsers == null
                  ? null
                  : () => widget.onNavigateToUsers!(AdminUserFilter.operators),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Validaciones QR',
              style: AppTypography.title(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            _StatCard(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Total validaciones',
              value: '$_totalValidations',
              onTap: () => _openValidations(approvedOnly: false),
            ),
            _StatCard(
              icon: Icons.check_circle_outline_rounded,
              label: 'Validaciones aprobadas',
              value: '$_approvedValidations',
              onTap: () => _openValidations(approvedOnly: true),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'Toca una tarjeta para ver el detalle. Actualiza deslizando hacia abajo.',
            style: AppTypography.caption(context, color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: AppHaptics.wrap(onTap),
          enableFeedback: false,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: palette.cardBorder),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: palette.accentPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(icon, color: palette.accentPrimary, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(label, style: AppTypography.body(context)),
                ),
                Text(
                  value,
                  style: AppTypography.sectionTitle(context).copyWith(
                    color: palette.accentPrimary,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: palette.textMuted,
                    size: 22,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
