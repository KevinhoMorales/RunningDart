import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/notification_preferences_provider.dart';
import '../../services/auth_service.dart';
import '../../services/username_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../utils/membership_helpers.dart';
import '../../utils/username_helpers.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/legal_links.dart';
import '../../widgets/international_phone_field.dart';
import '../../widgets/modern_text_field.dart';

enum _UsernameAvailability {
  idle,
  checking,
  available,
  taken,
  invalid,
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _usernameCheckDelay = Duration(milliseconds: 400);
  static const _takenColor = Color(0xFFDC2626);
  static const _invalidColor = Color(0xFFD97706);

  final _formKey = GlobalKey<FormState>();
  final _whatsappFieldKey = GlobalKey<InternationalPhoneFieldState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameService = UsernameService();

  DateTime? _birthDate;
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isCheckingUsername = false;
  bool _usernameTouched = false;
  _UsernameAvailability _usernameAvailability = _UsernameAvailability.idle;
  Timer? _usernameCheckTimer;
  int _usernameCheckGeneration = 0;

  @override
  void dispose() {
    _usernameCheckTimer?.cancel();
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
    _scheduleUsernameAvailabilityCheck(suggestion);
  }

  void _onUsernameChanged(String value) {
    if (!_usernameTouched) {
      setState(() => _usernameTouched = true);
    }
    _scheduleUsernameAvailabilityCheck(value);
  }

  void _scheduleUsernameAvailabilityCheck(String value) {
    _usernameCheckTimer?.cancel();
    final normalized = UsernameHelpers.normalize(value);
    if (normalized.isEmpty) {
      setState(() => _usernameAvailability = _UsernameAvailability.idle);
      return;
    }
    if (!UsernameHelpers.isValid(normalized)) {
      setState(() => _usernameAvailability = _UsernameAvailability.invalid);
      return;
    }

    setState(() => _usernameAvailability = _UsernameAvailability.checking);
    final generation = ++_usernameCheckGeneration;
    _usernameCheckTimer = Timer(_usernameCheckDelay, () {
      unawaited(_checkUsernameAvailability(normalized, generation));
    });
  }

  Future<void> _checkUsernameAvailability(
    String username,
    int generation,
  ) async {
    try {
      final available = await _usernameService.isAvailable(username);
      if (!mounted || generation != _usernameCheckGeneration) {
        return;
      }
      if (UsernameHelpers.normalize(_usernameController.text) != username) {
        return;
      }
      setState(() {
        _usernameAvailability = available
            ? _UsernameAvailability.available
            : _UsernameAvailability.taken;
      });
    } on UsernameException {
      if (!mounted || generation != _usernameCheckGeneration) {
        return;
      }
      setState(() => _usernameAvailability = _UsernameAvailability.idle);
    }
  }

  Widget? _usernameStatusIcon(AppPalette palette) {
    return switch (_usernameAvailability) {
      _UsernameAvailability.idle => null,
      _UsernameAvailability.checking => const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      _UsernameAvailability.available => Icon(
          Icons.check_circle_rounded,
          color: palette.accentPrimary,
        ),
      _UsernameAvailability.taken => const Icon(
          Icons.cancel_rounded,
          color: _takenColor,
        ),
      _UsernameAvailability.invalid => const Icon(
          Icons.cancel_rounded,
          color: _invalidColor,
        ),
    };
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

    if (_usernameAvailability == _UsernameAvailability.taken) {
      AppSnackBar.showError(
        context,
        'Ese nombre de usuario ya está tomado.',
      );
      return;
    }

    if (_usernameAvailability == _UsernameAvailability.checking) {
      AppSnackBar.show(
        context,
        'Espera un momento mientras verificamos el nombre de usuario.',
      );
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
          setState(() {
            _isCheckingUsername = false;
            _usernameAvailability = _UsernameAvailability.taken;
          });
          AppSnackBar.showError(
            context,
            'Ese nombre de usuario ya está tomado.',
          );
          return;
        }
        // Lo propuso la app, así que se corre al siguiente libre en silencio.
        username = await _usernameService.suggestAvailableFromEmail(email);
        _usernameController.text = username;
        if (mounted) {
          setState(
            () => _usernameAvailability = _UsernameAvailability.available,
          );
        }
      } else if (mounted) {
        setState(
          () => _usernameAvailability = _UsernameAvailability.available,
        );
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


  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final palette = context.palette;
    final isBusy =
        auth.isLoading || _isCheckingUsername;

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
                                textCapitalization: TextCapitalization.none,
                                inputFormatters:
                                    UsernameHelpers.inputFormatters,
                                onChanged: _onUsernameChanged,
                                suffixIcon: _usernameStatusIcon(palette),
                                validator: UsernameHelpers.validationError,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              _UsernameHint(isAutomatic: !_usernameTouched),
                              const SizedBox(height: AppSpacing.md),
                              InternationalPhoneField(
                                key: _whatsappFieldKey,
                                controller: _whatsappController,
                                labelText: 'WhatsApp (opcional)',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              ModernTextField(
                                controller: _nationalIdController,
                                labelText:
                                    'Últimos 4 dígitos de cédula (opcional)',
                                keyboardType: TextInputType.number,
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
                              OutlinedButton.icon(
                                onPressed: isBusy ? null : AppHaptics.wrap(_pickBirthDate),
                                icon: const Icon(Icons.calendar_today_rounded),
                                label: Text(
                                  _birthDate == null
                                      ? 'Fecha de nacimiento'
                                      : Helpers.formatDate(_birthDate!),
                                ),
                              ),
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
                                label: 'Crear cuenta',
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
