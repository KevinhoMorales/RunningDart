import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/business_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/category_style.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/business_location_section.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/membership_upsell_card.dart';
import '../../widgets/modern_text_field.dart';

class BusinessDetailScreen extends StatefulWidget {
  const BusinessDetailScreen({
    super.key,
    required this.businessId,
  });

  final String businessId;

  @override
  State<BusinessDetailScreen> createState() => _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends State<BusinessDetailScreen> {
  BusinessModel? _business;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    final business = await context
        .read<BusinessProvider>()
        .getBusinessById(widget.businessId);
    if (mounted) {
      setState(() {
        _business = business;
        _isLoading = false;
      });
    }
  }

  void _showMembershipInfo() {
    showModalBottomSheet<void>(
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Text(
                'Cómo usar tu membresía',
                style: AppTypography.sectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.md),
              _infoStep('1', 'Abre tu perfil en la app SAINTS.'),
              _infoStep('2', 'Muestra tu código QR al personal del negocio.'),
              _infoStep(
                '3',
                'El establecimiento verificará tu membresía y aplicará el beneficio.',
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Entendido',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppConstants.brandGradientAccentColors,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Text(
              number,
              style: AppTypography.micro(context, color: Colors.white),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text, style: AppTypography.body(context)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final auth = context.watch<AuthProvider>();
    final canUseMembership = auth.canUseMembershipFeatures;
    final isAdmin = auth.isAdmin;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: palette.scaffoldBackground,
        appBar: const CustomAppBar(title: 'Detalle'),
        body: const Center(
          child: CircularProgressIndicator(color: AppConstants.primaryColor),
        ),
      );
    }

    if (_business == null) {
      return Scaffold(
        backgroundColor: palette.scaffoldBackground,
        appBar: const CustomAppBar(title: 'Detalle'),
        body: const Center(child: Text('Negocio no encontrado')),
      );
    }

    final business = _business!;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: CustomAppBar(
        title: business.name,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: isAdmin
            ? [
                IconButton(
                  onPressed: () async {
                    await context.push('/admin/businesses/${business.id}/edit');
                    if (mounted) {
                      await _loadBusiness();
                    }
                  },
                  tooltip: 'Editar negocio',
                  icon: Icon(
                    Icons.edit_rounded,
                    color: palette.textPrimary,
                  ),
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                boxShadow: palette.softShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (business.imageUrl != null)
                    Image.network(
                      business.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: CategoryStyle.gradient(business.category),
                        ),
                      ),
                    )
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: CategoryStyle.gradient(business.category),
                      ),
                    ),
                  if (business.imageUrl != null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(
                      CategoryStyle.iconFor(business.category),
                      size: 120,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Text(
                            Helpers.categoryLabel(business.category),
                            style: AppTypography.caption(
                              context,
                              color: Colors.white,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          business.name,
                          style: AppTypography.sectionTitle(
                            context,
                            color: Colors.white,
                          ).copyWith(
                            shadows: const [
                              Shadow(
                                color: Color(0x99000000),
                                blurRadius: 8,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (business.discount.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _DiscountHighlightCard(
                discount: business.discount,
                canUseMembership: canUseMembership,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: palette.cardBackground,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                boxShadow: palette.softShadow,
              ),
              child: Text(
                business.description,
                style: AppTypography.muted(context).copyWith(height: 1.5),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _InfoSection(
              children: [
                _DetailRow(
                  icon: Icons.location_on_rounded,
                  text: business.address,
                ),
                _DetailRow(icon: Icons.phone_rounded, text: business.phone),
                _DetailRow(icon: Icons.schedule_rounded, text: business.hours),
              ],
            ),
            if (business.hasLocation) ...[
              const SizedBox(height: AppSpacing.md),
              BusinessLocationSection(business: business),
            ],
            const SizedBox(height: AppSpacing.md),
            if (canUseMembership) ...[
              _InfoSection(
                title: 'Beneficios para miembros',
                children: business.benefits
                    .map(
                      (benefit) => Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color:
                              AppConstants.accentColor.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusLg),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: AppConstants.accentColor,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                benefit,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Cómo usar tu membresía',
                onPressed: _showMembershipInfo,
              ),
            ] else ...[
              const MembershipUpsellCard(),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _DiscountHighlightCard extends StatelessWidget {
  const _DiscountHighlightCard({
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
    final showLargePercent =
        canUseMembership && percentFigure != null && Helpers.discountLooksLikePercent(discount);

    if (!canUseMembership) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: palette.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: palette.cardBorder),
          boxShadow: palette.softShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: palette.iconButtonBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_rounded,
                color: palette.textMuted,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Beneficio exclusivo para miembros',
                    style: AppTypography.title(context),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Activa tu membresía para ver el descuento de este negocio.',
                    style: AppTypography.muted(context).copyWith(height: 1.35),
                  ),
                ],
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
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -12,
            top: -12,
            child: Icon(
              Icons.local_offer_rounded,
              size: 96,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showLargePercent) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        percentFigure,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: -1,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          '%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.lg),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusLg),
                        ),
                        child: Text(
                          'Descuento miembro',
                          style: AppTypography.caption(
                            context,
                            color: Colors.white,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        showLargePercent
                            ? 'Ahorra $formattedDiscount en tu visita'
                            : formattedDiscount,
                        style: AppTypography.title(
                          context,
                          color: Colors.white,
                          weight: FontWeight.w800,
                        ).copyWith(height: 1.25),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Presenta tu QR de SAINTS al pagar.',
                        style: AppTypography.caption(
                          context,
                          color: Colors.white.withValues(alpha: 0.88),
                        ).copyWith(height: 1.35),
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

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.children,
    this.title,
  });

  final List<Widget> children;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: palette.isDark
            ? Border.all(color: palette.cardBorder)
            : null,
        boxShadow: palette.isDark
            ? palette.elevatedCardShadow
            : palette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: AppTypography.sectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppConstants.primaryColor.withValues(alpha: 0.14),
                  AppConstants.primaryColorLight.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, size: 18, color: AppConstants.primaryColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                text,
                style: AppTypography.body(context, weight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
