import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/page_result.dart';
import '../../models/public_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/social_provider.dart';
import '../../services/social_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/follow_user_row.dart';
import '../../widgets/haptic_controls.dart';

enum FollowListMode { followers, following }

class FollowListScreen extends StatefulWidget {
  const FollowListScreen({
    super.key,
    required this.userId,
    required this.mode,
  });

  final String userId;
  final FollowListMode mode;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final _socialService = SocialService();

  List<PublicProfile> _profiles = [];
  Object? _nextCursor;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _generation = 0;
  String? _error;

  String get _title =>
      widget.mode == FollowListMode.followers ? 'Seguidores' : 'Siguiendo';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUserId = context.read<AuthProvider>().user?.id;
      if (currentUserId != null) {
        context.read<SocialProvider>().start(currentUserId);
      }
      _loadInitial();
    });
  }

  Future<PageResult<PublicProfile>> _fetchPage({Object? startAfter}) {
    if (widget.mode == FollowListMode.followers) {
      return _socialService.fetchFollowersPage(
        widget.userId,
        startAfter: startAfter,
      );
    }
    return _socialService.fetchFollowingPage(
      widget.userId,
      startAfter: startAfter,
    );
  }

  Future<void> _loadInitial() async {
    final generation = ++_generation;
    setState(() {
      _isLoading = _profiles.isEmpty;
      _error = null;
      _nextCursor = null;
      _hasMore = true;
      _isLoadingMore = false;
      _profiles = [];
    });
    try {
      final page = await _fetchPage();
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _profiles = page.items;
        _nextCursor = page.cursor;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _error = 'No se pudo cargar la lista.';
        _isLoading = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoadingMore || _isLoading || _nextCursor == null) {
      return;
    }
    final generation = _generation;
    setState(() => _isLoadingMore = true);
    try {
      final page = await _fetchPage(startAfter: _nextCursor);
      if (!mounted || generation != _generation) {
        return;
      }
      final known = _profiles.map((p) => p.id).toSet();
      final fresh = page.items.where((p) => !known.contains(p.id)).toList();
      setState(() {
        _profiles = [..._profiles, ...fresh];
        _nextCursor = page.cursor;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() => _isLoadingMore = false);
      AppSnackBar.show(context, 'No se pudieron cargar más personas.');
    }
  }

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.pixels >= metrics.maxScrollExtent - 160) {
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

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: CustomAppBar(
        title: _title,
        leading: HapticIconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : HapticRefreshIndicator(
              onRefresh: _loadInitial,
              child: _error != null && _profiles.isEmpty
                  ? CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: EmptyStateCard(
                              icon: Icons.cloud_off_rounded,
                              message: 'No pudimos cargar la lista',
                              subtitle:
                                  'Desliza hacia abajo para reintentar.',
                              actionLabel: 'Reintentar',
                              onAction: _loadInitial,
                            ),
                          ),
                        ),
                      ],
                    )
                  : _profiles.isEmpty
                      ? CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: EmptyStateCard(
                                  icon: widget.mode == FollowListMode.followers
                                      ? Icons.people_outline_rounded
                                      : Icons.person_add_alt_1_outlined,
                                  message: widget.mode ==
                                          FollowListMode.followers
                                      ? 'Aún no hay seguidores'
                                      : 'Aún no sigue a nadie',
                                  subtitle: widget.mode ==
                                          FollowListMode.followers
                                      ? 'Cuando alguien te siga, aparecerá aquí.'
                                      : 'Las personas que siga aparecerán aquí.',
                                ),
                              ),
                            ),
                          ],
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: _onScroll,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            itemCount: _profiles.length +
                                (_hasMore || _isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _profiles.length) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.md,
                                  ),
                                  child: Center(
                                    child: _isLoadingMore
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
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
                                onOpenProfile: () =>
                                    context.push('/user/${profile.id}'),
                                onToggleFollow: () =>
                                    _toggleFollow(profile.id),
                              );
                            },
                          ),
                        ),
            ),
    );
  }
}
