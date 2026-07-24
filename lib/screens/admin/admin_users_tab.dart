import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/social_service.dart';
import '../../services/username_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/user_list_tile.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final _searchController = TextEditingController();
  final _socialService = SocialService();
  final _usernameService = UsernameService();
  bool _isSyncingProfiles = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadIfAdmin());
  }

  void _loadIfAdmin() {
    if (!mounted) {
      return;
    }

    final auth = context.read<AuthProvider>();
    if (auth.isAdmin) {
      context.read<AdminProvider>().startListening();
    } else {
      context.read<AdminProvider>().stopListening();
    }
  }

  Future<void> _handleRefresh() async {
    final auth = context.read<AuthProvider>();
    await auth.refreshAccountStatus();

    if (!mounted) {
      return;
    }

    if (!auth.isAdmin) {
      context.read<AdminProvider>().stopListening();
      return;
    }

    await context.read<AdminProvider>().refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _syncPublicProfiles() async {
    final users = context.read<AdminProvider>().users;
    if (users.isEmpty) {
      return;
    }

    setState(() => _isSyncingProfiles = true);
    try {
      final assigned = await _usernameService.assignMissingUsernames(users);
      final updated = [
        for (final user in users)
          assigned.containsKey(user.id)
              ? user.copyWith(username: assigned[user.id])
              : user,
      ];
      final total = await _socialService.backfillPublicProfiles(updated);
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        assigned.isEmpty
            ? '$total perfiles publicados en Comunidad.'
            : '$total perfiles publicados, '
                '${assigned.length} nombres de usuario asignados.',
      );
    } on SocialServiceException catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          'No se pudieron sincronizar los perfiles. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingProfiles = false);
      }
    }
  }

  Widget _refreshableScroll({
    required Widget child,
    required Future<void> Function() onRefresh,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: child,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final admin = context.watch<AdminProvider>();
    final palette = context.palette;

    if (!auth.isAdmin) {
      return _refreshableScroll(
        onRefresh: _handleRefresh,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'No tienes permiso para ver usuarios.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted),
            ),
          ),
        ),
      );
    }

    final users = admin.filteredUsers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: admin.setSearchQuery,
                  style: TextStyle(color: palette.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o correo',
                    hintStyle: TextStyle(color: palette.textMuted),
                    prefixIcon:
                        Icon(Icons.search_rounded, color: palette.textMuted),
                    filled: true,
                    fillColor: palette.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: BorderSide(color: palette.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: BorderSide(color: palette.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: BorderSide(color: palette.accentPrimary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _isSyncingProfiles
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : HapticIconButton(
                      onPressed: _syncPublicProfiles,
                      tooltip: 'Publicar perfiles en Comunidad',
                      icon: Icon(
                        Icons.sync_rounded,
                        color: palette.textMuted,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: palette.cardBackground,
                      ),
                    ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: AdminUserFilter.values.length,
            separatorBuilder: (context, _) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final filter = AdminUserFilter.values[index];
              return CategoryChip(
                label: filter.chipLabel,
                isSelected: admin.userFilter == filter,
                onSelected: () => admin.setUserFilter(filter),
              );
            },
          ),
        ),
        if (admin.userFilter != AdminUserFilter.all ||
            admin.searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Text(
              admin.searchQuery.isEmpty
                  ? admin.userFilter.label
                  : '${admin.filteredUsers.length} resultado(s)',
              style: AppTypography.caption(context, color: palette.textMuted),
            ),
          ),
        if (admin.isLoading && users.isEmpty)
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (admin.error != null && users.isEmpty)
          Expanded(
            child: _refreshableScroll(
              onRefresh: _handleRefresh,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        admin.error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      HapticFilledButton(
                        onPressed: admin.retry,
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.refresh_rounded),
                            const SizedBox(width: AppSpacing.sm),
                            const Text('Reintentar'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else if (users.isEmpty)
          Expanded(
            child: _refreshableScroll(
              onRefresh: _handleRefresh,
              child: Center(
                child: Text(
                  admin.searchQuery.isEmpty
                      ? admin.userFilter == AdminUserFilter.all
                          ? 'No hay usuarios registrados.'
                          : 'No hay usuarios para este filtro.'
                      : 'No se encontraron usuarios.',
                  style: TextStyle(color: palette.textMuted),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return UserListTile(
                    user: user,
                    onTap: () => context.push('/admin/users/${user.id}'),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
