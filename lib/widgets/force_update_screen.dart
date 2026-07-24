import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';
import '../utils/constants.dart';
import 'modern_text_field.dart';

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({
    super.key,
    required this.currentVersion,
    required this.requiredVersion,
  });

  final String currentVersion;
  final String requiredVersion;

  String get _storeUrl {
    if (Platform.isIOS) {
      return AppConstants.iosAppStoreUrl;
    }
    return AppConstants.androidPlayStoreUrl;
  }

  Future<void> _openStore(BuildContext context) async {
    final uri = Uri.parse(_storeUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted || launched) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo abrir la tienda. Intenta de nuevo.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: palette.scaffoldBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: palette.accentPrimary,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: const Icon(
                    Icons.system_update_alt_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Actualización requerida',
                  textAlign: TextAlign.center,
                  style: AppTypography.sectionTitle(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Hay una nueva versión de ${AppConstants.appName} disponible. '
                  'Actualiza la app para continuar.',
                  textAlign: TextAlign.center,
                  style: AppTypography.muted(context).copyWith(height: 1.5),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: palette.cardBackground,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  child: Column(
                    children: [
                      _VersionRow(
                        label: 'Tu versión',
                        value: currentVersion,
                        palette: palette,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _VersionRow(
                        label: 'Versión mínima',
                        value: requiredVersion,
                        palette: palette,
                        highlight: true,
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                PrimaryButton(
                  label: 'Actualizar ahora',
                  onPressed: AppHaptics.wrap(() => _openStore(context)),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  Platform.isIOS
                      ? 'Te llevaremos al App Store.'
                      : 'Te llevaremos a Google Play.',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.label,
    required this.value,
    required this.palette,
    this.highlight = false,
  });

  final String label;
  final String value;
  final AppPalette palette;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.caption(context),
          ),
        ),
        Text(
          value,
          style: AppTypography.body(
            context,
            weight: FontWeight.w700,
            color: highlight ? palette.accentPrimary : palette.textPrimary,
          ),
        ),
      ],
    );
  }
}
