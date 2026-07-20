import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/business_model.dart';
import '../providers/auth_provider.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/category_style.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class BusinessCard extends StatelessWidget {
  const BusinessCard({
    super.key,
    required this.business,
    required this.onTap,
  });

  final BusinessModel business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canUseMembership =
        context.watch<AuthProvider>().canUseMembershipFeatures;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          boxShadow: palette.elevatedCardShadow,
        ),
        child: Material(
          color: palette.cardBackground,
          elevation: 0,
          shadowColor: Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(
                  color: palette.isDark
                      ? palette.cardBorder
                      : palette.inputBorder.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Container(
                  height: 96,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppSpacing.radiusLg),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (business.imageUrl != null)
                        Image.network(
                          business.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _GradientHeader(business: business),
                        )
                      else
                        _GradientHeader(business: business),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.18),
                              Colors.black.withValues(alpha: 0.62),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: AppSpacing.md,
                        top: AppSpacing.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Text(
                            Helpers.categoryLabel(business.category),
                            style: AppTypography.micro(
                              context,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: AppSpacing.md,
                        right: AppSpacing.md,
                        bottom: AppSpacing.sm,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                business.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.sectionTitle(
                                  context,
                                  color: Colors.white,
                                ).copyWith(shadows: _overlayTextShadows),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white,
                              size: 14,
                              shadows: _overlayIconShadows,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        business.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.muted(context, weight: FontWeight.w400)
                            .copyWith(height: 1.4),
                      ),
                      if (business.discount.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _BusinessCardDiscount(
                          discount: business.discount,
                          canUseMembership: canUseMembership,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}

const _overlayTextShadows = [
  Shadow(
    color: Color(0x99000000),
    blurRadius: 8,
    offset: Offset(0, 1),
  ),
  Shadow(
    color: Color(0x66000000),
    blurRadius: 16,
    offset: Offset(0, 2),
  ),
];

const _overlayIconShadows = [
  Shadow(
    color: Color(0xCC000000),
    blurRadius: 6,
    offset: Offset(0, 1),
  ),
];

class _BusinessCardDiscount extends StatelessWidget {
  const _BusinessCardDiscount({
    required this.discount,
    required this.canUseMembership,
  });

  final String discount;
  final bool canUseMembership;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final formattedDiscount = Helpers.formatDiscountLabel(discount);
    final percentFigure = Helpers.discountPercentFigure(discount);
    final showLargePercent = canUseMembership &&
        percentFigure != null &&
        Helpers.discountLooksLikePercent(discount);

    if (!canUseMembership) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: palette.iconButtonBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_rounded, size: 16, color: palette.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Descuento exclusivo para miembros',
                style: AppTypography.caption(context),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppConstants.brandGradientAccentColors,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -6,
            top: -6,
            child: Icon(
              Icons.local_offer_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (showLargePercent) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        percentFigure,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          '%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Descuento miembro',
                        style: AppTypography.micro(
                          context,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        showLargePercent
                            ? 'Ahorra $formattedDiscount'
                            : formattedDiscount,
                        style: AppTypography.caption(
                          context,
                          color: Colors.white,
                        ).copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

class _GradientHeader extends StatelessWidget {
  const _GradientHeader({required this.business});

  final BusinessModel business;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: CategoryStyle.gradient(business.category),
      ),
    );
  }
}
