import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'haptic_controls.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.actions,
    this.leading,
  });

  final String title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final titleStyle = AppTypography.appBarTitle(context);

    return AppBar(
      leading: leading,
      title: titleWidget ??
          Text(
            title,
            style: titleStyle,
          ),
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: palette.textPrimary,
      actions: actions,
      actionsPadding: const EdgeInsets.only(right: AppSpacing.sm),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.sectionTitle(context),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: AppTypography.muted(context),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: palette.cardBorder),
        boxShadow: palette.elevatedCardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: palette.accentPrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: palette.accentPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.title(context, weight: FontWeight.w600),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: AppTypography.muted(context),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            HapticFilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({super.key});

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.4 + (_controller.value * 0.4),
          child: child,
        );
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            height: 140,
            decoration: BoxDecoration(
              color: palette.skeletonColor,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          );
        },
      ),
    );
  }
}
