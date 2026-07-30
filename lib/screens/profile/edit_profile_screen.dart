import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../utils/username_helpers.dart';
import '../../services/profile_photo_service.dart';
import '../../services/profile_service.dart';
import '../../services/social_service.dart';
import '../../services/username_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/international_phone_field.dart';
import '../../widgets/modern_text_field.dart';
import '../../widgets/user_avatar.dart';

const _bioMaxLength = 150;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _bioController = TextEditingController();
  final _whatsappFieldKey = GlobalKey<InternationalPhoneFieldState>();

  final _picker = ImagePicker();
  final _photoService = ProfilePhotoService();
  final _profileService = ProfileService();
  final _socialService = SocialService();
  final _usernameService = UsernameService();

  DateTime? _birthDate;
  XFile? _selectedPhoto;
  bool _isSaving = false;
  bool _initialized = false;
  String? _currentUsername;
  int _daysUntilUsernameChange = 0;
  int _bioLength = 0;

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
      _bioController.text = user.bio ?? '';
      _bioLength = _bioController.text.trim().length;
      _birthDate = user.birthDate;
      _currentUsername = user.username;
      _usernameController.text = user.username?.isNotEmpty == true
          ? user.username!
          : UsernameHelpers.suggestFromEmail(user.email);
      _daysUntilUsernameChange = (user.username?.isNotEmpty ?? false)
          ? UsernameHelpers.daysUntilChangeAllowed(user.usernameUpdatedAt)
          : 0;
    }
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _nationalIdController.dispose();
    _whatsappController.dispose();
    _bioController.dispose();
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
      var photoUrl = user.photoUrl;
      if (photo != null) {
        photoUrl = await _photoService.uploadProfilePhoto(user.id, photo) ??
            photoUrl;
      }

      final displayName = _nameController.text.trim();
      final bio = _bioController.text.trim();
      final username = UsernameHelpers.normalize(_usernameController.text);

      if (username != UsernameHelpers.normalize(_currentUsername ?? '')) {
        await _usernameService.changeUsername(
          userId: user.id,
          newUsername: username,
          currentUsername: _currentUsername,
          bypassCooldown: false,
          usernameUpdatedAt: user.usernameUpdatedAt,
        );
        _currentUsername = username;
      }

      await _profileService.updateProfile(
        userId: user.id,
        displayName: displayName,
        whatsapp: _whatsappFieldKey.currentState!.formatForStorage(),
        nationalIdLast4: _nationalIdController.text.trim(),
        birthDate: _birthDate!,
        bio: bio,
      );

      await _socialService.upsertPublicProfile(
        userId: user.id,
        displayName: displayName,
        photoUrl: photoUrl,
        bio: bio,
        username: username,
      );

      await auth.refreshAccountStatus();

      if (!mounted) {
        return;
      }
      AppSnackBar.show(context, 'Perfil actualizado.');
      context.pop();
    } on UsernameException catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, e.message);
      }
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
                    ModernTextField(
                      controller: _usernameController,
                      labelText: 'Nombre de usuario',
                      prefixText: '@',
                      prefixIcon: Icons.alternate_email_rounded,
                      textCapitalization: TextCapitalization.none,
                      enabled: !_isSaving && _daysUntilUsernameChange == 0,
                      inputFormatters: UsernameHelpers.inputFormatters,
                      validator: UsernameHelpers.validationError,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _UsernameHint(daysRemaining: _daysUntilUsernameChange),
                    const SizedBox(height: AppSpacing.md),
                    ModernTextField(
                      controller: _bioController,
                      labelText: 'Descripción',
                      // Sin capitalización automática: la descripción puede
                      // empezar en minúscula, con un @ o con un emoji.
                      textCapitalization: TextCapitalization.none,
                      prefixIcon: Icons.notes_rounded,
                      maxLines: 3,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(_bioMaxLength),
                      ],
                      onChanged: (value) =>
                          setState(() => _bioLength = value.trim().length),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _BioHint(length: _bioLength, maxLength: _bioMaxLength),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionLabel(text: 'Contacto (opcional)'),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Puedes dejarlos vacíos al registrarte y completarlos aquí después.',
                      style: AppTypography.muted(context),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    InternationalPhoneField(
                      key: _whatsappFieldKey,
                      controller: _whatsappController,
                      labelText: 'WhatsApp (opcional)',
                      initialStoredNumber: user.whatsapp,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ModernTextField(
                      controller: _nationalIdController,
                      labelText: 'Últimos 4 dígitos de cédula (opcional)',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.badge_outlined,
                      inputFormatters:
                          MembershipHelpers.nationalIdLast4InputFormatters,
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return null;
                        }
                        if (!MembershipHelpers
                            .isValidNationalIdLast4(trimmed)) {
                          return 'Ingresa 4 dígitos';
                        }
                        return null;
                      },
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

class _BioHint extends StatelessWidget {
  const _BioHint({required this.length, required this.maxLength});

  final int length;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: palette.textMuted,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Una línea sobre ti que verá toda la comunidad en tu perfil.',
              style: AppTypography.caption(context, color: palette.textMuted),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$length/$maxLength',
            style: AppTypography.caption(context, color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _UsernameHint extends StatelessWidget {
  const _UsernameHint({required this.daysRemaining});

  final int daysRemaining;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = daysRemaining > 0
        ? 'Podrás cambiarlo en $daysRemaining '
            '${daysRemaining == 1 ? 'día' : 'días'}.'
        : 'Debe ser único. Solo podrás cambiarlo cada '
            '${UsernameHelpers.cooldownDays} días.';

    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            daysRemaining > 0
                ? Icons.lock_clock_rounded
                : Icons.info_outline_rounded,
            size: 14,
            color: palette.textMuted,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: AppTypography.caption(context, color: palette.textMuted),
            ),
          ),
        ],
      ),
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
    final statusLabel = MembershipHelpers.credentialStatusLabel(
      status: user.membershipStatus,
      modality: user.membershipModality,
      isExpired: user.isMembershipExpired,
      hasCredential: user.hasMembershipPrivileges,
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
