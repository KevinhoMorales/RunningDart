import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../utils/helpers.dart';
import '../../utils/membership_helpers.dart';
import '../../services/profile_photo_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/international_phone_field.dart';
import '../../widgets/modern_text_field.dart';
import '../../widgets/user_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _whatsappFieldKey = GlobalKey<InternationalPhoneFieldState>();

  final _picker = ImagePicker();
  final _photoService = ProfilePhotoService();
  final _profileService = ProfileService();

  DateTime? _birthDate;
  XFile? _selectedPhoto;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _nameController.text = user.displayName;
      _nationalIdController.text = user.nationalIdLast4 ?? '';
      _birthDate = user.birthDate;
    }
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nationalIdController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 90),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _selectedPhoto = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_birthDate == null) {
      AppSnackBar.show(context, 'Selecciona tu fecha de nacimiento.');
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final photo = _selectedPhoto;
      if (photo != null) {
        await _photoService.uploadProfilePhoto(user.id, photo);
      }

      await _profileService.updateProfile(
        userId: user.id,
        displayName: _nameController.text.trim(),
        whatsapp: _whatsappFieldKey.currentState!.formatForStorage(),
        nationalIdLast4: _nationalIdController.text.trim(),
        birthDate: _birthDate!,
      );

      await auth.refreshAccountStatus();

      if (!mounted) {
        return;
      }
      AppSnackBar.show(context, 'Perfil actualizado.');
      context.pop();
    } on ProfilePhotoException catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, e.message);
      }
    } on ProfileUpdateException catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          'No se pudieron guardar los cambios. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: CustomAppBar(
        title: 'Editar perfil',
        leading: HapticIconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: user == null
          ? Center(
              child: Text(
                'No hay sesión activa',
                style: AppTypography.muted(context),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PhotoEditor(
                      displayName: user.displayName,
                      existingPhotoUrl: user.photoUrl,
                      selectedPhoto: _selectedPhoto,
                      onPickPhoto: _pickPhoto,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SectionLabel(text: 'Datos personales'),
                    const SizedBox(height: AppSpacing.md),
                    ModernTextField(
                      controller: _nameController,
                      labelText: 'Nombre completo',
                      textCapitalization: TextCapitalization.words,
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Ingresa tu nombre'
                              : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    InternationalPhoneField(
                      key: _whatsappFieldKey,
                      controller: _whatsappController,
                      labelText: 'WhatsApp',
                      initialStoredNumber: user.whatsapp,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ModernTextField(
                      controller: _nationalIdController,
                      labelText: 'Últimos 4 dígitos de cédula',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.badge_outlined,
                      inputFormatters:
                          MembershipHelpers.nationalIdLast4InputFormatters,
                      validator: (value) => value == null ||
                              !MembershipHelpers.isValidNationalIdLast4(value)
                          ? 'Ingresa 4 dígitos'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _BirthDateField(
                      birthDate: _birthDate,
                      onTap: _isSaving ? null : _pickBirthDate,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SectionLabel(text: 'Membresía'),
                    const SizedBox(height: AppSpacing.md),
                    _MembershipInfoCard(user: user),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: 'Guardar cambios',
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _PhotoEditor extends StatelessWidget {
  const _PhotoEditor({
    required this.displayName,
    required this.existingPhotoUrl,
    required this.selectedPhoto,
    required this.onPickPhoto,
  });

  final String displayName;
  final String? existingPhotoUrl;
  final XFile? selectedPhoto;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const radius = 52.0;

    final avatar = selectedPhoto != null
        ? CircleAvatar(
            radius: radius,
            backgroundColor: palette.iconButtonBackground,
            backgroundImage: FileImage(File(selectedPhoto!.path)),
          )
        : UserAvatar(
            displayName: displayName,
            photoUrl: existingPhotoUrl,
            radius: radius,
          );

    return Column(
      children: [
        GestureDetector(
          onTap: AppHaptics.wrap(onPickPhoto),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              avatar,
              Material(
                color: palette.accentPrimary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: AppHaptics.wrap(onPickPhoto),
                  enableFeedback: false,
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Toca para cambiar tu foto',
          style: AppTypography.caption(context, color: palette.textMuted),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.title(context, weight: FontWeight.w700),
    );
  }
}

class _BirthDateField extends StatelessWidget {
  const _BirthDateField({required this.birthDate, required this.onTap});

  final DateTime? birthDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.inputFill,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap == null ? null : AppHaptics.wrap(onTap),
        enableFeedback: false,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: palette.inputBorder),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 22,
                color: palette.textMuted,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fecha de nacimiento',
                      style: AppTypography.caption(
                        context,
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      birthDate == null
                          ? 'Selecciona una fecha'
                          : Helpers.formatDate(birthDate!),
                      style: AppTypography.body(context),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_rounded,
                size: 18,
                color: palette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembershipInfoCard extends StatelessWidget {
  const _MembershipInfoCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final statusLabel = MembershipHelpers.membershipStatusLabel(
      status: user.membershipStatus,
      isExpired: user.isMembershipExpired,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.mail_outline_rounded,
            label: 'Correo',
            value: user.email,
          ),
          _InfoRow(
            icon: Icons.workspace_premium_outlined,
            label: 'Modalidad',
            value: user.membershipModality.displayName,
          ),
          _InfoRow(
            icon: Icons.verified_outlined,
            label: 'Estado',
            value: statusLabel,
          ),
          if (user.expiresAt != null && !user.isAdmin)
            _InfoRow(
              icon: Icons.event_available_outlined,
              label: 'Vigencia',
              value: 'Hasta ${Helpers.formatDate(user.expiresAt!)}',
            ),
          _InfoRow(
            icon: Icons.qr_code_rounded,
            label: 'Código de miembro',
            value: user.qrCode,
            isLast: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: palette.textMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Estos datos los gestiona SAINTS. Escríbenos si necesitas cambiarlos.',
                  style: AppTypography.caption(context, color: palette.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: palette.accentPrimary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption(context, color: palette.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.body(context, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
