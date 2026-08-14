import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/social_provider.dart';
import '../../services/social_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/delete_post_dialog.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/hide_post_dialog.dart';
import '../../widgets/horizontal_chip_tab_bar.dart';
import '../../widgets/post_card.dart';
import '../../widgets/post_comments_sheet.dart';
import '../../widgets/post_likes_sheet.dart';
import '../../widgets/post_viewer.dart';
import '../social/user_search_tab.dart';

const communityHomeTabIndex = 1;

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Explorar / Siguiendo / Conoce. Las propias van en el perfil.
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted) {
      return;
    }
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id;
    if (userId == null) {
      return;
    }
    context.read<FeedProvider>().start(userId, isModerator: auth.isAdmin);
    context.read<SocialProvider>().start(userId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() => context.read<FeedProvider>().refresh();

  void _openAuthor(PostModel post) {
    context.push('/user/${post.authorId}');
  }

  Future<void> _toggleLike(PostModel post) async {
    try {
      await context.read<FeedProvider>().toggleLike(post);
    } on SocialServiceException catch (e) {
      if (mounted) {
        AppSnackBar.show(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, 'No se pudo actualizar tu me gusta.');
      }
    }
  }

  Future<void> _handleAction(PostModel post, PostCardAction action) async {
    switch (action) {
      case PostCardAction.report:
        await _reportPost(post);
        break;
      case PostCardAction.block:
        await _blockAuthor(post);
        break;
      case PostCardAction.delete:
        await _deletePost(post);
        break;
      case PostCardAction.hide:
        await _hidePost(post);
        break;
      case PostCardAction.unhide:
        await _unhidePost(post);
        break;
    }
  }

  Future<void> _hidePost(PostModel post) async {
    final decision = await askHideReason(context);
    if (decision == null || !mounted) {
      return;
    }
    try {
      await context.read<FeedProvider>().hidePost(
            post.id,
            reason: decision.reason,
            note: decision.note,
          );
      if (mounted) {
        AppSnackBar.show(context, 'Publicación oculta para la comunidad.');
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, 'No se pudo ocultar. Intenta de nuevo.');
      }
    }
  }

  Future<void> _unhidePost(PostModel post) async {
    try {
      await context.read<FeedProvider>().unhidePost(post.id);
      if (mounted) {
        AppSnackBar.show(context, 'Publicación visible otra vez.');
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, 'No se pudo mostrar. Intenta de nuevo.');
      }
    }
  }

  Future<void> _reportPost(PostModel post) async {
    final confirmed = await _confirm(
      title: '¿Reportar publicación?',
      message:
          'Nuestro equipo la revisará. Gracias por ayudarnos a cuidar la comunidad.',
      confirmLabel: 'Reportar',
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await context.read<FeedProvider>().reportPost(post.id);
      if (mounted) {
        AppSnackBar.show(context, 'Gracias, recibimos tu reporte.');
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, 'No se pudo enviar el reporte.');
      }
    }
  }

  Future<void> _blockAuthor(PostModel post) async {
    final confirmed = await _confirm(
      title: '¿Bloquear a ${post.authorName}?',
      message: 'Ya no verás sus publicaciones en la comunidad.',
      confirmLabel: 'Bloquear',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await context.read<SocialProvider>().blockUser(post.authorId);
      if (mounted) {
        AppSnackBar.show(context, 'Usuario bloqueado.');
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, 'No se pudo bloquear. Intenta de nuevo.');
      }
    }
  }

  Future<void> _deletePost(PostModel post) async {
    if (!await confirmDeletePost(context) || !mounted) {
      return;
    }
    await _deleteConfirmedPost(post);
  }

  /// Borra sin volver a preguntar: la usan el visor y la cuadrícula, que ya
  /// pidieron confirmación antes de cerrarse.
  Future<void> _deleteConfirmedPost(PostModel post) async {
    try {
      await context.read<FeedProvider>().deletePost(post.id);
      if (mounted) {
        AppSnackBar.show(context, 'Publicación eliminada.');
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, 'No se pudo eliminar. Intenta de nuevo.');
      }
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    final palette = context.palette;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          HapticTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: palette.textMuted),
            ),
          ),
          HapticFilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: isDestructive
                  ? const Color(0xFFDC2626)
                  : Theme.of(dialogContext).colorScheme.primary,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedProvider>();
    final social = context.watch<SocialProvider>();
    final currentUserId = context.watch<AuthProvider>().user?.id ?? '';
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    final explorePosts = feed.posts;
    final followingPosts = feed.postsFollowing(social.followingIds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Comunidad',
          subtitle: 'Comparte y descubre a la comunidad SAINTS',
        ),
        if (feed.blockedError != null)
          _FeedWarningBanner(
            message:
                '${feed.blockedError!} Puede que veas publicaciones de personas que bloqueaste.',
            onRetry: _handleRefresh,
          ),
        HorizontalChipTabBar(
          labels: const ['Explorar', 'Siguiendo', 'Conoce'],
          icons: const [
            Icons.public_rounded,
            Icons.people_alt_rounded,
            Icons.search_rounded,
          ],
          controller: _tabController,
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _PostList(
                posts: explorePosts,
                isLoading: feed.isLoading,
                isLoadingMore: feed.isLoadingMore,
                hasMore: feed.hasMore,
                onLoadMore: () => context.read<FeedProvider>().loadMore(),
                error: feed.error,
                currentUserId: currentUserId,
                isAdmin: isAdmin,
                onRefresh: _handleRefresh,
                onOpenAuthor: _openAuthor,
                onAction: _handleAction,
                onToggleLike: _toggleLike,
                onDeletePost: _deleteConfirmedPost,
                emptyIcon: Icons.people_outline_rounded,
                emptyTitle: 'Aún no hay publicaciones',
                emptySubtitle:
                    'Sé el primero en compartir algo con la comunidad.',
                emptyActionLabel: 'Publicar',
                onEmptyAction: () => context.push('/post/new'),
              ),
              _PostList(
                posts: followingPosts,
                isLoading: feed.isLoading,
                isLoadingMore: feed.isLoadingMore,
                hasMore: feed.hasMore,
                onLoadMore: () => context.read<FeedProvider>().loadMore(),
                error: feed.error,
                currentUserId: currentUserId,
                isAdmin: isAdmin,
                onRefresh: _handleRefresh,
                onOpenAuthor: _openAuthor,
                onAction: _handleAction,
                onToggleLike: _toggleLike,
                onDeletePost: _deleteConfirmedPost,
                emptyIcon: Icons.person_add_alt_1_outlined,
                emptyTitle: 'Sigue a más personas',
                emptySubtitle:
                    'Cuando sigas a alguien, sus publicaciones aparecerán aquí.',
                // Siguiendo filtra el feed global: si hay pocas de seguidos,
                // seguimos paginando el feed hasta llenar o agotar.
                autofillWhenSparse: true,
              ),
              const UserSearchTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeedWarningBanner extends StatelessWidget {
  const _FeedWarningBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.infoBannerBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: palette.infoBannerBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: palette.accentPrimary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: AppTypography.caption(context)),
          ),
          HapticTextButton(
            onPressed: () => onRetry(),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _PostList extends StatelessWidget {
  const _PostList({
    required this.posts,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.onLoadMore,
    required this.error,
    required this.currentUserId,
    required this.isAdmin,
    required this.onRefresh,
    required this.onOpenAuthor,
    required this.onAction,
    required this.onToggleLike,
    required this.onDeletePost,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.autofillWhenSparse = false,
  });

  final List<PostModel> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final String? error;
  final String currentUserId;
  final bool isAdmin;
  final Future<void> Function() onRefresh;
  final void Function(PostModel post) onOpenAuthor;
  final void Function(PostModel post, PostCardAction action) onAction;
  final void Function(PostModel post) onToggleLike;
  final Future<void> Function(PostModel post) onDeletePost;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  /// Cuando la lista visible es un filtro del feed (p. ej. Siguiendo), pide
  /// más páginas del feed global hasta tener contenido o agotar el cursor.
  final bool autofillWhenSparse;

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.pixels >= metrics.maxScrollExtent - 240) {
      onLoadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (autofillWhenSparse &&
        !isLoading &&
        !isLoadingMore &&
        hasMore &&
        posts.length < 8) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
    }

    if (isLoading && posts.isEmpty) {
      return const LoadingSkeleton();
    }

    if (error != null && posts.isEmpty) {
      return HapticRefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: EmptyStateCard(
                  icon: Icons.cloud_off_rounded,
                  message: 'No pudimos cargar la comunidad',
                  subtitle:
                      'Desliza hacia abajo para reintentar o vuelve en un momento.',
                  actionLabel: 'Reintentar',
                  onAction: onRefresh,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (posts.isEmpty) {
      return HapticRefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: EmptyStateCard(
                  icon: emptyIcon,
                  message: emptyTitle,
                  subtitle: emptySubtitle,
                  actionLabel: emptyActionLabel,
                  onAction: onEmptyAction,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final feed = context.watch<FeedProvider>();
    final footer = hasMore || isLoadingMore;

    return HapticRefreshIndicator(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          itemCount: posts.length + (footer ? 1 : 0),
          itemBuilder: (context, index) {
            if (footer && index == posts.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: isLoadingMore
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : HapticTextButton(
                          onPressed: onLoadMore,
                          child: const Text('Cargar más'),
                        ),
                ),
              );
            }
            final post = posts[index];
            final canDelete = post.authorId == currentUserId;
            return PostCard(
              post: post,
              currentUserId: currentUserId,
              isAdmin: isAdmin,
              onOpenAuthor: () => onOpenAuthor(post),
              onAction: (action) => onAction(post, action),
              isLiked: feed.isLiked(post.id),
              likesCount: feed.likesFor(post),
              onToggleLike: () => onToggleLike(post),
              onOpenLikes: () => showPostLikesSheet(context, post.id),
              onOpenComments: () => showPostCommentsSheet(context, post),
              onOpenPost: () => showPostViewer(
                context,
                post,
                onDelete: canDelete ? () => onDeletePost(post) : null,
              ),
            );
          },
        ),
      ),
    );
  }
}
