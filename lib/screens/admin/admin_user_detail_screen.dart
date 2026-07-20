import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/business_model.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../providers/admin_business_provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/helpers.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/user_avatar.dart';

class AdminUserDetailScreen extends StatefulWidget {
  const AdminUserDetailScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  UserModel? _user;
  bool _isLoading = true;
  bool _isActive = false;
  UserRole _selectedRole = UserRole.user;
  String? _selectedBusinessId;
  String? _error;

  static const _noBusinessValue = '__none__';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBusinessProvider>().startListening();
      _loadUser();
    });
  }

  Future<void> _loadUser() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final user =
        await context.read<AdminProvider>().getUserById(widget.userId);

    if (!mounted) {
      return;
    }

    setState(() {
      _user = user;
      _isActive = user?.isActive ?? false;
      _selectedRole = user?.role ?? UserRole.user;
      _selectedBusinessId = user?.businessId;
      _isLoading = false;
      _error = user == null ? 'Usuario no encontrado.' : null;
    });
  }

  Future<void> _handleToggleActive(bool value) async {
    final user = _user;
    if (user == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(value ? 'Activar cuenta' : 'Desactivar cuenta'),
          content: Text(
            value
                ? '¿Confirmas que ${user.displayName} podrá volver a usar SAINTS?'
                : '¿Confirmas que ${user.displayName} quedará sin acceso a la app?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final admin = context.read<AdminProvider>();
    final success = await admin.updateUserActive(user.id, value);

    if (!mounted) {
      return;
    }

    if (success) {
      setState(() {
        _isActive = value;
        _user = user.copyWith(isActive: value);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Cuenta activada.' : 'Cuenta desactivada.',
          ),
        ),
      );
    } else if (admin.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(admin.error!)),
      );
    }
  }

  Future<void> _saveChanges() async {
    final user = _user;
    if (user == null) {
      return;
    }

    final auth = context.read<AuthProvider>();
    final isSelf = user.id == auth.user?.id;
    final roleChanged = !isSelf && user.role != _selectedRole;
    final businessChanged = user.businessId != _selectedBusinessId;

    if (!roleChanged && !businessChanged) {
      return;
    }

    final admin = context.read<AdminProvider>();

    if (roleChanged) {
      final success = await admin.updateUserRole(
        user.id,
        _selectedRole,
        actingAdminId: auth.user?.id,
      );
      if (!mounted) {
        return;
      }
      if (!success) {
        if (admin.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(admin.error!)),
          );
        }
        return;
      }
    }

    if (businessChanged) {
      final success = await admin.updateBusinessAssignment(
        user.id,
        _selectedBusinessId,
      );
      if (!mounted) {
        return;
      }
      if (!success) {
        if (admin.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(admin.error!)),
          );
        }
        return;
      }
    }

    await _loadUser();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cambios guardados.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final admin = context.watch<AdminProvider>();
    final auth = context.watch<AuthProvider>();
    final businesses = context.watch<AdminBusinessProvider>().businesses;
    final dropdownValue = _selectedBusinessId ?? _noBusinessValue;
    final isSelf = _user != null && _user!.id == auth.user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de usuario'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: TextStyle(color: palette.textMuted),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: UserAvatar(
                            displayName: _user!.displayName,
                            photoUrl: _user!.photoUrl,
                            radius: 48,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          _user!.displayName,
                          textAlign: TextAlign.center,
                          style: AppTypography.sectionTitle(context),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _user!.email,
                          textAlign: TextAlign.center,
                          style: AppTypography.muted(context),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _DetailRow(
                          label: 'Estado',
                          value: _user!.isActive ? 'Activo' : 'Desactivado',
                        ),
                        _DetailRow(
                          label: 'Rol',
                          value: _user!.role.displayName,
                        ),
                        if (_user!.isBusinessOperator)
                          _DetailRow(
                            label: 'Operador',
                            value: 'Sí',
                          ),
                        if (_user!.businessId != null)
                          _DetailRow(
                            label: 'Negocio',
                            value: _businessName(
                              businesses,
                              _user!.businessId!,
                            ),
                          ),
                        _DetailRow(
                          label: 'Código QR',
                          value: _user!.qrCode,
                        ),
                        _DetailRow(
                          label: 'Registro',
                          value: Helpers.formatDate(_user!.createdAt),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Rol en la app',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (isSelf)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Text(
                              'No puedes cambiar tu propio rol.',
                              style: AppTypography.caption(context),
                            ),
                          ),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: UserRole.values.map((role) {
                            final isSelected = _selectedRole == role;
                            return ChoiceChip(
                              label: Text(role.displayName),
                              selected: isSelected,
                              onSelected: isSelf || admin.isUpdating
                                  ? null
                                  : (_) {
                                      setState(() => _selectedRole = role);
                                    },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Negocio asignado',
                          style: AppTypography.title(
                            context,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Asignar un negocio habilita escaneo QR. Si el usuario es "Usuario", se promueve a miembro automáticamente.',
                          style: AppTypography.caption(context),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        DropdownButtonFormField<String>(
                          value: dropdownValue,
                          decoration: const InputDecoration(
                            labelText: 'Operador de negocio',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: _noBusinessValue,
                              child: Text('Ninguno'),
                            ),
                            ...businesses.map(
                              (business) => DropdownMenuItem(
                                value: business.id,
                                child: Text(business.name),
                              ),
                            ),
                          ],
                          onChanged: admin.isUpdating
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedBusinessId =
                                        value == _noBusinessValue ? null : value;
                                  });
                                },
                        ),
                        if (businesses.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: Text(
                              'Primero crea un negocio desde el panel admin.',
                              style: TextStyle(color: palette.textMuted),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        FilledButton(
                          onPressed: admin.isUpdating ? null : _saveChanges,
                          child: const Text('Guardar cambios'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Cuenta activa',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Desactívala para bloquear el acceso a la app.',
                            style: TextStyle(color: palette.textMuted),
                          ),
                          value: _isActive,
                          onChanged: admin.isUpdating
                              ? null
                              : (value) => _handleToggleActive(value),
                        ),
                        if (admin.isUpdating) ...[
                          const SizedBox(height: AppSpacing.sm),
                          const Center(child: CircularProgressIndicator()),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  String _businessName(List<BusinessModel> businesses, String businessId) {
    for (final business in businesses) {
      if (business.id == businessId) {
        return business.name;
      }
    }
    return businessId;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                color: palette.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
