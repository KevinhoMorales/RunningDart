import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../utils/app_haptics.dart';
import '../utils/constants.dart';

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
        onTap: () => _launchWhatsApp(whatsapp!.trim()),
      ));
    }

    if (instagram != null && instagram!.trim().isNotEmpty) {
      items.add((
        label: 'Instagram',
        icon: Icons.camera_alt_outlined,
        onTap: () => _launchInstagram(instagram!.trim()),
      ));
    }

    if (phone != null && phone!.trim().isNotEmpty) {
      items.add((
        label: 'Llamar',
        icon: Icons.phone_rounded,
        onTap: () => _launchPhone(phone!.trim()),
      ));
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final palette = context.palette;

    if (compact) {
      return Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            _CompactSocialButton(
              icon: items[i].icon,
              label: items[i].label,
              onTap: items[i].onTap,
              palette: palette,
            ),
          ],
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _launchWhatsApp(String value) async {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchInstagram(String value) async {
    final handle = value.replaceAll('@', '').trim();
    final uri = Uri.parse(
      value.startsWith('http') ? value : 'https://instagram.com/$handle',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchPhone(String value) async {
    final uri = Uri.parse('tel:$value');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        onTap: AppHaptics.wrap(onTap),
        enableFeedback: false,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppConstants.primaryColor),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  color: AppConstants.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
