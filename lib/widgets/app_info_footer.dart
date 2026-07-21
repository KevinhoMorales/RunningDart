import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';
import '../utils/constants.dart';

class AppInfoFooter extends StatelessWidget {
  const AppInfoFooter({super.key});

  Future<void> _openDevLokosSite(BuildContext context) async {
    final uri = Uri.parse(AppConstants.devLokosEnterpriseUrl);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el enlace. Intenta de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '—';
        final build = snapshot.data?.buildNumber ?? '—';

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Versión $version · Build $build',
                style: AppTypography.caption(context),
              ),
              const SizedBox(height: AppSpacing.md),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: AppHaptics.wrap(() => _openDevLokosSite(context)),
                  enableFeedback: false,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    child: Column(
                      children: [
                        ClipOval(
                          child: Image.asset(
                            AppConstants.devLokosLogoAsset,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Aplicación creada por ${AppConstants.devLokosEnterpriseName}',
                          textAlign: TextAlign.center,
                          style: AppTypography.body(
                            context,
                            color: palette.accentPrimary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
