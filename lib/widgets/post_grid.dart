import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';
import 'custom_app_bar.dart';
import 'delete_post_dialog.dart';

/// Cuadrícula de publicaciones a tres por fila. Es un sliver: va dentro de un
/// [CustomScrollView].
class PostGrid extends StatelessWidget {
  const PostGrid({
    super.key,
    required this.posts,
    required this.isLoading,
    required this.onOpenPost,
    required this.emptyMessage,
    this.emptySubtitle,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.onDeletePost,
    this.errorMessage,
    this.onRetry,
  });

  final List<PostModel> posts;
  final bool isLoading;
  final void Function(PostModel post) onOpenPost;
  final String emptyMessage;
  final String? emptySubtitle;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  /// Cuando la carga falló. Se distingue del estado vacío para no decirle a
  /// alguien que no ha publicado nada cuando en realidad no pudimos leerlo.
  final String? errorMessage;
  final VoidCallback? onRetry;

  /// Cuando llega, mantener pulsada una foto ofrece eliminarla. Va nulo en los
  /// perfiles ajenos, donde no hay nada que borrar.
  final Future<void> Function(PostModel post)? onDeletePost;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final withImage = posts
        .where((p) => p.imageUrl != null && p.imageUrl!.isNotEmpty)
        .toList(growable: false);

    if (withImage.isEmpty && errorMessage != null) {
      return SliverToBoxAdapter(
        child: EmptyStateCard(
          icon: Icons.cloud_off_rounded,
          message: errorMessage!,
          subtitle: 'Revisa tu conexión e inténtalo de nuevo.',
          actionLabel: onRetry == null ? null : 'Reintentar',
          onAction: onRetry,
        ),
      );
    }

    if (withImage.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyStateCard(
          icon: Icons.grid_on_outlined,
          message: emptyMessage,
          subtitle: emptySubtitle,
          actionLabel: emptyActionLabel,
          onAction: onEmptyAction,
        ),
      );
    }

    final palette = context.palette;

    return SliverPadding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final post = withImage[index];
            return GestureDetector(
              onTap: AppHaptics.wrap(() => onOpenPost(post)),
              onLongPress: onDeletePost == null
                  ? null
                  : () {
                      AppHaptics.lightTap();
                      _showPostActions(context, post);
                    },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    post.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: palette.skeletonColor,
                    ),
                  ),
                  // Las ocultas por moderación se atenúan para distinguirlas de
                  // un vistazo entre las demás.
                  if (post.isHidden)
                    Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.visibility_off_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                ],
              ),
            );
          },
          childCount: withImage.length,
        ),
      ),
    );
  }

  Future<void> _showPostActions(BuildContext context, PostModel post) async {
    final action = await showModalBottomSheet<_GridAction>(
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
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.inputBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ActionTile(
                icon: Icons.open_in_full_rounded,
                label: 'Ver publicación',
                onTap: () =>
                    Navigator.of(sheetContext).pop(_GridAction.open),
              ),
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Eliminar publicación',
                color: const Color(0xFFDC2626),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_GridAction.delete),
              ),
            ],
          ),
        );
      },
    );

    if (action == _GridAction.open) {
      onOpenPost(post);
      return;
    }
    if (action != _GridAction.delete || !context.mounted) {
      return;
    }
    if (await confirmDeletePost(context)) {
      await onDeletePost?.call(post);
    }
  }
}

enum _GridAction { open, delete }

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = color ?? palette.textPrimary;

    return ListTile(
      leading: Icon(icon, color: tint),
      title: Text(label, style: AppTypography.body(context, color: tint)),
      onTap: AppHaptics.wrap(onTap),
      enableFeedback: false,
    );
  }
}
