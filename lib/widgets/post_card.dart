import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';
import 'user_avatar.dart';

enum PostCardAction { report, block, delete }

const _likeColor = Color(0xFFDC2626);

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.isAdmin,
    required this.onOpenAuthor,
    required this.onAction,
    required this.isLiked,
    required this.likesCount,
    required this.onToggleLike,
    required this.onOpenLikes,
    required this.onOpenPost,
  });

  final PostModel post;
  final String currentUserId;
  final bool isAdmin;
  final VoidCallback onOpenAuthor;
  final void Function(PostCardAction action) onAction;
  final bool isLiked;
  final int likesCount;
  final VoidCallback onToggleLike;
  final VoidCallback onOpenLikes;
  final VoidCallback onOpenPost;

  bool get _isAuthor => post.authorId == currentUserId;
  bool get _canDelete => _isAuthor || isAdmin;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: palette.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: palette.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              post: post,
              palette: palette,
              onOpenAuthor: onOpenAuthor,
              trailing: _buildMenu(context, palette),
            ),
            if (hasImage)
              LikeableImage(
                imageUrl: post.imageUrl!,
                palette: palette,
                isLiked: isLiked,
                onLike: onToggleLike,
                onOpen: onOpenPost,
              ),
            _LikeBar(isLiked: isLiked, onToggleLike: onToggleLike),
            if (likesCount > 0)
              LikesSummary(
                likesCount: likesCount,
                recentLikes: post.recentLikes,
                onTap: onOpenLikes,
              ),
            if (post.caption != null && post.caption!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Text(
                  post.caption!.trim(),
                  style: AppTypography.body(context).copyWith(height: 1.4),
                ),
              )
            else
              const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context, AppPalette palette) {
    return PopupMenuButton<PostCardAction>(
      icon: Icon(Icons.more_horiz_rounded, color: palette.textMuted),
      onSelected: (action) {
        AppHaptics.lightTap();
        onAction(action);
      },
      itemBuilder: (context) => [
        if (!_isAuthor)
          const PopupMenuItem(
            value: PostCardAction.report,
            child: _MenuRow(
              icon: Icons.flag_outlined,
              label: 'Reportar',
            ),
          ),
        if (!_isAuthor)
          PopupMenuItem(
            value: PostCardAction.block,
            child: _MenuRow(
              icon: Icons.block_rounded,
              label: 'Bloquear a ${post.authorName}',
            ),
          ),
        if (_canDelete)
          const PopupMenuItem(
            value: PostCardAction.delete,
            child: _MenuRow(
              icon: Icons.delete_outline_rounded,
              label: 'Eliminar',
              isDestructive: true,
            ),
          ),
      ],
    );
  }
}

/// Imagen de la publicación: un toque la abre en grande y el doble tap da
/// "me gusta".
///
/// El doble tap solo agrega el like, nunca lo quita, para que no se pierda por
/// accidente al mirar una foto dos veces seguidas.
class LikeableImage extends StatefulWidget {
  const LikeableImage({
    super.key,
    required this.imageUrl,
    required this.palette,
    required this.isLiked,
    required this.onLike,
    required this.onOpen,
  });

  final String imageUrl;
  final AppPalette palette;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onOpen;

  @override
  State<LikeableImage> createState() => _LikeableImageState();
}

class _LikeableImageState extends State<LikeableImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    AppHaptics.lightTap();
    _controller.forward(from: 0);
    if (!widget.isLiked) {
      widget.onLike();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: AppHaptics.wrap(widget.onOpen),
      onDoubleTap: _handleDoubleTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: widget.palette.skeletonColor,
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: widget.palette.textMuted,
                  size: 40,
                ),
              ),
            ),
            Center(
              child: _HeartBurst(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeartBurst extends StatelessWidget {
  const _HeartBurst({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final value = controller.value;
          if (value == 0) {
            return const SizedBox.shrink();
          }
          // Aparece con un rebote y se desvanece en el último tramo.
          final scale = value < 0.3
              ? Curves.easeOutBack.transform(value / 0.3)
              : 1.0;
          final opacity = value < 0.7 ? 1.0 : (1 - value) / 0.3;
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: const Icon(
          Icons.favorite_rounded,
          color: Colors.white,
          size: 96,
          shadows: [
            Shadow(color: Colors.black38, blurRadius: 16),
          ],
        ),
      ),
    );
  }
}

class _LikeBar extends StatelessWidget {
  const _LikeBar({required this.isLiked, required this.onToggleLike});

  final bool isLiked;
  final VoidCallback onToggleLike;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, 0, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: AppHaptics.wrap(onToggleLike),
            enableFeedback: false,
            visualDensity: VisualDensity.compact,
            tooltip: isLiked ? 'Quitar me gusta' : 'Me gusta',
            icon: Icon(
              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isLiked ? _likeColor : palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Resumen de likes al estilo Instagram: con pocos se nombran las personas y
/// con muchos solo queda el número. Tocarlo abre la lista completa.
class LikesSummary extends StatelessWidget {
  const LikesSummary({
    super.key,
    required this.likesCount,
    required this.recentLikes,
    required this.onTap,
  });

  final int likesCount;
  final List<PostLikePreview> recentLikes;
  final VoidCallback onTap;

  static const _maxNames = 3;

  String _label() {
    final names = recentLikes
        .map((like) => like.displayName.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);

    if (likesCount > _maxNames || names.length < likesCount) {
      return '$likesCount Me gusta';
    }

    switch (likesCount) {
      case 1:
        return 'Le gusta a ${names[0]}';
      case 2:
        return 'Les gusta a ${names[0]} y ${names[1]}';
      default:
        return 'Les gusta a ${names[0]}, ${names[1]} y ${names[2]}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final showAvatars = likesCount <= _maxNames && recentLikes.isNotEmpty;

    return InkWell(
      onTap: AppHaptics.wrap(onTap),
      enableFeedback: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            if (showAvatars) ...[
              _StackedAvatars(profiles: recentLikes.take(_maxNames).toList()),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                _label(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(context, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StackedAvatars extends StatelessWidget {
  const _StackedAvatars({required this.profiles});

  final List<PostLikePreview> profiles;

  static const _radius = 11.0;
  static const _step = 15.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      height: _radius * 2,
      width: _radius * 2 + _step * (profiles.length - 1),
      child: Stack(
        children: [
          for (var i = 0; i < profiles.length; i++)
            Positioned(
              left: i * _step,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.cardBackground, width: 1.5),
                ),
                child: UserAvatar(
                  displayName: profiles[i].displayName,
                  photoUrl: profiles[i].photoUrl,
                  radius: _radius,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.post,
    required this.palette,
    required this.onOpenAuthor,
    required this.trailing,
  });

  final PostModel post;
  final AppPalette palette;
  final VoidCallback onOpenAuthor;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: AppHaptics.wrap(onOpenAuthor),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Row(
                children: [
                  UserAvatar(
                    displayName: post.authorName,
                    photoUrl: post.authorPhotoUrl,
                    radius: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.title(
                            context,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _relativeTime(post.createdAt),
                          style: AppTypography.caption(
                            context,
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  static String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) {
      return 'Ahora';
    }
    if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes} min';
    }
    if (diff.inHours < 24) {
      return 'Hace ${diff.inHours} h';
    }
    if (diff.inDays < 7) {
      return 'Hace ${diff.inDays} d';
    }
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) {
      return 'Hace $weeks sem';
    }
    final months = (diff.inDays / 30).floor();
    if (months < 12) {
      return 'Hace $months mes${months == 1 ? '' : 'es'}';
    }
    final years = (diff.inDays / 365).floor();
    return 'Hace $years año${years == 1 ? '' : 's'}';
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = isDestructive ? const Color(0xFFDC2626) : palette.textPrimary;

    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(context, color: color),
          ),
        ),
      ],
    );
  }
}
