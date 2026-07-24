import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_model.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/membership_code.dart';
import '../utils/membership_helpers.dart';
import 'qr_generator.dart';

class MembershipCredentialCard extends StatelessWidget {
  const MembershipCredentialCard({
    super.key,
    required this.user,
    required this.qrPayload,
  });

  final UserModel user;
  final String qrPayload;

  @override
  Widget build(BuildContext context) {
    final isAdminCredential = user.isAdmin;
    final canShowQr = user.hasMembershipPrivileges;
    final brightness = Theme.of(context).brightness;
    final accent = AppConstants.credentialAccentColor(brightness);
    final statusLabel = isAdminCredential
        ? 'Activo'
        : MembershipHelpers.membershipStatusLabel(
            status: user.membershipStatus,
            isExpired: user.isMembershipExpired,
          );
    final vigenciaLabel = user.expiresAt != null
        ? Helpers.formatDate(user.expiresAt!)
        : '—';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppConstants.credentialCardGradientFor(brightness),
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: brightness == Brightness.dark ? 0.08 : 0.1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, AppConstants.primaryColorLight],
                ),
              ),
            ),
          ),
          Positioned(
            right: -24,
            top: 12,
            child: Icon(
              Icons.verified_rounded,
              size: 128,
              color: accent.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg + 4,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Icon(
                        Icons.badge_outlined,
                        size: 18,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SAINTS Wellness Club',
                            style: AppTypography.caption(
                              context,
                              color: Colors.white.withValues(alpha: 0.72),
                            ).copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          Text(
                            'Credencial digital',
                            style: AppTypography.micro(
                              context,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _MetadataGrid(
                  modality: user.membershipModality.displayName,
                  status: statusLabel,
                  vigencia: vigenciaLabel,
                  accent: accent,
                  showVigencia: !isAdminCredential,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (canShowQr) ...[
                  Center(
                    child: CustomPaint(
                      painter: _TicketBorderPainter(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: QRGenerator(data: qrPayload, size: 180),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _MembershipCodeBlock(code: user.qrCode),
                ] else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          user.isMembershipPending
                              ? Icons.hourglass_top_rounded
                              : Icons.lock_rounded,
                          color: Colors.white.withValues(alpha: 0.88),
                          size: 32,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          user.isMembershipPending
                              ? 'Tu credencial estará disponible cuando SAINTS apruebe tu membresía.'
                              : 'Activa tu membresía para ver tu credencial digital.',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption(
                            context,
                            color: Colors.white.withValues(alpha: 0.82),
                          ).copyWith(height: 1.4),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipCodeBlock extends StatelessWidget {
  const _MembershipCodeBlock({required this.code});

  final String code;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Código copiado'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CÓDIGO DE MIEMBRO',
            style: AppTypography.micro(
              context,
              color: Colors.white.withValues(alpha: 0.5),
            ).copyWith(letterSpacing: 0.6),
          ),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            MembershipCode.formatForDisplay(code),
            style: AppTypography.caption(
              context,
              color: Colors.white,
            ).copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _copy(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copiar código'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataGrid extends StatelessWidget {
  const _MetadataGrid({
    required this.modality,
    required this.status,
    required this.vigencia,
    required this.accent,
    this.showVigencia = true,
  });

  final String modality;
  final String status;
  final String vigencia;
  final Color accent;
  final bool showVigencia;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              flex: showVigencia ? 1 : 2,
              child: _MetadataCell(
                label: 'Modalidad',
                value: modality,
                accent: accent,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.12),
            ),
            Expanded(
              flex: showVigencia ? 1 : 2,
              child: _MetadataCell(
                label: 'Estado',
                value: status,
                accent: accent,
              ),
            ),
            if (showVigencia) ...[
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              Expanded(
                child: _MetadataCell(
                  label: 'Vigencia',
                  value: vigencia,
                  accent: accent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetadataCell extends StatelessWidget {
  const _MetadataCell({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.micro(
              context,
              color: Colors.white.withValues(alpha: 0.45),
            ).copyWith(letterSpacing: 0.6),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption(
              context,
              color: Colors.white,
            ).copyWith(fontWeight: FontWeight.w700, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _TicketBorderPainter extends CustomPainter {
  _TicketBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double startX = 0;
    final y = size.height - 1;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + dashWidth, y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
