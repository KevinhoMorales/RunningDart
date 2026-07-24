import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';
import '../utils/constants.dart';
import '../utils/external_url_launcher.dart';
import '../utils/whatsapp_launcher.dart';
import '../widgets/app_snackbar.dart';

class SocialLinksRow extends StatelessWidget {
  const SocialLinksRow({
    super.key,
    this.whatsapp,
    this.instagram,
    this.phone,
    this.compact = false,
  });

  final String? whatsapp;
  final String? instagram;
  final String? phone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, IconData icon, VoidCallback onTap})>[];

    if (whatsapp != null && whatsapp!.trim().isNotEmpty) {
      items.add((
        label: 'WhatsApp',
        icon: Icons.chat_rounded,
        onTap: () => _confirmAndLaunchWhatsApp(context, whatsapp!.trim()),
      ));
    }

    if (instagram != null && instagram!.trim().isNotEmpty) {
      items.add((
        label: 'Instagram',
        icon: Icons.camera_alt_outlined,
        onTap: () => _confirmAndLaunchInstagram(context, instagram!.trim()),
      ));
    }

    if (phone != null && phone!.trim().isNotEmpty) {
      items.add((
        label: 'Llamar',
        icon: Icons.phone_rounded,
        onTap: () => _confirmAndLaunchPhone(context, phone!.trim()),
      ));
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final palette = context.palette;

    if (compact) {
      return Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: i == 0 ? 0 : AppSpacing.xs,
                ),
                child: _CompactSocialButton(
                  icon: items[i].icon,
                  label: items[i].label,
                  onTap: items[i].onTap,
                  palette: palette,
                ),
              ),
            ),
        ],
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: items.map((item) {
        return OutlinedButton.icon(
          onPressed: AppHaptics.wrap(item.onTap),
          icon: Icon(item.icon, size: 18),
          label: Text(item.label),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppConstants.primaryColor,
            side: BorderSide(color: palette.inputBorder),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _confirmAndLaunchWhatsApp(
    BuildContext context,
    String phone,
  ) async {
    final confirmed = await confirmExternalAction(
      context,
      title: '¿Abrir WhatsApp?',
      message: 'Se abrirá WhatsApp para contactar a esta marca.',
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    final launched = await launchWhatsApp(phone);
    if (!launched && context.mounted) {
      AppSnackBar.show(context, 'No se pudo abrir WhatsApp. Intenta de nuevo.');
    }
  }

  Future<void> _confirmAndLaunchInstagram(
    BuildContext context,
    String value,
  ) async {
    final confirmed = await confirmExternalAction(
      context,
      title: '¿Abrir Instagram?',
      message: 'Se abrirá Instagram para ver el perfil de esta marca.',
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    final handle = value.replaceAll('@', '').trim();
    final uri = Uri.parse(
      value.startsWith('http') ? value : 'https://instagram.com/$handle',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      AppSnackBar.show(context, 'No se pudo abrir Instagram. Intenta de nuevo.');
    }
  }

  Future<void> _confirmAndLaunchPhone(
    BuildContext context,
    String value,
  ) async {
    final confirmed = await confirmExternalAction(
      context,
      title: '¿Llamar?',
      message: 'Se abrirá la app de teléfono para llamar a esta marca.',
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    final uri = Uri.parse('tel:$value');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      AppSnackBar.show(context, 'No se pudo iniciar la llamada. Intenta de nuevo.');
    }
  }
}

class _CompactSocialButton extends StatelessWidget {
  const _CompactSocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.iconButtonBackground,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: AppHaptics.wrap(onTap),
        enableFeedback: false,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: AppConstants.primaryColor),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.caption(context).copyWith(
                  color: AppConstants.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
