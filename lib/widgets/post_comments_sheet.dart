import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/post_comment_model.dart';
import '../models/post_model.dart';
import '../providers/auth_provider.dart';
import '../services/social_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';
import 'app_snackbar.dart';
import 'haptic_controls.dart';
import 'user_avatar.dart';

/// Hilo de comentarios de una publicación: lista en vivo + campo para escribir.
Future<void> showPostCommentsSheet(BuildContext context, PostModel post) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => PostCommentsSheet(post: post),
  );
}

class PostCommentsSheet extends StatefulWidget {
  const PostCommentsSheet({super.key, required this.post});

  final PostModel post;

  @override
  State<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<PostCommentsSheet> {
  final _socialService = SocialService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  ScrollController? _listScrollController;

  StreamSubscription<List<PostCommentModel>>? _subscription;
  List<PostCommentModel> _comments = const [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = _socialService.watchPostComments(widget.post.id).listen(
      (comments) {
        if (!mounted) {
          return;
        }
        setState(() {
          _comments = comments;
          _isLoading = false;
          _error = null;
        });
      },
      onError: (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoading = false;
          _error = 'No se pudieron cargar los comentarios.';
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    final user = context.read<AuthProvider>().user;
    if (user == null) {
      return;
    }

    setState(() => _isSending = true);
    try {
      await _socialService.addComment(
        postId: widget.post.id,
        postAuthorId: widget.post.authorId,
        authorId: user.id,
        authorName: user.displayName.trim().isEmpty
            ? 'Miembro SAINTS'
            : user.displayName.trim(),
        authorPhotoUrl: user.photoUrl,
        text: text,
      );
      if (!mounted) {
        return;
      }
      _controller.clear();
      AppHaptics.lightTap();
      // Baja al final cuando llega el comentario propio.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final scroll = _listScrollController;
        if (scroll != null && scroll.hasClients) {
          scroll.animateTo(
            scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } on SocialServiceException catch (e) {
      if (mounted) {
        AppSnackBar.show(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, 'No se pudo publicar el comentario.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _delete(PostCommentModel comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar comentario?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          HapticTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: context.palette.textMuted),
            ),
          ),
          HapticFilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await _socialService.deleteComment(comment.id);
      if (mounted) {
        AppSnackBar.show(context, 'Comentario eliminado.');
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, 'No se pudo eliminar. Intenta de nuevo.');
      }
    }
  }

  void _openAuthor(String userId) {
    Navigator.of(context).pop();
    context.push('/user/$userId');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final currentUserId = context.watch<AuthProvider>().user?.id ?? '';
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, sheetScrollController) {
          return Container(
            decoration: BoxDecoration(
              color: palette.bottomSheetBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusLg),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.inputBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Comentarios', style: AppTypography.sectionTitle(context)),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: _buildList(
                    sheetScrollController,
                    currentUserId,
                    palette,
                  ),
                ),
                _Composer(
                  controller: _controller,
                  focusNode: _focusNode,
                  isSending: _isSending,
                  onSend: _send,
                  palette: palette,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(
    ScrollController sheetScrollController,
    String currentUserId,
    AppPalette palette,
  ) {
    _listScrollController = sheetScrollController;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _comments.isEmpty) {
      return _Message(text: _error!, palette: palette);
    }

    if (_comments.isEmpty) {
      return _Message(
        text: 'Sé el primero en comentar.',
        palette: palette,
      );
    }

    return ListView.builder(
      controller: sheetScrollController,
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        final comment = _comments[index];
        final isOwn = comment.authorId == currentUserId;
        return _CommentTile(
          comment: comment,
          onOpenAuthor: () => _openAuthor(comment.authorId),
          onDelete: isOwn ? () => _delete(comment) : null,
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.onOpenAuthor,
    this.onDelete,
  });

  final PostCommentModel comment;
  final VoidCallback onOpenAuthor;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final name = comment.authorName.trim().isEmpty
        ? 'Miembro SAINTS'
        : comment.authorName.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            displayName: name,
            photoUrl: comment.authorPhotoUrl,
            radius: 18,
            onTap: onOpenAuthor,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: AppHaptics.wrap(onOpenAuthor),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: name,
                            style: AppTypography.body(
                              context,
                              weight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: '  ${_relativeTime(comment.createdAt)}',
                            style: AppTypography.caption(
                              context,
                              color: palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  comment.text,
                  style: AppTypography.body(context).copyWith(height: 1.35),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz_rounded, color: palette.textMuted),
              enableFeedback: false,
              onOpened: AppHaptics.lightTap,
              onSelected: (_) {
                AppHaptics.lightTap();
                onDelete!();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: Color(0xFFDC2626),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        'Eliminar',
                        style: TextStyle(color: Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
    required this.palette,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: palette.bottomSheetBackground,
          border: Border(top: BorderSide(color: palette.cardBorder)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 4,
                maxLength: PostCommentModel.maxTextLength,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Escribe un comentario…',
                  counterText: '',
                  filled: true,
                  fillColor: palette.inputFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide(color: palette.inputBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide(color: palette.inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide(color: palette.accentPrimary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            HapticIconButton(
              tooltip: 'Publicar',
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.accentPrimary,
                      ),
                    )
                  : Icon(Icons.send_rounded, color: palette.accentPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.palette});

  final String text;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.body(context, color: palette.textMuted),
        ),
      ),
    );
  }
}
