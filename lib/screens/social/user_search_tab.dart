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

class UserSearchTab extends StatefulWidget {
  const UserSearchTab({super.key});

  @override
  State<UserSearchTab> createState() => _UserSearchTabState();
}

class _UserSearchTabState extends State<UserSearchTab> {
  final _searchController = TextEditingController();
  final _socialService = SocialService();

  List<PublicProfile> _results = const [];
  bool _isLoading = true;
  bool _hasError = false;
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
    });

    try {
      final profiles = await _socialService.searchProfiles(query);
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _results = profiles;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
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

    if (_results.isEmpty) {
      return const Center(
        child: EmptyStateCard(
          icon: Icons.search_off_rounded,
          message: 'Sin resultados',
          subtitle: 'Prueba con otro nombre o con su @usuario.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final profile = _results[index];
        final isSelf = profile.id == currentUserId;
        return FollowUserRow(
          profile: profile,
          showFollowButton: !isSelf,
          isFollowing: social.isFollowing(profile.id),
          onOpenProfile: () => context.push('/user/${profile.id}'),
          onToggleFollow: () => _toggleFollow(profile.id),
        );
      },
    );
  }
}
