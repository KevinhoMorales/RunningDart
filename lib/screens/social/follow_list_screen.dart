import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
  bool _isLoading = true;
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
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = _profiles.isEmpty;
      _error = null;
    });
    try {
      final ids = widget.mode == FollowListMode.followers
          ? await _socialService.getFollowerIds(widget.userId)
          : await _socialService.getFollowingIds(widget.userId);
      final profiles = await _socialService.getPublicProfilesByIds(ids);
      if (!mounted) {
        return;
      }
      setState(() {
        _profiles = profiles;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'No se pudo cargar la lista.';
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
          : RefreshIndicator(
              onRefresh: _load,
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
                              onAction: _load,
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
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          itemCount: _profiles.length,
                          itemBuilder: (context, index) {
                            final profile = _profiles[index];
                            final isSelf = profile.id == currentUserId;
                            return FollowUserRow(
                              profile: profile,
                              showFollowButton: !isSelf,
                              isFollowing: social.isFollowing(profile.id),
                              onOpenProfile: () =>
                                  context.push('/user/${profile.id}'),
                              onToggleFollow: () => _toggleFollow(profile.id),
                            );
                          },
                        ),
            ),
    );
  }
}
