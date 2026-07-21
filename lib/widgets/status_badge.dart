import 'package:flutter/material.dart';

import '../models/membership_status.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/constants.dart';
import '../utils/membership_helpers.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.isExpired = false,
    this.onDarkBackground = false,
  });

  final MembershipStatus status;
  final bool isExpired;
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    final label = MembershipHelpers.membershipStatusLabel(
      status: status,
      isExpired: isExpired,
    );
    final colors = _colorsFor(label, onDarkBackground: onDarkBackground);

    return Container(
      height: 28,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
        style: AppTypography.caption(
          context,
          color: colors.foreground,
        ).copyWith(fontWeight: FontWeight.w700, height: 1),
      ),
    );
  }

  ({Color background, Color border, Color foreground}) _colorsFor(
    String label, {
    bool onDarkBackground = false,
  }) {
    if (onDarkBackground) {
      return switch (label) {
        'Activo' => (
            background: AppConstants.primaryColorLight.withValues(alpha: 0.22),
            border: AppConstants.primaryColorLight.withValues(alpha: 0.4),
            foreground: const Color(0xFFB8E6C1),
          ),
        'Pendiente' => (
            background: const Color(0x33FAAD14),
            border: const Color(0x66FAAD14),
            foreground: const Color(0xFFFFE7BA),
          ),
        'Vencido' => (
            background: const Color(0x33FF4D4F),
            border: const Color(0x66FF4D4F),
            foreground: const Color(0xFFFFCCC7),
          ),
        _ => (
            background: Colors.white.withValues(alpha: 0.12),
            border: Colors.white.withValues(alpha: 0.22),
            foreground: Colors.white.withValues(alpha: 0.88),
          ),
      };
    }

    return switch (label) {
      'Activo' => (
          background: AppConstants.accentColor.withValues(alpha: 0.14),
          border: AppConstants.accentColor.withValues(alpha: 0.28),
          foreground: AppConstants.primaryColor,
        ),
      'Pendiente' => (
          background: const Color(0xFFFFF7E6),
          border: const Color(0xFFFFD591),
          foreground: const Color(0xFFAD6800),
        ),
      'Vencido' => (
          background: const Color(0xFFFFF1F0),
          border: const Color(0xFFFFCCC7),
          foreground: const Color(0xFFA8071A),
        ),
      _ => (
          background: const Color(0xFFF3F4F6),
          border: const Color(0xFFE5E7EB),
          foreground: const Color(0xFF6B7280),
        ),
    };
  }
}
