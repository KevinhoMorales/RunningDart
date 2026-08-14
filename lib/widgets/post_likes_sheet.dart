import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/public_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/social_provider.dart';
import '../services/social_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_snackbar.dart';
import 'follow_user_row.dart';
import 'haptic_controls.dart';

/// Lista de quienes dieron "me gusta" a una publicación, con páginas.
Future<void> showPostLikesSheet(BuildContext context, String postId) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => PostLikesSheet(postId: postId),
  );
}

class PostLikesSheet extends StatefulWidget {
  const PostLikesSheet({super.key, required this.postId});

  final String postId;

  @override
  State<PostLikesSheet> createState() => _PostLikesSheetState();
}

class _PostLikesSheetState extends State<PostLikesSheet> {
  final _socialService = SocialService();

  List<PublicProfile> _profiles = [];
  Object? _nextCursor;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final page = await _socialService.fetchPostLikeProfiles(widget.postId);
      if (!mounted) {
        return;
      }
      setState(() {
        _profiles = page.items;
        _nextCursor = page.cursor;
        _hasMore = page.hasMore;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'No se pudo cargar la lista.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoadingMore || _nextCursor == null) {
      return;
    }
    setState(() => _isLoadingMore = true);
    try {
      final page = await _socialService.fetchPostLikeProfiles(
        widget.postId,
        startAfter: _nextCursor,
      );
      if (!mounted) {
        return;
      }
      final known = _profiles.map((p) => p.id).toSet();
      final fresh =
          page.items.where((p) => !known.contains(p.id)).toList();
      setState(() {
        _profiles = [..._profiles, ...fresh];
        _nextCursor = page.cursor;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        AppSnackBar.show(context, 'No se pudieron cargar más me gusta.');
      }
    }
  }

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.pixels >= metrics.maxScrollExtent - 120) {
      unawaited(_loadMore());
    }
    return false;
  }

  Future<void> _toggleFollow(String targetUserId) async {
    try {
      await context.read<SocialProvider>().toggleFollow(targetUserId);
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, 'No se pudo actualizar. Intenta de nuevo.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final currentUserId = context.watch<AuthProvider>().user?.id ?? '';
    final social = context.watch<SocialProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
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
              Text('Me gusta', style: AppTypography.sectionTitle(context)),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: _buildBody(context, scrollController, currentUserId,
                    social, palette),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    ScrollController scrollController,
    String currentUserId,
    SocialProvider social,
    AppPalette palette,
  ) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _profiles.isEmpty) {
      return _Message(text: _error!, palette: palette);
    }

    if (_profiles.isEmpty) {
      return _Message(
        text: 'Todavía nadie le dio me gusta.',
        palette: palette,
      );
    }

    final footer = _hasMore || _isLoadingMore;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        itemCount: _profiles.length + (footer ? 1 : 0),
        itemBuilder: (context, index) {
          if (footer && index == _profiles.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: _isLoadingMore
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : HapticTextButton(
                        onPressed: _loadMore,
                        child: const Text('Cargar más'),
                      ),
              ),
            );
          }
          final profile = _profiles[index];
          final isSelf = profile.id == currentUserId;
          return FollowUserRow(
            profile: profile,
            showFollowButton: !isSelf,
            isFollowing: social.isFollowing(profile.id),
            onOpenProfile: () {
              Navigator.of(context).pop();
              context.push('/user/${profile.id}');
            },
            onToggleFollow: () => _toggleFollow(profile.id),
          );
        },
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
