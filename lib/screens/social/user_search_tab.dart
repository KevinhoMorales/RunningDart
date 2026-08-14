import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/public_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/social_provider.dart';
import '../../services/social_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/admin_search_field.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/follow_user_row.dart';
import '../../widgets/haptic_controls.dart';

class UserSearchTab extends StatefulWidget {
  const UserSearchTab({super.key});

  @override
  State<UserSearchTab> createState() => _UserSearchTabState();
}

class _UserSearchTabState extends State<UserSearchTab> {
  final _searchController = TextEditingController();
  final _socialService = SocialService();

  List<PublicProfile> _results = const [];
  Object? _nextCursor;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;

  /// Sube en cada búsqueda nueva para descartar páginas en vuelo.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _search(''));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _results = const [];
      _nextCursor = null;
      _hasMore = true;
      _isLoadingMore = false;
    });

    try {
      final page = await _socialService.searchProfilesPage(query);
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _results = page.items;
        _nextCursor = page.cursor;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _hasError = true;
        _isLoading = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoadingMore || _isLoading || _nextCursor == null) {
      return;
    }

    final requestId = _requestId;
    setState(() => _isLoadingMore = true);

    try {
      final page = await _socialService.searchProfilesPage(
        _searchController.text,
        startAfter: _nextCursor,
      );
      if (!mounted || requestId != _requestId) {
        return;
      }

      final known = _results.map((profile) => profile.id).toSet();
      final fresh =
          page.items.where((profile) => !known.contains(profile.id)).toList();
      setState(() {
        _results = [..._results, ...fresh];
        _nextCursor = page.cursor;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) {
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
    final currentUserId = context.watch<AuthProvider>().user?.id ?? '';
    final social = context.watch<SocialProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSearchFieldStateful(
          controller: _searchController,
          hintText: 'Buscar por @usuario o nombre',
          onChanged: _search,
        ),
        Expanded(child: _buildResults(currentUserId, social)),
      ],
    );
  }

  Widget _buildResults(String currentUserId, SocialProvider social) {
    if (_isLoading && _results.isEmpty) {
      return const LoadingSkeleton();
    }

    if (_hasError) {
      return Center(
        child: EmptyStateCard(
          icon: Icons.cloud_off_rounded,
          message: 'No pudimos buscar personas',
          subtitle: 'Revisa tu conexión e intenta de nuevo.',
          actionLabel: 'Reintentar',
          onAction: () => _search(_searchController.text),
        ),
      );
    }

    // A quien bloqueaste no debería reaparecer en la búsqueda.
    final visible = _results
        .where((profile) => !social.isBlocked(profile.id))
        .toList(growable: false);

    if (visible.isEmpty && _hasMore && !_isLoadingMore && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_loadMore());
        }
      });
    }

    if (visible.isEmpty && !_hasMore) {
      return const Center(
        child: EmptyStateCard(
          icon: Icons.search_off_rounded,
          message: 'Sin resultados',
          subtitle: 'Prueba con otro nombre o con su @usuario.',
        ),
      );
    }

    if (visible.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final footer = _hasMore || _isLoadingMore;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        itemCount: visible.length + (footer ? 1 : 0),
        itemBuilder: (context, index) {
          if (footer && index == visible.length) {
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
          final profile = visible[index];
          final isSelf = profile.id == currentUserId;
          return FollowUserRow(
            profile: profile,
            showFollowButton: !isSelf,
            isFollowing: social.isFollowing(profile.id),
            onOpenProfile: () => context.push('/user/${profile.id}'),
            onToggleFollow: () => _toggleFollow(profile.id),
          );
        },
      ),
    );
  }
}
