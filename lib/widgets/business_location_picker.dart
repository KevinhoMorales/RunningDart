import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../utils/app_haptics.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/constants.dart';

class BusinessLocationPicker extends StatefulWidget {
  const BusinessLocationPicker({
    super.key,
    this.initialLocation,
    required this.onChanged,
  });

  final LatLng? initialLocation;
  final ValueChanged<LatLng?> onChanged;

  @override
  State<BusinessLocationPicker> createState() => _BusinessLocationPickerState();
}

class _BusinessLocationPickerState extends State<BusinessLocationPicker> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  @override
  void didUpdateWidget(covariant BusinessLocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLocation != oldWidget.initialLocation &&
        widget.initialLocation != _selectedLocation) {
      _selectedLocation = widget.initialLocation;
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _selectLocation(LatLng location) {
    setState(() => _selectedLocation = location);
    widget.onChanged(location);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (!mounted) {
        return;
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activa el permiso de ubicación para usar esta opción.'),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final location = LatLng(position.latitude, position.longitude);
      _selectLocation(location);
      _mapController.move(location, 16);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener tu ubicación actual.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final center = _selectedLocation ?? AppConstants.defaultMapCenter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Ubicación en el mapa',
          style: AppTypography.title(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Toca el mapa para marcar dónde está el negocio.',
          style: AppTypography.muted(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: SizedBox(
            height: 220,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: _selectedLocation == null ? 13 : 16,
                    onTap: (_, point) {
                      AppHaptics.lightTap();
                      _selectLocation(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.devlokos.runningdart',
                    ),
                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation!,
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
                Positioned(
                  right: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: FilledButton.tonalIcon(
                    onPressed: _isLocating ? null : AppHaptics.wrap(_useCurrentLocation),
                    icon: _isLocating
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: palette.textPrimary,
                            ),
                          )
                        : const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text('Mi ubicación'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_selectedLocation != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Coordenadas: ${_selectedLocation!.latitude.toStringAsFixed(5)}, '
            '${_selectedLocation!.longitude.toStringAsFixed(5)}',
            style: AppTypography.caption(context),
          ),
        ] else ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Selecciona un punto en el mapa.',
            style: AppTypography.caption(
              context,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
