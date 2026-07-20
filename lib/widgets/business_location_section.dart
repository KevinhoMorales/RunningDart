import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/business_model.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/constants.dart';
import 'modern_text_field.dart';
import 'navigate_maps_sheet.dart';

class BusinessLocationSection extends StatelessWidget {
  const BusinessLocationSection({
    super.key,
    required this.business,
  });

  final BusinessModel business;

  @override
  Widget build(BuildContext context) {
    if (!business.hasLocation) {
      return const SizedBox.shrink();
    }

    final palette = context.palette;
    final location = LatLng(business.latitude!, business.longitude!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: palette.cardBackground,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: palette.isDark
                ? Border.all(color: palette.cardBorder)
                : null,
            boxShadow: palette.isDark
                ? palette.elevatedCardShadow
                : palette.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ubicación',
                style: AppTypography.sectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                child: SizedBox(
                  height: 180,
                  child: IgnorePointer(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: location,
                        initialZoom: 16,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.devlokos.runningdart',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: location,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: AppConstants.primaryColor,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: 'Cómo llegar',
          onPressed: () => showNavigateMapsSheet(context, business),
        ),
      ],
    );
  }
}
