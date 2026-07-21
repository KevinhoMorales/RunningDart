import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/membership_modality.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_preferences_provider.dart';
import '../../services/auth_service.dart';
import '../../services/payment_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../utils/membership_helpers.dart';
import '../../utils/receipt_upload_helper.dart';
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
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _paymentService = PaymentService();
  final _picker = ImagePicker();

  MembershipModality _selectedModality = MembershipModality.official;
  DateTime? _birthDate;
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  XFile? _receiptFile;
  bool _isUploadingReceipt = false;

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _nationalIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(now.year - 90),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _pickReceipt() async {
    final file = await ReceiptUploadHelper.pickReceipt(context, _picker);
    if (file != null) {
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

    if (_selectedModality.requiresPayment && _receiptFile == null) {
      AppSnackBar.show(context, 'Adjunta el comprobante de pago.');
      return;
    }

    final auth = context.read<AuthProvider>();
    final profile = RegisterProfileData(
      displayName: _nameController.text.trim(),
      whatsapp: _whatsappFieldKey.currentState!.formatForStorage(),
      nationalIdLast4: _nationalIdController.text.trim(),
      birthDate: _birthDate!,
      modality: _selectedModality,
      acceptedTerms: _acceptedTerms,
    );

    final success = await auth.register(
      email: _emailController.text.trim(),
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
    final isBusy = auth.isLoading || _isUploadingReceipt;

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
                              InternationalPhoneField(
                                key: _whatsappFieldKey,
                                controller: _whatsappController,
                                labelText: 'WhatsApp',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              ModernTextField(
                                controller: _emailController,
                                labelText: 'Correo electrónico',
                                keyboardType: TextInputType.emailAddress,
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
                              ...MembershipModality.registrableOptions.map(
                                (modality) => RadioListTile<MembershipModality>(
                                  contentPadding: EdgeInsets.zero,
                                  value: modality,
                                  groupValue: _selectedModality,
                                  onChanged: isBusy
                                      ? null
                                      : AppHaptics.wrapValue((value) {
                                          if (value != null) {
                                            setState(
                                              () => _selectedModality = value,
                                            );
                                          }
                                        }),
                                  title: Text(modality.displayName),
                                  subtitle: Text(
                                    switch (modality) {
                                      MembershipModality.community =>
                                        'Gratis · entrenamientos recreativos Mar/Jue',
                                      MembershipModality.official =>
                                        '${AppConstants.officialMembershipPriceLabel} · vigencia 31-dic-2026',
                                      MembershipModality.proTeam =>
                                        'Incluye beneficios de miembro oficial + entrenamiento guiado',
                                    },
                                  ),
                                ),
                              ),
                              if (_selectedModality.requiresPayment) ...[
                                const SizedBox(height: AppSpacing.sm),
                                OutlinedButton.icon(
                                  onPressed: isBusy ? null : AppHaptics.wrap(_pickReceipt),
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
                                label: _selectedModality.requiresPayment
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
