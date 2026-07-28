import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/membership_modality.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_preferences_provider.dart';
import '../../services/auth_service.dart';
import '../../services/payment_service.dart';
import '../../services/username_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../utils/membership_helpers.dart';
import '../../utils/receipt_upload_helper.dart';
import '../../utils/username_helpers.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/legal_links.dart';
import '../../widgets/international_phone_field.dart';
import '../../widgets/modern_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _whatsappFieldKey = GlobalKey<InternationalPhoneFieldState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _paymentService = PaymentService();
  final _usernameService = UsernameService();
  final _picker = ImagePicker();

  MembershipModality _selectedModality = MembershipModality.official;
  DateTime? _birthDate;
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  XFile? _receiptFile;
  bool _isUploadingReceipt = false;
  bool _isCheckingUsername = false;
  bool _usernameTouched = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _nationalIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Propone el username mientras se escribe el correo, hasta que la persona
  /// decida escribirlo ella misma.
  void _suggestUsernameFromEmail(String value) {
    if (_usernameTouched) {
      return;
    }
    final email = value.trim();
    if (!Helpers.isValidEmail(email)) {
      return;
    }
    final suggestion = UsernameHelpers.suggestFromEmail(email);
    if (suggestion != _usernameController.text) {
      _usernameController.text = suggestion;
    }
  }

  void _markUsernameTouched(String _) {
    if (!_usernameTouched) {
      setState(() => _usernameTouched = true);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(now.year - 90),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _pickReceipt() async {
    final file = await ReceiptUploadHelper.pickReceipt(context, _picker);
    if (file != null && mounted) {
      setState(() => _receiptFile = file);
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_birthDate == null) {
      AppSnackBar.show(
        context,
        'Selecciona tu fecha de nacimiento.',
      );
      return;
    }

    if (!_acceptedTerms) {
      AppSnackBar.show(
        context,
        'Debes aceptar los términos y condiciones y la política de privacidad.',
      );
      return;
    }

    // Pro Team se puede pagar con In-App Purchase tras el registro; Oficial
    // sigue requiriendo comprobante de transferencia.
    final needsReceipt =
        _selectedModality.requiresPayment &&
        _selectedModality != MembershipModality.proTeam;
    if (needsReceipt && _receiptFile == null) {
      AppSnackBar.show(context, 'Adjunta el comprobante de pago.');
      return;
    }

    final email = _emailController.text.trim();
    var username = UsernameHelpers.normalize(_usernameController.text);
    setState(() => _isCheckingUsername = true);
    try {
      if (!await _usernameService.isAvailable(username)) {
        if (_usernameTouched) {
          if (!mounted) {
            return;
          }
          setState(() => _isCheckingUsername = false);
          AppSnackBar.showError(
            context,
            'Ese nombre de usuario ya está tomado.',
          );
          return;
        }
        // Lo propuso la app, así que se corre al siguiente libre en silencio.
        username = await _usernameService.suggestAvailableFromEmail(email);
        _usernameController.text = username;
      }
    } on UsernameException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isCheckingUsername = false);
      AppSnackBar.showError(context, e.message);
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() => _isCheckingUsername = false);

    final auth = context.read<AuthProvider>();
    final profile = RegisterProfileData(
      displayName: _nameController.text.trim(),
      username: username,
      whatsapp: _whatsappFieldKey.currentState!.formatForStorage(),
      nationalIdLast4: _nationalIdController.text.trim(),
      birthDate: _birthDate!,
      modality: _selectedModality,
      acceptedTerms: _acceptedTerms,
    );

    final success = await auth.register(
      email: email,
      password: _passwordController.text,
      profile: profile,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      if (auth.error != null) {
        AppSnackBar.showError(context, auth.error);
      }
      return;
    }

    if (_selectedModality.requiresPayment && _receiptFile != null) {
      await _uploadReceipt(auth.user!.id);
    }

    if (!mounted) {
      return;
    }

    final notificationPreferences =
        context.read<NotificationPreferencesProvider?>();
    if (notificationPreferences != null) {
      await notificationPreferences.markOnboardingPending();
    }

    if (!mounted) {
      return;
    }

    if (notificationPreferences != null) {
      context.go('/onboarding/notifications');
      return;
    }

    context.go(auth.postAuthRoute);
  }

  Future<void> _uploadReceipt(String userId) async {
    setState(() => _isUploadingReceipt = true);
    try {
      await ReceiptUploadHelper.submitReceipt(
        paymentService: _paymentService,
        userId: userId,
        modality: _selectedModality,
        receiptFile: _receiptFile!,
      );
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          'Cuenta creada, pero no se pudo subir el comprobante. Contacta a SAINTS.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingReceipt = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final palette = context.palette;
    final isBusy =
        auth.isLoading || _isUploadingReceipt || _isCheckingUsername;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    HapticIconButton(
                      onPressed: isBusy ? null : () => context.go('/login'),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: palette.iconButtonBackground,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Únete a SAINTS',
                          style: AppTypography.sectionTitle(context),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          AppConstants.appTagline,
                          style: AppTypography.muted(context),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ModernTextField(
                                controller: _nameController,
                                labelText: 'Nombre completo',
                                textCapitalization: TextCapitalization.words,
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Ingresa tu nombre'
                                        : null,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              ModernTextField(
                                controller: _emailController,
                                labelText: 'Correo electrónico',
                                keyboardType: TextInputType.emailAddress,
                                onChanged: _suggestUsernameFromEmail,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Ingresa tu correo';
                                  }
                                  if (!Helpers.isValidEmail(value.trim())) {
                                    return 'Ingresa un correo válido';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.md),
                              ModernTextField(
                                controller: _usernameController,
                                labelText: 'Nombre de usuario',
                                prefixText: '@',
                                inputFormatters:
                                    UsernameHelpers.inputFormatters,
                                onChanged: _markUsernameTouched,
                                validator: UsernameHelpers.validationError,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              _UsernameHint(isAutomatic: !_usernameTouched),
                              const SizedBox(height: AppSpacing.md),
                              InternationalPhoneField(
                                key: _whatsappFieldKey,
                                controller: _whatsappController,
                                labelText: 'WhatsApp',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              ModernTextField(
                                controller: _nationalIdController,
                                labelText: 'Últimos 4 dígitos de cédula',
                                keyboardType: TextInputType.number,
                                inputFormatters:
                                    MembershipHelpers.nationalIdLast4InputFormatters,
                                validator: (value) =>
                                    value == null ||
                                            !MembershipHelpers
                                                .isValidNationalIdLast4(value)
                                        ? 'Ingresa 4 dígitos'
                                        : null,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              OutlinedButton.icon(
                                onPressed: isBusy ? null : AppHaptics.wrap(_pickBirthDate),
                                icon: const Icon(Icons.calendar_today_rounded),
                                label: Text(
                                  _birthDate == null
                                      ? 'Fecha de nacimiento'
                                      : Helpers.formatDate(_birthDate!),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                'Modalidad',
                                style: AppTypography.title(context),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              RadioGroup<MembershipModality>(
                                groupValue: _selectedModality,
                                onChanged: (value) {
                                  AppHaptics.lightTap();
                                  if (value != null) {
                                    setState(() => _selectedModality = value);
                                  }
                                },
                                child: Column(
                                  children: [
                                    for (final modality
                                        in MembershipModality.registrableOptions)
                                      RadioListTile<MembershipModality>(
                                        contentPadding: EdgeInsets.zero,
                                        value: modality,
                                        enabled: !isBusy,
                                        title: Text(modality.displayName),
                                        subtitle: Text(
                                          switch (modality) {
                                            MembershipModality.community =>
                                              'Gratis · entrenamientos recreativos Mar/Jue',
                                            MembershipModality.official =>
                                              '${AppConstants.officialMembershipPriceLabel} · vigencia 31-dic-2026',
                                            MembershipModality.proTeam =>
                                              'Suscripción mensual in-app · beneficios oficiales + entrenamiento guiado',
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (_selectedModality ==
                                  MembershipModality.proTeam) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Después de crear tu cuenta podrás activar '
                                  'Pro Team con App Store / Google Play, o '
                                  'adjuntar un comprobante de transferencia.',
                                  style: AppTypography.caption(context)
                                      .copyWith(height: 1.4),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                OutlinedButton.icon(
                                  onPressed: isBusy
                                      ? null
                                      : AppHaptics.wrap(_pickReceipt),
                                  icon: const Icon(Icons.receipt_long_rounded),
                                  label: Text(
                                    _receiptFile == null
                                        ? 'Adjuntar comprobante (opcional)'
                                        : 'Comprobante seleccionado',
                                  ),
                                ),
                              ] else if (_selectedModality.requiresPayment) ...[
                                const SizedBox(height: AppSpacing.sm),
                                OutlinedButton.icon(
                                  onPressed: isBusy
                                      ? null
                                      : AppHaptics.wrap(_pickReceipt),
                                  icon: const Icon(Icons.receipt_long_rounded),
                                  label: Text(
                                    _receiptFile == null
                                        ? 'Adjuntar comprobante de pago'
                                        : 'Comprobante seleccionado',
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.md),
                              ModernTextField(
                                controller: _passwordController,
                                labelText: 'Contraseña',
                                obscureText: _obscurePassword,
                                prefixIcon: Icons.lock_outline,
                                suffixIcon: HapticIconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: palette.textMuted,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Ingresa una contraseña';
                                  }
                                  if (value.length <
                                      AppConstants.minPasswordLength) {
                                    return 'Mínimo ${AppConstants.minPasswordLength} caracteres';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.md),
                              ModernTextField(
                                controller: _confirmPasswordController,
                                labelText: 'Confirmar contraseña',
                                obscureText: _obscureConfirm,
                                prefixIcon: Icons.lock_outline,
                                suffixIcon: HapticIconButton(
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: palette.textMuted,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirm = !_obscureConfirm;
                                    });
                                  },
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Confirma tu contraseña';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Las contraseñas no coinciden';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.md),
                              LegalAcceptanceField(
                                value: _acceptedTerms,
                                enabled: !isBusy,
                                onChanged: (accepted) {
                                  setState(() => _acceptedTerms = accepted);
                                },
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              PrimaryButton(
                                label: _selectedModality ==
                                        MembershipModality.proTeam
                                    ? 'Crear cuenta y continuar'
                                    : _selectedModality.requiresPayment
                                        ? 'Enviar solicitud'
                                        : 'Crear cuenta',
                                isLoading: isBusy,
                                onPressed: _handleRegister,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsernameHint extends StatelessWidget {
  const _UsernameHint({required this.isAutomatic});

  final bool isAutomatic;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: Text(
        isAutomatic
            ? 'Lo generamos desde tu correo. Puedes cambiarlo si prefieres otro.'
            : 'Así te encontrarán en la comunidad.',
        style: AppTypography.caption(context, color: palette.textMuted),
      ),
    );
  }
}
