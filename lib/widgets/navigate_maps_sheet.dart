import 'dart:io';

import 'package:flutter/material.dart';

import '../models/business_model.dart';
import '../services/map_launcher_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

Future<void> showNavigateMapsSheet(
  BuildContext context,
  BusinessModel business,
) {
  if (!business.hasLocation) {
    return Future<void>.value();
  }

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final palette = sheetContext.palette;
      final latitude = business.latitude!;
      final longitude = business.longitude!;

      Future<void> launch(Future<bool> Function() action, String appName) async {
        Navigator.pop(sheetContext);
        final launched = await action();
        if (!context.mounted) {
          return;
        }
        if (!launched) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo abrir $appName.')),
          );
        }
      }

      return Container(
        decoration: BoxDecoration(
          color: palette.bottomSheetBackground,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.inputBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Cómo llegar',
              style: AppTypography.sectionTitle(sheetContext),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              business.name,
              style: AppTypography.muted(sheetContext),
            ),
            const SizedBox(height: AppSpacing.md),
            _MapOptionTile(
              icon: Icons.map_rounded,
              label: 'Google Maps',
              onTap: () => launch(
                () => MapLauncherService.openGoogleMaps(
                  latitude: latitude,
                  longitude: longitude,
                  label: business.name,
                ),
                'Google Maps',
              ),
            ),
            if (Platform.isIOS)
              _MapOptionTile(
                icon: Icons.map_outlined,
                label: 'Apple Maps',
                onTap: () => launch(
                  () => MapLauncherService.openAppleMaps(
                    latitude: latitude,
                    longitude: longitude,
                    label: business.name,
                  ),
                  'Apple Maps',
                ),
              ),
            _MapOptionTile(
              icon: Icons.navigation_rounded,
              label: 'Waze',
              onTap: () => launch(
                () => MapLauncherService.openWaze(
                  latitude: latitude,
                  longitude: longitude,
                ),
                'Waze',
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _MapOptionTile extends StatelessWidget {
  const _MapOptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: palette.iconButtonBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Icon(icon, color: palette.textPrimary),
      ),
      title: Text(label, style: AppTypography.body(context)),
      trailing: Icon(Icons.chevron_right_rounded, color: palette.textMuted),
      onTap: onTap,
    );
  }
}
