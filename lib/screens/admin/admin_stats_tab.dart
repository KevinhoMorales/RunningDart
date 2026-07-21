import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/membership_status.dart';
import '../../models/visit_model.dart';
import '../../providers/admin_provider.dart';
import '../../services/visit_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';

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
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadValidationStats();
  }

  Future<void> _loadValidationStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final visits = await VisitService().watchAllVisits().first;
      var approved = 0;
      for (final visit in visits) {
        if (visit.validationResult == ValidationResult.approved) {
          approved++;
        }
      }
      if (mounted) {
        setState(() {
          _totalValidations = visits.length;
          _approvedValidations = approved;
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
    final users = admin.users;

    final pending = users
        .where((u) => u.membershipStatus == MembershipStatus.pending)
        .length;
    final activeMembers = users
        .where(
          (u) =>
              u.isActive &&
              u.membershipStatus == MembershipStatus.active &&
              u.role.isMember,
        )
        .length;
    final operators = users.where((u) => u.isBusinessOperator).length;

    return RefreshIndicator(
      onRefresh: () async {
        await admin.refresh();
        await _loadValidationStats();
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
          _StatCard(
            icon: Icons.people_rounded,
            label: 'Usuarios registrados',
            value: '${users.length}',
            onTap: widget.onNavigateToUsers == null
                ? null
                : () => widget.onNavigateToUsers!(AdminUserFilter.all),
          ),
          _StatCard(
            icon: Icons.hourglass_top_rounded,
            label: 'Solicitudes pendientes',
            value: '$pending',
            onTap: widget.onNavigateToUsers == null
                ? null
                : () => widget.onNavigateToUsers!(AdminUserFilter.pending),
          ),
          _StatCard(
            icon: Icons.verified_rounded,
            label: 'Miembros activos',
            value: '$activeMembers',
            onTap: widget.onNavigateToUsers == null
                ? null
                : () => widget.onNavigateToUsers!(AdminUserFilter.activeMembers),
          ),
          _StatCard(
            icon: Icons.storefront_rounded,
            label: 'Operadores de marcas',
            value: '$operators',
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
          if (_isLoadingStats)
            const Center(child: CircularProgressIndicator())
          else ...[
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
