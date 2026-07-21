import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/visit_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/visit_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_app_bar.dart';

class VisitHistoryScreen extends StatefulWidget {
  const VisitHistoryScreen({super.key});

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListening();
    });
  }

  void _startListening() {
    final businessId = context.read<AuthProvider>().user?.businessId;
    if (businessId != null && businessId.isNotEmpty) {
      context.read<VisitProvider>().startListening(businessId);
    }
  }

  void _refreshVisits() {
    final businessId = context.read<AuthProvider>().user?.businessId;
    if (businessId != null && businessId.isNotEmpty) {
      context.read<VisitProvider>().refresh(businessId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final visitProvider = context.watch<VisitProvider>();

    if (!auth.canScanQr) {
      return Center(
        child: EmptyStateCard(
          icon: Icons.storefront_outlined,
          message: 'Sin marca aliada vinculada',
          subtitle:
              'Las validaciones aparecerán aquí cuando un administrador asigne tu cuenta a una marca aliada.',
        ),
      );
    }

    if (visitProvider.isLoading && visitProvider.visits.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (visitProvider.error != null && visitProvider.visits.isEmpty) {
      return Center(
        child: EmptyStateCard(
          icon: Icons.cloud_off_rounded,
          message: visitProvider.error!,
          subtitle:
              'Revisa tu conexión e intenta cargar el historial de escaneos otra vez.',
          actionLabel: 'Reintentar',
          onAction: _refreshVisits,
        ),
      );
    }

    if (visitProvider.visits.isEmpty) {
      return Center(
        child: EmptyStateCard(
          icon: Icons.history_rounded,
          message: 'Aún no hay validaciones',
          subtitle:
              'Cuando escanees el QR de un miembro, la validación quedará registrada aquí con fecha y hora.',
        ),
      );
    }

    return RefreshIndicator(
      color: AppConstants.primaryColor,
      onRefresh: () async => _refreshVisits(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.sm,
        ),
        itemCount: visitProvider.visits.length,
        itemBuilder: (context, index) {
          final visit = visitProvider.visits[index];
          return _VisitTile(visit: visit);
        },
      ),
    );
  }
}

class _VisitTile extends StatelessWidget {
  const _VisitTile({required this.visit});

  final VisitModel visit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: palette.cardBorder),
        boxShadow: palette.softShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        leading: CircleAvatar(
          backgroundColor: palette.accentPrimary.withValues(alpha: 0.12),
          child: Icon(
            Icons.person_rounded,
            color: palette.accentPrimary,
          ),
        ),
        title: Text(
          visit.memberDisplayName,
          style: AppTypography.title(context),
        ),
        subtitle: Text(
          '${Helpers.formatDate(visit.visitedAt)} · ${visit.validationResult.displayName}${visit.benefitUsed != null ? ' · ${visit.benefitUsed}' : ''}',
          style: AppTypography.caption(context),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: palette.iconButtonBackground,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Text(
            _formatTime(visit.visitedAt),
            style: AppTypography.caption(
              context,
              color: palette.textPrimary,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
