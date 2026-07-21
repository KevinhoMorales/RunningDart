import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../utils/app_haptics.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/constants.dart';
import 'app_snackbar.dart';
import 'modern_text_field.dart';

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
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  LatLng? _selectedLocation;
  bool _isLocating = false;
  bool _suppressFieldSync = false;
  Timer? _coordDebounce;

  static final RegExp _coordinateInputPattern = RegExp(r'^-?\d*\.?\d*$');

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    if (_selectedLocation != null) {
      _syncFieldsFromLocation(_selectedLocation!);
    }
    _latController.addListener(_onCoordinateFieldsChanged);
    _lngController.addListener(_onCoordinateFieldsChanged);
    if (_selectedLocation == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _mapController.move(AppConstants.defaultMapCenter, 13);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _mapController.move(_selectedLocation!, 16);
      });
    }
  }

  @override
  void didUpdateWidget(covariant BusinessLocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLocation != oldWidget.initialLocation &&
        widget.initialLocation != _selectedLocation) {
      _selectedLocation = widget.initialLocation;
      if (_selectedLocation != null) {
        _syncFieldsFromLocation(_selectedLocation!);
        _mapController.move(_selectedLocation!, 16);
      } else {
        _suppressFieldSync = true;
        _latController.clear();
        _lngController.clear();
        _suppressFieldSync = false;
      }
    }
  }

  @override
  void dispose() {
    _coordDebounce?.cancel();
    _latController.dispose();
    _lngController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _syncFieldsFromLocation(LatLng location) {
    _suppressFieldSync = true;
    _latController.text = location.latitude.toStringAsFixed(5);
    _lngController.text = location.longitude.toStringAsFixed(5);
    _suppressFieldSync = false;
  }

  void _onCoordinateFieldsChanged() {
    if (_suppressFieldSync) {
      return;
    }
    _coordDebounce?.cancel();
    _coordDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        _applyCoordinatesFromFields();
      }
    });
  }

  void _applyCoordinatesFromFields() {
    final lat = double.tryParse(_latController.text.replaceAll(',', '.'));
    final lng = double.tryParse(_lngController.text.replaceAll(',', '.'));
    if (lat == null || lng == null) {
      return;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return;
    }

    final location = LatLng(lat, lng);
    if (_selectedLocation?.latitude == lat &&
        _selectedLocation?.longitude == lng) {
      return;
    }

    setState(() => _selectedLocation = location);
    widget.onChanged(location);
    _mapController.move(location, 16);
  }

  void _selectLocation(LatLng location) {
    setState(() => _selectedLocation = location);
    widget.onChanged(location);
    _syncFieldsFromLocation(location);
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
        AppSnackBar.show(
          context,
          'Activa el permiso de ubicación para usar esta opción.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final location = LatLng(position.latitude, position.longitude);
      _selectLocation(location);
      _mapController.move(location, 16);
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          'No se pudo obtener tu ubicación actual.',
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
          'Toca el mapa o ingresa coordenadas para marcar dónde está el negocio.',
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
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ModernTextField(
                controller: _latController,
                labelText: 'Latitud',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(_coordinateInputPattern),
                ],
                onFieldSubmitted: (_) => _applyCoordinatesFromFields(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ModernTextField(
                controller: _lngController,
                labelText: 'Longitud',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(_coordinateInputPattern),
                ],
                onFieldSubmitted: (_) => _applyCoordinatesFromFields(),
              ),
            ),
          ],
        ),
        if (_selectedLocation == null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Selecciona un punto en el mapa o ingresa latitud y longitud.',
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
