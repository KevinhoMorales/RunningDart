import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/membership_modality.dart';
import '../../models/membership_status.dart';
import '../../models/payment_model.dart';
import '../../models/business_model.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../providers/admin_business_provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../utils/helpers.dart';
import '../../utils/membership_helpers.dart';
import '../../services/payment_service.dart';
import '../../services/social_service.dart';
import '../../services/username_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/international_phone_field.dart';
import '../../widgets/manual_payment_dialog.dart';
import '../../widgets/modality_chip.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/receipt_viewer.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/username_dialog.dart';

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
  MembershipModality _selectedModality = MembershipModality.community;
  MembershipStatus _selectedMembershipStatus = MembershipStatus.active;
  String? _selectedBusinessId;
  String? _error;
  DateTime? _expiresAt;
  final _whatsappFieldKey = GlobalKey<InternationalPhoneFieldState>();
  final _whatsappController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _internalNotesController = TextEditingController();
  final _paymentService = PaymentService();
  final _usernameService = UsernameService();
  final _socialService = SocialService();
  String? _initialWhatsapp;
  bool _isChangingUsername = false;

  static const _noBusinessValue = '__none__';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBusinessProvider>().startListening();
      _loadUser();
    });
  }

  @override
  void dispose() {
    _whatsappController.dispose();
    _nationalIdController.dispose();
    _internalNotesController.dispose();
    super.dispose();
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
      _selectedModality = user?.membershipModality ?? MembershipModality.community;
      _selectedMembershipStatus =
          user?.membershipStatus ?? MembershipStatus.active;
      _expiresAt = user?.expiresAt ??
          (user?.membershipModality.requiresPayment == true
              ? MembershipHelpers.defaultOfficialExpiry()
              : null);
      _selectedBusinessId = user?.businessId;
      _initialWhatsapp = user?.whatsapp;
      _nationalIdController.text = user?.nationalIdLast4 ?? '';
      _internalNotesController.text = user?.internalNotes ?? '';
      _isLoading = false;
      _error = user == null ? 'Usuario no encontrado.' : null;
    });
  }

  Future<void> _changeUsername() async {
    final user = _user;
    if (user == null || _isChangingUsername) {
      return;
    }

    // El aviso se marca antes de abrir el diálogo: así dos toques seguidos no
    // apilan dos diálogos sobre el mismo usuario.
    setState(() => _isChangingUsername = true);
    try {
      final newUsername = await askNewUsername(
        context,
        currentUsername: user.username,
        helperText: 'Como admin no aplica la espera de 30 días.',
      );

      if (newUsername == null || !mounted) {
        return;
      }

      await _usernameService.changeUsername(
        userId: user.id,
        newUsername: newUsername,
        currentUsername: user.username,
        bypassCooldown: true,
      );
      // changeUsername solo escribe los campos del username. Si el perfil
      // público aún no existía quedaría sin nombre, así que se completa aquí.
      await _socialService.upsertPublicProfile(
        userId: user.id,
        displayName: user.displayName,
        photoUrl: user.photoUrl,
        bio: user.bio,
        username: newUsername,
      );
      if (!mounted) {
        return;
      }
      await _loadUser();
      if (!mounted) {
        return;
      }
      AppSnackBar.show(context, 'Nombre de usuario actualizado.');
    } on UsernameException catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isChangingUsername = false);
      }
    }
  }

  Future<void> _approveMembership() async {
    final admin = context.read<AdminProvider>();
    final success = await admin.approveMembership(widget.userId);
    if (!mounted) {
      return;
    }
    if (success) {
      await _loadUser();
      if (!mounted) {
        return;
      }
      AppSnackBar.show(context, 'Membresía aprobada.');
    } else if (admin.error != null) {
      AppSnackBar.showError(context, admin.error);
    }
  }

  Future<void> _rejectMembership() async {
    final admin = context.read<AdminProvider>();
    final success = await admin.rejectMembership(widget.userId);
    if (!mounted) {
      return;
    }
    if (success) {
      await _loadUser();
      if (!mounted) {
        return;
      }
      AppSnackBar.show(context, 'Solicitud rechazada.');
    } else if (admin.error != null) {
      AppSnackBar.showError(context, admin.error);
    }
  }

  Future<void> _saveMembership() async {
    final admin = context.read<AdminProvider>();
    final success = await admin.updateMembershipProfile(
      userId: widget.userId,
      modality: _selectedModality,
      status: _selectedMembershipStatus,
      expiresAt: _expiresAt,
      whatsapp: _formatWhatsappForSave(),
      nationalIdLast4: _nationalIdController.text.trim(),
      internalNotes: _internalNotesController.text.trim(),
    );
    if (!mounted) {
      return;
    }
    if (success) {
      await _loadUser();
      if (!mounted) {
        return;
      }
      AppSnackBar.show(context, 'Membresía actualizada.');
    } else if (admin.error != null) {
      AppSnackBar.showError(context, admin.error);
    }
  }

  String? _formatWhatsappForSave() {
    final local = _whatsappController.text.trim();
    if (local.isEmpty) {
      return null;
    }
    return _whatsappFieldKey.currentState?.formatForStorage() ??
        MembershipHelpers.formatWhatsappForStorage(local);
  }

  Future<void> _registerManualPayment() async {
    final draft = await askManualPayment(
      context,
      initialModality: _selectedModality,
    );

    if (draft == null || !mounted) {
      return;
    }

    try {
      await _paymentService.createPayment(
        PaymentModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: widget.userId,
          modality: draft.modality,
          amount: draft.amount,
          paidAt: DateTime.now(),
          status: PaymentStatus.approved,
          notes: draft.notes,
          createdAt: DateTime.now(),
        ),
      );
      if (!mounted) {
        return;
      }
      AppSnackBar.show(context, 'Pago registrado.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(context, 'No se pudo registrar el pago.');
    }
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? MembershipHelpers.defaultOfficialExpiry(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null && mounted) {
      setState(() => _expiresAt = picked);
    }
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
            HapticTextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            HapticFilledButton(
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
      AppSnackBar.show(
        context,
        value ? 'Cuenta activada.' : 'Cuenta desactivada.',
      );
    } else if (admin.error != null) {
      AppSnackBar.showError(context, admin.error);
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
          AppSnackBar.showError(context, admin.error);
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
          AppSnackBar.showError(context, admin.error);
        }
        return;
      }
    }

    await _loadUser();

    if (!mounted) {
      return;
    }

    AppSnackBar.show(context, 'Cambios guardados.');
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
      backgroundColor: palette.scaffoldBackground,
      appBar: const CustomAppBar(title: 'Detalle de usuario'),
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
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _UserIdentityHeader(user: _user!),
                      const SizedBox(height: AppSpacing.md),
                      _AdminSectionCard(
                        title: 'Resumen',
                        child: Column(
                          children: [
                            _DetailRow(
                              label: 'Estado cuenta',
                              value: _user!.isActive ? 'Activo' : 'Desactivado',
                            ),
                            _DetailRow(
                              label: 'Rol',
                              value: _user!.role.displayName,
                            ),
                            if (_user!.whatsapp != null)
                              _DetailRow(
                                label: 'WhatsApp',
                                value: _user!.whatsapp!,
                              ),
                            if (_user!.nationalIdLast4 != null)
                              _DetailRow(
                                label: 'Cédula',
                                value: '**** ${_user!.nationalIdLast4}',
                              ),
                            if (_user!.isBusinessOperator)
                              const _DetailRow(
                                label: 'Operador',
                                value: 'Marca aliada',
                              ),
                            if (_user!.businessId != null)
                              _DetailRow(
                                label: 'Marca',
                                value: _businessName(
                                  businesses,
                                  _user!.businessId!,
                                ),
                              ),
                            _DetailRow(
                              label: 'Código QR',
                              value: _user!.qrCode,
                              monospace: true,
                            ),
                            _DetailRow(
                              label: 'Registro',
                              value: Helpers.formatDate(_user!.createdAt),
                            ),
                            _DetailRow(
                              label: 'Usuario',
                              value: _user!.username == null
                                  ? 'Sin asignar'
                                  : '@${_user!.username}',
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: HapticTextButtonIcon(
                                onPressed: _isChangingUsername
                                    ? null
                                    : _changeUsername,
                                icon: const Icon(
                                  Icons.alternate_email_rounded,
                                  size: 16,
                                ),
                                label: const Text('Cambiar nombre de usuario'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_user!.membershipStatus ==
                          MembershipStatus.pending) ...[
                        const SizedBox(height: AppSpacing.md),
                        _PendingMembershipBanner(
                          isUpdating: admin.isUpdating,
                          onApprove: _approveMembership,
                          onReject: _rejectMembership,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      _AdminSectionCard(
                        title: 'Gestión de membresía',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<MembershipModality>(
                              initialValue: _selectedModality,
                              decoration: const InputDecoration(
                                labelText: 'Modalidad',
                              ),
                              items: MembershipModality.values
                                  .map(
                                    (modality) => DropdownMenuItem(
                                      value: modality,
                                      child: Text(modality.displayName),
                                    ),
                                  )
                                  .toList(),
                              onChanged: admin.isUpdating
                                  ? null
                                  : AppHaptics.wrapValue((value) {
                                      if (value != null) {
                                        setState(
                                          () => _selectedModality = value,
                                        );
                                      }
                                    }),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            DropdownButtonFormField<MembershipStatus>(
                              initialValue: _selectedMembershipStatus,
                              decoration: const InputDecoration(
                                labelText: 'Estado de membresía',
                              ),
                              items: MembershipStatus.values
                                  .map(
                                    (status) => DropdownMenuItem(
                                      value: status,
                                      child: Text(status.displayName),
                                    ),
                                  )
                                  .toList(),
                              onChanged: admin.isUpdating
                                  ? null
                                  : AppHaptics.wrapValue((value) {
                                      if (value != null) {
                                        setState(
                                          () => _selectedMembershipStatus =
                                              value,
                                        );
                                      }
                                    }),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            OutlinedButton.icon(
                              onPressed: admin.isUpdating
                                  ? null
                                  : AppHaptics.wrap(_pickExpiryDate),
                              icon: const Icon(Icons.event_rounded),
                              label: Text(
                                _expiresAt == null
                                    ? 'Vigencia'
                                    : 'Vigencia: ${Helpers.formatDate(_expiresAt!)}',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            InternationalPhoneField(
                              key: _whatsappFieldKey,
                              controller: _whatsappController,
                              labelText: 'WhatsApp',
                              initialStoredNumber: _initialWhatsapp,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              controller: _nationalIdController,
                              keyboardType: TextInputType.number,
                              inputFormatters:
                                  MembershipHelpers.nationalIdLast4InputFormatters,
                              decoration: const InputDecoration(
                                labelText: 'Últimos 4 dígitos cédula',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              controller: _internalNotesController,
                              decoration: const InputDecoration(
                                labelText: 'Observaciones internas',
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            HapticFilledButton(
                              onPressed:
                                  admin.isUpdating ? null : _saveMembership,
                              child: const Text('Guardar membresía'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _AdminSectionCard(
                        title: 'Pagos registrados',
                        child: StreamBuilder<List<PaymentModel>>(
                          stream: _paymentService.watchPaymentsForUser(
                            widget.userId,
                          ),
                          builder: (context, snapshot) {
                            final payments = snapshot.data ?? [];
                            if (payments.isEmpty) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sin pagos registrados.',
                                    style: AppTypography.muted(context),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  OutlinedButton.icon(
                                    onPressed: admin.isUpdating
                                        ? null
                                        : AppHaptics.wrap(_registerManualPayment),
                                    icon: const Icon(Icons.add_rounded),
                                    label:
                                        const Text('Registrar pago manual'),
                                  ),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                ...payments.map(
                                  (payment) => _PaymentListItem(
                                    payment: payment,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton.icon(
                                    onPressed: admin.isUpdating
                                        ? null
                                        : AppHaptics.wrap(_registerManualPayment),
                                    icon: const Icon(Icons.add_rounded),
                                    label:
                                        const Text('Registrar pago manual'),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _AdminSectionCard(
                        title: 'Rol y acceso',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                                      : AppHaptics.wrapValue((_) {
                                          setState(
                                            () => _selectedRole = role,
                                          );
                                        }),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'Marca aliada asignada',
                              style: AppTypography.title(context),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Asignar una marca habilita el escaneo QR. Si el usuario es "Usuario", pasa a miembro automáticamente.',
                              style: AppTypography.caption(context),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            DropdownButtonFormField<String>(
                              initialValue: dropdownValue,
                              decoration: const InputDecoration(
                                labelText: 'Operador de marca aliada',
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
                                  : AppHaptics.wrapValue((value) {
                                      setState(() {
                                        _selectedBusinessId =
                                            value == _noBusinessValue
                                                ? null
                                                : value;
                                      });
                                    }),
                            ),
                            if (businesses.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.sm,
                                ),
                                child: Text(
                                  'Primero crea una marca aliada desde el panel admin.',
                                  style: TextStyle(color: palette.textMuted),
                                ),
                              ),
                            const SizedBox(height: AppSpacing.md),
                            HapticFilledButton(
                              onPressed:
                                  admin.isUpdating ? null : _saveChanges,
                              child: const Text('Guardar cambios'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _AdminSectionCard(
                        title: 'Estado de cuenta',
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Cuenta activa',
                            style: AppTypography.title(context),
                          ),
                          subtitle: Text(
                            'Desactívala para bloquear el acceso a la app.',
                            style: AppTypography.caption(context),
                          ),
                          value: _isActive,
                          onChanged: admin.isUpdating
                              ? null
                              : AppHaptics.wrapValue(_handleToggleActive),
                        ),
                      ),
                      if (admin.isUpdating) ...[
                        const SizedBox(height: AppSpacing.md),
                        const Center(child: CircularProgressIndicator()),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                    ],
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

class _UserIdentityHeader extends StatelessWidget {
  const _UserIdentityHeader({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        UserAvatar(
          displayName: user.displayName,
          photoUrl: user.photoUrl,
          radius: 36,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                style: AppTypography.sectionTitle(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                user.email,
                style: AppTypography.body(context, color: palette.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  StatusBadge(
                    status: user.membershipStatus,
                    isExpired: user.isMembershipExpired,
                  ),
                  ModalityChip(
                    modality: user.membershipModality,
                    compact: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminSectionCard extends StatelessWidget {
  const _AdminSectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: palette.cardBorder),
        boxShadow: palette.elevatedCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTypography.title(context)),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _PendingMembershipBanner extends StatelessWidget {
  const _PendingMembershipBanner({
    required this.isUpdating,
    required this.onApprove,
    required this.onReject,
  });

  final bool isUpdating;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.infoBannerBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: palette.infoBannerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.hourglass_top_rounded,
                color: palette.accentPrimary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Solicitud pendiente de aprobación',
                  style: AppTypography.title(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Revisa los datos y el comprobante antes de aprobar la membresía.',
            style: AppTypography.muted(context).copyWith(height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: HapticFilledButton(
                  onPressed: isUpdating ? null : onApprove,
                  child: const Text('Aprobar'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: isUpdating ? null : AppHaptics.wrap(onReject),
                  child: const Text('Rechazar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentListItem extends StatelessWidget {
  const _PaymentListItem({required this.payment});

  final PaymentModel payment;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.scaffoldBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: palette.accentPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              Icons.payments_outlined,
              size: 18,
              color: palette.accentPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${payment.modality.displayName} · \$${payment.amount.toStringAsFixed(0)}',
                  style: AppTypography.title(context),
                ),
                Text(
                  '${payment.status.displayName} · ${Helpers.formatDate(payment.paidAt)}',
                  style: AppTypography.caption(context),
                ),
                if (payment.receiptUrl != null &&
                    payment.receiptUrl!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  HapticTextButtonIcon(
                    onPressed: () =>
                        ReceiptViewer.show(context, payment.receiptUrl!),
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: const Text('Ver comprobante'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: palette.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: monospace ? 2 : null,
              overflow: monospace ? TextOverflow.ellipsis : null,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w500,
                fontFamily: monospace ? 'monospace' : null,
                fontSize: monospace ? 12 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
