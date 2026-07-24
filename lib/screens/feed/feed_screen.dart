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
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/delete_post_dialog.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/horizontal_chip_tab_bar.dart';
import '../../widgets/post_card.dart';
import '../../widgets/post_grid.dart';
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
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted) {
      return;
    }
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) {
      return;
    }
    context.read<FeedProvider>().start(userId);
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
        HorizontalChipTabBar(
          labels: const ['Explorar', 'Mi feed', 'Para ti', 'Conoce'],
          icons: const [
            Icons.public_rounded,
            Icons.grid_on_rounded,
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
              _MyPostsGridTab(
                posts: feed.myPosts,
                isLoading: feed.isLoadingMyPosts,
                onRefresh: _handleRefresh,
                onDeletePost: _deleteConfirmedPost,
              ),
              _PostList(
                posts: followingPosts,
                isLoading: feed.isLoading,
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
              ),
              const UserSearchTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _MyPostsGridTab extends StatelessWidget {
  const _MyPostsGridTab({
    required this.posts,
    required this.isLoading,
    required this.onRefresh,
    required this.onDeletePost,
  });

  final List<PostModel> posts;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Future<void> Function(PostModel post) onDeletePost;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          PostGrid(
            posts: posts,
            isLoading: isLoading,
            onOpenPost: (post) => showPostViewer(
              context,
              post,
              onDelete: () => onDeletePost(post),
            ),
            onDeletePost: onDeletePost,
            emptyMessage: 'Aún no has publicado nada',
            emptySubtitle:
                'Comparte tu primera carrera con la comunidad SAINTS.',
            emptyActionLabel: 'Publicar',
            onEmptyAction: () => context.push('/post/new'),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.xl),
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
  });

  final List<PostModel> posts;
  final bool isLoading;
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

  @override
  Widget build(BuildContext context) {
    if (isLoading && posts.isEmpty) {
      return const LoadingSkeleton();
    }

    if (error != null && posts.isEmpty) {
      return RefreshIndicator(
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
      return RefreshIndicator(
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

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final canDelete = post.authorId == currentUserId || isAdmin;
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
            onOpenPost: () => showPostViewer(
              context,
              post,
              onDelete: canDelete ? () => onDeletePost(post) : null,
            ),
          );
        },
      ),
    );
  }
}
