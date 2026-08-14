import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/post_model.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';
import '../utils/helpers.dart';
import 'delete_post_dialog.dart';
import 'haptic_controls.dart';
import 'post_comments_sheet.dart';
import 'post_likes_sheet.dart';
import 'user_avatar.dart';

/// Abre una publicación a pantalla completa, con zoom y cierre por arrastre.
///
/// Cuando llega [onDelete] el visor muestra el menú para eliminar; se ejecuta
/// después de confirmar y de cerrar el visor.
Future<void> showPostViewer(
  BuildContext context,
  PostModel post, {
  Future<void> Function()? onDelete,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      // Sin opacidad para que al arrastrar se vea la pantalla de atrás.
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondary, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (context, animation, secondary) =>
          PostViewer(post: post, onDelete: onDelete),
    ),
  );
}

class PostViewer extends StatefulWidget {
  const PostViewer({super.key, required this.post, this.onDelete});

  final PostModel post;
  final Future<void> Function()? onDelete;

  /// Cuánto hay que arrastrar para que el visor se cierre al soltar.
  static const dismissDistance = 120.0;

  @override
  State<PostViewer> createState() => _PostViewerState();
}

class _PostViewerState extends State<PostViewer>
    with SingleTickerProviderStateMixin {
  final _transformationController = TransformationController();
  late final AnimationController _zoomController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _zoomAnimation;

  Offset? _doubleTapPosition;
  double _dragOffset = 0;

  static const _zoomScale = 2.5;

  bool get _isZoomed =>
      _transformationController.value.getMaxScaleOnAxis() > 1.01;

  @override
  void initState() {
    super.initState();
    _zoomController.addListener(() {
      final animation = _zoomAnimation;
      if (animation != null) {
        _transformationController.value = animation.value;
      }
    });
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _animateTo(Matrix4 target) {
    _zoomAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: target,
    ).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeOutCubic),
    );
    _zoomController.forward(from: 0);
  }

  void _handleDoubleTap() {
    AppHaptics.lightTap();
    if (_isZoomed) {
      _animateTo(Matrix4.identity());
      setState(() {});
      return;
    }

    // Acerca dejando el punto tocado en el mismo lugar de la pantalla.
    final position = _doubleTapPosition ?? Offset.zero;
    final target = Matrix4.identity()
      ..translateByDouble(
        -position.dx * (_zoomScale - 1),
        -position.dy * (_zoomScale - 1),
        0,
        1,
      )
      ..scaleByDouble(_zoomScale, _zoomScale, _zoomScale, 1);
    _animateTo(target);
    setState(() {});
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() => _dragOffset += details.delta.dy);
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (_dragOffset.abs() > PostViewer.dismissDistance || velocity.abs() > 700) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _dragOffset = 0);
  }

  Future<void> _handleDelete() async {
    final navigator = Navigator.of(context);
    if (!await confirmDeletePost(context)) {
      return;
    }
    navigator.pop();
    await widget.onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        (_dragOffset.abs() / (PostViewer.dismissDistance * 2)).clamp(0.0, 1.0);
    final imageUrl = widget.post.imageUrl;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 1 - progress * 0.7),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // El arrastre solo cierra cuando la foto está sin acercar; con zoom el
          // gesto vertical le toca al InteractiveViewer para desplazarla.
          GestureDetector(
            onVerticalDragUpdate: _isZoomed ? null : _handleDragUpdate,
            onVerticalDragEnd: _isZoomed ? null : _handleDragEnd,
            onDoubleTapDown: (details) =>
                _doubleTapPosition = details.localPosition,
            onDoubleTap: _handleDoubleTap,
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: InteractiveViewer(
                transformationController: _transformationController,
                maxScale: 4,
                // Sin zoom el arrastre de un dedo es para cerrar, así que el
                // visor no debe disputar ese gesto; el pellizco sigue activo.
                panEnabled: _isZoomed,
                onInteractionEnd: (_) => setState(() {}),
                child: imageUrl == null || imageUrl.isEmpty
                    ? const _MissingImage()
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const _MissingImage(),
                      ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopBar(
              onClose: () => Navigator.of(context).pop(),
              onDelete: widget.onDelete == null ? null : _handleDelete,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _Details(post: widget.post),
          ),
        ],
      ),
    );
  }
}

enum _ViewerAction { delete }

class _MissingImage extends StatelessWidget {
  const _MissingImage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.white54,
        size: 48,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose, required this.onDelete});

  final VoidCallback onClose;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              HapticIconButton(
                tooltip: 'Cerrar',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
              const Spacer(),
              if (onDelete != null)
                PopupMenuButton<_ViewerAction>(
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white,
                  ),
                  tooltip: 'Más opciones',
                  enableFeedback: false,
                  onOpened: AppHaptics.lightTap,
                  onSelected: (_) {
                    AppHaptics.lightTap();
                    onDelete!();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _ViewerAction.delete,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Eliminar',
                            style: AppTypography.body(
                              context,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.post});

  final PostModel post;

  @override
  Widget build(BuildContext context) {
    final caption = post.caption?.trim();
    final commentsLabel = post.commentsCount <= 0
        ? 'Comentar'
        : post.commentsCount == 1
            ? '1 comentario'
            : '${post.commentsCount} comentarios';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: AppHaptics.wrap(
                  () => context.push('/user/${post.authorId}'),
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: Row(
                  children: [
                    UserAvatar(
                      displayName: post.authorName,
                      photoUrl: post.authorPhotoUrl,
                      radius: 16,
                      onTap: () => context.push('/user/${post.authorId}'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        post.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          context,
                          color: Colors.white,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                Helpers.formatDate(post.createdAt),
                style: AppTypography.caption(context, color: Colors.white70),
              ),
              if (post.likesCount > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                HapticTextButton(
                  onPressed: () => showPostLikesSheet(context, post.id),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        size: 16,
                        color: Color(0xFFDC2626),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${post.likesCount} Me gusta',
                        style: AppTypography.body(
                          context,
                          color: Colors.white,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              HapticTextButton(
                onPressed: () => showPostCommentsSheet(context, post),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      commentsLabel,
                      style: AppTypography.body(
                        context,
                        color: Colors.white,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (caption != null && caption.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  caption,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(context, color: Colors.white)
                      .copyWith(height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
