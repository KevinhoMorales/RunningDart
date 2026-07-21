import 'package:flutter/material.dart';

import '../models/visit_model.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/helpers.dart';
import 'modality_chip.dart';
import 'status_badge.dart';

Future<void> showValidationResultSheet(
  BuildContext context,
  ScanValidationResult result,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final palette = sheetContext.palette;

      return Container(
        decoration: BoxDecoration(
          color: palette.bottomSheetBackground,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.inputBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: result.isApproved
                        ? palette.accentPrimary.withValues(alpha: 0.14)
                        : const Color(0xFFFFF1F0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    result.isApproved
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: result.isApproved
                        ? palette.accentPrimary
                        : const Color(0xFFA8071A),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.isApproved
                            ? 'Validación aprobada'
                            : 'Validación rechazada',
                        style: AppTypography.sectionTitle(sheetContext),
                      ),
                      Text(
                        result.message,
                        style: AppTypography.muted(sheetContext),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (result.memberDisplayName != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _ValidationRow(
                label: 'Miembro',
                value: result.memberDisplayName!,
              ),
            ],
            if (result.memberModality != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(
                    'Modalidad',
                    style: AppTypography.caption(sheetContext),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ModalityChip(
                    modality: result.memberModality!,
                    compact: true,
                  ),
                ],
              ),
            ],
            if (result.memberStatus != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(
                    'Estado',
                    style: AppTypography.caption(sheetContext),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusBadge(status: result.memberStatus!),
                ],
              ),
            ],
            if (result.expiresAt != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _ValidationRow(
                label: 'Vigencia',
                value: Helpers.formatDate(result.expiresAt!),
              ),
            ],
            if (result.benefitUsed != null &&
                result.benefitUsed!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _ValidationRow(
                label: 'Beneficio',
                value: result.benefitUsed!,
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _ValidationRow extends StatelessWidget {
  const _ValidationRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(label, style: AppTypography.caption(context)),
        ),
        Expanded(
          child: Text(value, style: AppTypography.body(context)),
        ),
      ],
    );
  }
}
