import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/public_profile.dart';
import '../../providers/social_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/user_avatar.dart';

/// Único sitio desde el que se puede deshacer un bloqueo sin tener que volver a
/// encontrar el perfil de la persona bloqueada, que precisamente está oculto.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<PublicProfile> _profiles = const [];
  bool _isLoading = true;
  bool _hasError = false;
  final _unblocking = <String>{};

  /// Los ids con los que se resolvieron los perfiles en pantalla, para saber si
  /// el stream de bloqueos trajo algo nuevo y hay que volver a resolverlos.
  Set<String> _loadedIds = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final social = context.read<SocialProvider>();
    final ids = Set<String>.from(social.blockedIds);

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final profiles = await social.blockedProfiles();
      if (!mounted) {
        return;
      }
      setState(() {
        _profiles = profiles;
        _loadedIds = ids;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _unblock(PublicProfile profile) async {
    if (_unblocking.contains(profile.id)) {
      return;
    }

    setState(() => _unblocking.add(profile.id));
    try {
      await context.read<SocialProvider>().unblockUser(profile.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _profiles = _profiles
            .where((item) => item.id != profile.id)
            .toList(growable: false);
        _loadedIds = _loadedIds.difference({profile.id});
      });
      AppSnackBar.show(context, 'Usuario desbloqueado.');
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, 'No se pudo desbloquear. Intenta de nuevo.');
      }
    } finally {
      if (mounted) {
        setState(() => _unblocking.remove(profile.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final social = context.watch<SocialProvider>();

    // Si bloquearon a alguien más desde otro dispositivo, el stream lo trae y
    // hay que resolver su perfil.
    if (!_isLoading && social.blockedIds.difference(_loadedIds).isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _load();
        }
      });
    }

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: const CustomAppBar(title: 'Cuentas bloqueadas'),
      body: _buildBody(social),
    );
  }

  Widget _buildBody(SocialProvider social) {
    if (_isLoading) {
      return const LoadingSkeleton();
    }

    if (_hasError || social.blockedError != null) {
      return Center(
        child: EmptyStateCard(
          icon: Icons.cloud_off_rounded,
          message: 'No pudimos cargar tus bloqueos',
          subtitle: 'Revisa tu conexión e intenta de nuevo.',
          actionLabel: 'Reintentar',
          onAction: _load,
        ),
      );
    }

    if (_profiles.isEmpty) {
      return const Center(
        child: EmptyStateCard(
          icon: Icons.block_rounded,
          message: 'No has bloqueado a nadie',
          subtitle:
              'Cuando bloquees a alguien, aparecerá aquí para que puedas deshacerlo.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      itemCount: _profiles.length,
      itemBuilder: (context, index) {
        final profile = _profiles[index];
        return _BlockedUserRow(
          profile: profile,
          isUnblocking: _unblocking.contains(profile.id),
          onUnblock: () => _unblock(profile),
        );
      },
    );
  }
}

class _BlockedUserRow extends StatelessWidget {
  const _BlockedUserRow({
    required this.profile,
    required this.isUnblocking,
    required this.onUnblock,
  });

  final PublicProfile profile;
  final bool isUnblocking;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final name = profile.displayName.trim().isEmpty
        ? 'Miembro SAINTS'
        : profile.displayName.trim();
    final username = profile.username?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Row(
          children: [
            UserAvatar(
              displayName: name,
              photoUrl: profile.photoUrl,
              radius: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.title(context),
                  ),
                  if (username.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(
                        context,
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
              onPressed: isUnblocking ? null : AppHaptics.wrap(onUnblock),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
              ),
              child: const Text('Desbloquear'),
            ),
          ],
        ),
      ),
    );
  }
}
