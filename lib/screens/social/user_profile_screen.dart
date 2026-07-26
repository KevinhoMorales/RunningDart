import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/post_model.dart';
import '../../models/public_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/social_provider.dart';
import '../../services/firestore_post_service.dart';
import '../../services/social_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/modern_text_field.dart';
import '../../widgets/post_grid.dart';
import '../../widgets/post_viewer.dart';
import '../../widgets/user_avatar.dart';
import '../profile/profile_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.userId,
    this.isAccountView = false,
  });

  final String userId;

  /// Cuando es `true` la pantalla es "Mi cuenta": suma la credencial, la
  /// membresía y los accesos del socio debajo del encabezado social.
  final bool isAccountView;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _postService = FirestorePostService();
  final _socialService = SocialService();

  StreamSubscription<List<PostModel>>? _postsSubscription;

  PublicProfile? _profile;
  List<PostModel> _posts = const [];
  bool _loadingPosts = true;
  bool _loadingProfile = true;
  String? _postsError;
  int _followers = 0;
  int _following = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final currentUserId = context.read<AuthProvider>().user?.id;
    if (currentUserId != null) {
      context.read<SocialProvider>().start(currentUserId);
    }
    _listenPosts();
    await _loadProfile();
  }

  void _listenPosts() {
    _postsSubscription?.cancel();
    _postsSubscription = _postService
        .watchUserPosts(widget.userId, includeHidden: _canSeeHidden)
        .listen(
      (posts) {
        if (!mounted) {
          return;
        }
        setState(() {
          _posts = posts.where(_canSee).toList(growable: false);
          _loadingPosts = false;
          _postsError = null;
        });
      },
      onError: (error) {
        debugPrint('No se pudieron cargar las publicaciones del perfil: $error');
        if (mounted) {
          setState(() {
            _loadingPosts = false;
            _postsError = 'No pudimos cargar las publicaciones.';
          });
        }
      },
    );
  }

  /// En el perfil de otra persona las publicaciones ocultas por moderación no
  /// se muestran; su autor y los administradores sí las ven.
  bool get _canSeeHidden {
    final auth = context.read<AuthProvider>();
    return auth.isAdmin || auth.user?.id == widget.userId;
  }

  bool _canSee(PostModel post) => !post.isHidden || _canSeeHidden;

  PostModel? get _latestPost => _posts.isEmpty ? null : _posts.first;

  String? get _postFallbackName {
    final name = _latestPost?.authorName.trim();
    return (name == null || name.isEmpty) ? null : name;
  }

  String? get _postFallbackPhoto {
    final photo = _latestPost?.authorPhotoUrl;
    return (photo == null || photo.isEmpty) ? null : photo;
  }

  Future<void> _loadProfile() async {
    try {
      final results = await Future.wait([
        _socialService.getPublicProfile(widget.userId),
        _socialService.followersCount(widget.userId),
        _socialService.followingCount(widget.userId),
      ]);
      if (!mounted) {
        return;
      }
      // FirebaseAuthService mantiene sincronizado el perfil público del usuario
      // en sesión, así que aquí solo se lee.
      final profile = results[0] as PublicProfile?;
      setState(() {
        _profile = profile;
        _followers = results[1] as int;
        _following = results[2] as int;
        _loadingProfile = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingProfile = false);
      }
    }
  }

  String get _displayName {
    final fromProfile = _profile?.displayName.trim();
    if (fromProfile != null && fromProfile.isNotEmpty) {
      return fromProfile;
    }
    final authUser = context.read<AuthProvider>().user;
    if (authUser != null && authUser.id == widget.userId) {
      final fromAuth = authUser.displayName.trim();
      if (fromAuth.isNotEmpty) {
        return fromAuth;
      }
    }
    final fromPost = _postFallbackName?.trim();
    if (fromPost != null && fromPost.isNotEmpty) {
      return fromPost;
    }
    return 'Miembro SAINTS';
  }

  String? get _photoUrl {
    final fromProfile = _profile?.photoUrl;
    if (fromProfile != null && fromProfile.isNotEmpty) {
      return fromProfile;
    }
    final authUser = context.read<AuthProvider>().user;
    if (authUser != null && authUser.id == widget.userId) {
      final fromAuth = authUser.photoUrl;
      if (fromAuth != null && fromAuth.isNotEmpty) {
        return fromAuth;
      }
    }
    final fromPost = _postFallbackPhoto;
    if (fromPost != null && fromPost.isNotEmpty) {
      return fromPost;
    }
    return null;
  }

  String? get _username {
    final fromProfile = _profile?.username?.trim();
    if (fromProfile != null && fromProfile.isNotEmpty) {
      return fromProfile;
    }
    final authUser = context.read<AuthProvider>().user;
    if (authUser != null && authUser.id == widget.userId) {
      final fromAuth = authUser.username?.trim();
      if (fromAuth != null && fromAuth.isNotEmpty) {
        return fromAuth;
      }
    }
    return null;
  }

  String? get _bio {
    final fromProfile = _profile?.bio;
    if (fromProfile != null && fromProfile.trim().isNotEmpty) {
      return fromProfile;
    }
    final authUser = context.read<AuthProvider>().user;
    if (authUser != null && authUser.id == widget.userId) {
      final fromAuth = authUser.bio;
      if (fromAuth != null && fromAuth.trim().isNotEmpty) {
        return fromAuth;
      }
    }
    return null;
  }

  Future<void> _toggleFollow() async {
    final social = context.read<SocialProvider>();
    final wasFollowing = social.isFollowing(widget.userId);
    try {
      await social.toggleFollow(widget.userId);
      if (!mounted) {
        return;
      }
      setState(() => _followers += wasFollowing ? -1 : 1);
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, 'No se pudo actualizar. Intenta de nuevo.');
      }
    }
  }

  Future<void> _blockUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Bloquear a $_displayName?'),
        content: const Text(
          'Ya no verás sus publicaciones en la comunidad.',
        ),
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
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await context.read<SocialProvider>().blockUser(widget.userId);
      if (mounted) {
        AppSnackBar.show(context, 'Usuario bloqueado.');
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, 'No se pudo bloquear. Intenta de nuevo.');
      }
    }
  }

  Future<void> _unblockUser() async {
    try {
      await context.read<SocialProvider>().unblockUser(widget.userId);
      if (mounted) {
        AppSnackBar.show(context, 'Usuario desbloqueado.');
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, 'No se pudo desbloquear. Intenta de nuevo.');
      }
    }
  }

  /// Borra sin volver a preguntar: la cuadrícula y el visor ya confirmaron.
  Future<void> _deleteConfirmedPost(PostModel post) async {
    try {
      await _postService.deletePost(post.id);
      if (mounted) {
        AppSnackBar.show(context, 'Publicación eliminada.');
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, 'No se pudo eliminar. Intenta de nuevo.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final authUser = context.watch<AuthProvider>().user;
    final isSelf = authUser?.id == widget.userId;
    final social = context.watch<SocialProvider>();
    final isFollowing = social.isFollowing(widget.userId);
    final isBlocked = !isSelf && social.isBlocked(widget.userId);
    final showAccount = widget.isAccountView && isSelf && authUser != null;
    // Borrar es solo del autor: el administrador oculta desde el feed.
    final canDelete = isSelf;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: CustomAppBar(
        title: widget.isAccountView ? 'Mi cuenta' : 'Perfil',
        leading: HapticIconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (widget.isAccountView)
            HapticIconButton(
              onPressed: () => context.push('/settings'),
              tooltip: 'Ajustes',
              icon: Icon(Icons.settings_rounded, color: palette.textPrimary),
            ),
          if (!isSelf)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz_rounded, color: palette.textPrimary),
              enableFeedback: false,
              onOpened: AppHaptics.lightTap,
              onSelected: AppHaptics.wrapValue((value) {
                if (value == 'block') {
                  _blockUser();
                } else if (value == 'unblock') {
                  _unblockUser();
                }
              }),
              itemBuilder: (context) => [
                if (isBlocked)
                  const PopupMenuItem(
                    value: 'unblock',
                    child: Text('Desbloquear usuario'),
                  )
                else
                  const PopupMenuItem(
                    value: 'block',
                    child: Text('Bloquear usuario'),
                  ),
              ],
            ),
        ],
      ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          // Bloquear a alguien tiene que ocultar también su perfil, no solo
          // filtrarlo del feed.
          : isBlocked
          ? Center(
              child: EmptyStateCard(
                icon: Icons.block_rounded,
                message: 'Bloqueaste a $_displayName',
                subtitle:
                    'No ves su perfil ni sus publicaciones. Puedes desbloquearlo cuando quieras.',
                actionLabel: 'Desbloquear',
                onAction: _unblockUser,
              ),
            )
          : HapticRefreshIndicator(
              onRefresh: _loadProfile,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _ProfileHeader(
                      userId: widget.userId,
                      displayName: _displayName,
                      username: _username,
                      photoUrl: _photoUrl,
                      bio: _bio,
                      email: showAccount ? authUser.email : null,
                      posts: _posts.length,
                      followers: _followers,
                      following: _following,
                      isSelf: isSelf,
                      isFollowing: isFollowing,
                      onToggleFollow: _toggleFollow,
                    ),
                  ),
                  if (showAccount)
                    SliverToBoxAdapter(child: AccountSections(user: authUser)),
                  // En "Mi cuenta" no va la cuadrícula: esas publicaciones ya
                  // se ven en el chip "Mi feed" de Comunidad.
                  if (!widget.isAccountView)
                    PostGrid(
                      posts: _posts,
                      isLoading: _loadingPosts,
                      onOpenPost: (post) => showPostViewer(
                        context,
                        post,
                        onDelete: canDelete
                            ? () => _deleteConfirmedPost(post)
                            : null,
                      ),
                      onDeletePost: canDelete ? _deleteConfirmedPost : null,
                      emptyMessage: isSelf
                          ? 'Aún no has publicado nada'
                          : 'Sin publicaciones todavía',
                      emptySubtitle: isSelf
                          ? 'Comparte tu primera carrera con la comunidad SAINTS.'
                          : null,
                      emptyActionLabel: isSelf ? 'Publicar' : null,
                      onEmptyAction:
                          isSelf ? () => context.push('/post/new') : null,
                      errorMessage: _postsError,
                      onRetry: () {
                        setState(() {
                          _loadingPosts = true;
                          _postsError = null;
                        });
                        _listenPosts();
                      },
                    ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xl),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.userId,
    required this.displayName,
    required this.username,
    required this.photoUrl,
    required this.bio,
    required this.email,
    required this.posts,
    required this.followers,
    required this.following,
    required this.isSelf,
    required this.isFollowing,
    required this.onToggleFollow,
  });

  final String userId;
  final String displayName;
  final String? username;
  final String? photoUrl;
  final String? bio;
  final String? email;
  final int posts;
  final int followers;
  final int following;
  final bool isSelf;
  final bool isFollowing;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UserAvatar(
                displayName: displayName,
                photoUrl: photoUrl,
                radius: 40,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _CountStat(
                        value: posts,
                        label: 'Publicaciones',
                      ),
                    ),
                    Expanded(
                      child: _CountStat(
                        value: followers,
                        label: 'Seguidores',
                        onTap: () => context.push('/user/$userId/followers'),
                      ),
                    ),
                    Expanded(
                      child: _CountStat(
                        value: following,
                        label: 'Siguiendo',
                        onTap: () => context.push('/user/$userId/following'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            displayName,
            style: AppTypography.title(context, weight: FontWeight.w700),
          ),
          if (username != null && username!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '@${username!.trim()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption(context, color: palette.textMuted),
            ),
          ],
          if (email != null && email!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              email!.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption(context, color: palette.textMuted),
            ),
          ],
          if (bio != null && bio!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              bio!.trim(),
              style: AppTypography.body(context).copyWith(height: 1.4),
            ),
          ] else if (isSelf) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: HapticTextButtonIcon(
                onPressed: () => context.push('/profile/edit'),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Agregar descripción'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xs,
                  ),
                  visualDensity: VisualDensity.compact,
                  foregroundColor: palette.textMuted,
                  textStyle: AppTypography.caption(context),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (!isSelf)
            isFollowing
                ? HapticOutlinedButtonIcon(
                    onPressed: onToggleFollow,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Siguiendo'),
                  )
                : PrimaryButton(
                    label: 'Seguir',
                    onPressed: onToggleFollow,
                  ),
          if (isSelf)
            HapticOutlinedButtonIcon(
              onPressed: () => context.push('/profile/edit'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar perfil'),
            ),
          const SizedBox(height: AppSpacing.sm),
          Divider(color: palette.cardBorder),
        ],
      ),
    );
  }
}

class _CountStat extends StatelessWidget {
  const _CountStat({
    required this.value,
    required this.label,
    this.onTap,
  });

  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null ? null : AppHaptics.wrap(onTap!),
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 2,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$value',
                style: AppTypography.title(context, weight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 2),
            // Etiquetas como "Publicaciones" no caben junto al avatar en
            // pantallas angostas: se encogen antes que recortarse.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: AppTypography.caption(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
