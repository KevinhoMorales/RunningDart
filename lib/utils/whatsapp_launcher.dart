import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../utils/app_haptics.dart';
import '../utils/constants.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/haptic_controls.dart';

Future<bool> launchWhatsApp(String phone, {String? message}) async {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) {
    return false;
  }

  final queryParameters =
      message != null && message.trim().isNotEmpty
          ? {'text': message.trim()}
          : null;
  final uri = Uri(
    scheme: 'https',
    host: 'wa.me',
    path: digits,
    queryParameters: queryParameters,
  );

  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<bool> launchWhatsAppGroupInvite(String inviteUrl) async {
  final uri = Uri.tryParse(inviteUrl.trim());
  if (uri == null ||
      uri.host != 'chat.whatsapp.com' ||
      uri.scheme != 'https') {
    return false;
  }

  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> launchWhatsAppGroupInviteFromContext(
  BuildContext context,
  String inviteUrl,
) async {
  final launched = await launchWhatsAppGroupInvite(inviteUrl);
  if (!launched && context.mounted) {
    AppSnackBar.show(context, 'No se pudo abrir WhatsApp. Intenta de nuevo.');
  }
}

String? whatsAppGroupUrlForScheduleSection(
  String title, {
  required bool isProTeamMember,
}) {
  if (title.contains('Pro Team')) {
    return isProTeamMember ? AppConstants.proTeamWhatsAppGroupUrl : null;
  }
  if (title.contains('Comunidad') || title.contains('Oficial')) {
    return AppConstants.communityWhatsAppGroupUrl;
  }
  return null;
}

String whatsAppGroupCtaLabelForScheduleSection(String title) {
  if (title.contains('Pro Team')) {
    return 'Grupo Pro Team en WhatsApp';
  }
  return 'Unirme al grupo de WhatsApp';
}

Future<void> confirmAndLaunchWhatsApp(
  BuildContext context, {
  String phone = AppConstants.supportWhatsApp,
  String? message = AppConstants.supportWhatsAppDefaultMessage,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => const _WhatsAppConfirmDialog(),
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  final launched = await launchWhatsApp(phone, message: message);
  if (!launched && context.mounted) {
    AppSnackBar.show(context, 'No se pudo abrir WhatsApp. Intenta de nuevo.');
  }
}

class _WhatsAppConfirmDialog extends StatelessWidget {
  const _WhatsAppConfirmDialog();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AlertDialog(
      title: const Text('¿Abrir WhatsApp?'),
      content: Text(
        'Se abrirá WhatsApp para contactar al equipo SAINTS sobre dudas, '
        'membresía o unirte a la comunidad.',
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      actionsOverflowButtonSpacing: AppSpacing.md,
      actions: [
        HapticTextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancelar',
            style: TextStyle(color: palette.textMuted),
          ),
        ),
        HapticFilledButton(
          onPressed: AppHaptics.wrap(() => Navigator.of(context).pop(true)),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            minimumSize: const Size(120, 44),
          ),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
