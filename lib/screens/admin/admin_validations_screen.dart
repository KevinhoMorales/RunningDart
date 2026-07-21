import 'package:flutter/material.dart';

import '../../models/visit_model.dart';
import '../../services/visit_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_app_bar.dart';

class AdminValidationsScreen extends StatelessWidget {
  const AdminValidationsScreen({
    super.key,
    this.approvedOnly = false,
  });

  final bool approvedOnly;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final service = VisitService();

    return Scaffold(
      appBar: CustomAppBar(
        title: approvedOnly ? 'Validaciones aprobadas' : 'Validaciones QR',
      ),
      body: StreamBuilder<List<VisitModel>>(
        stream: service.watchAllVisits(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'No se pudieron cargar las validaciones.',
                  textAlign: TextAlign.center,
                  style: AppTypography.muted(context),
                ),
              ),
            );
          }

          final visits = (snapshot.data ?? const <VisitModel>[])
              .where(
                (visit) =>
                    !approvedOnly ||
                    visit.validationResult == ValidationResult.approved,
              )
              .toList(growable: false);

          if (visits.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  approvedOnly
                      ? 'Aún no hay validaciones aprobadas.'
                      : 'Aún no hay validaciones registradas.',
                  textAlign: TextAlign.center,
                  style: AppTypography.muted(context),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: visits.length,
            itemBuilder: (context, index) {
              final visit = visits[index];
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
                    backgroundColor:
                        palette.accentPrimary.withValues(alpha: 0.12),
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
                    '${Helpers.formatDate(visit.visitedAt)} · '
                    '${visit.validationResult.displayName}'
                    '${visit.benefitUsed != null ? ' · ${visit.benefitUsed}' : ''}',
                    style: AppTypography.caption(context),
                  ),
                  trailing: Text(
                    _formatTime(visit.visitedAt),
                    style: AppTypography.caption(
                      context,
                      color: palette.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
