import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/business_hours.dart';
import '../../models/membership_modality.dart';
import '../../models/business_model.dart';
import '../../providers/admin_business_provider.dart';
import '../../providers/business_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../utils/constants.dart';
import '../../utils/app_haptics.dart';
import '../../utils/business_hours_helpers.dart';
import '../../utils/helpers.dart';
import '../../utils/membership_helpers.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/business_hours_editor.dart';
import '../../widgets/business_location_picker.dart';
import '../../widgets/category_selector.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/international_phone_field.dart';
import '../../widgets/modern_text_field.dart';

class AdminBusinessFormScreen extends StatefulWidget {
  const AdminBusinessFormScreen({
    super.key,
    this.businessId,
  });

  final String? businessId;

  bool get isEditing => businessId != null;

  @override
  State<AdminBusinessFormScreen> createState() =>
      _AdminBusinessFormScreenState();
}

class _AdminBusinessFormScreenState extends State<AdminBusinessFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _discountController = TextEditingController();
  final _benefitController = TextEditingController();
  final _whatsappFieldKey = GlobalKey<InternationalPhoneFieldState>();
  final _whatsappController = TextEditingController();
  final _instagramController = TextEditingController();
  final _meniuzMenuUrlController = TextEditingController();
  final _conditionsController = TextEditingController();
  String? _initialWhatsapp;

  String _selectedCategory = AppConstants.businessCategories[1];
  final List<String> _benefits = [];
  final Set<MembershipModality> _selectedModalities = {};
  LatLng? _selectedLocation;
  List<BusinessHoursSlot> _operatingHoursSlots = const [
    BusinessHoursSlot(
      weekdays: [1, 2, 3, 4, 5],
      period: BusinessDayPeriod.morning,
      start: TimeOfDay(hour: 9, minute: 0),
      end: TimeOfDay(hour: 12, minute: 0),
    ),
  ];
  String? _legacyHours;
  bool _isLoading = false;
  String? _existingImageUrl;
  XFile? _selectedPhoto;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedModalities.addAll(MembershipModality.values);
    if (widget.isEditing) {
      _loadBusiness();
    }
  }

  Future<void> _loadBusiness() async {
    setState(() => _isLoading = true);

    final business = await context
        .read<BusinessProvider>()
        .getBusinessById(widget.businessId!);

    if (!mounted) {
      return;
    }

    if (business != null) {
      _nameController.text = business.name;
      _descriptionController.text = business.description;
      _addressController.text = business.address;
      _phoneController.text = business.phone;
      _legacyHours = business.hasStructuredHours ? null : business.hours;
      _operatingHoursSlots = business.hasStructuredHours
          ? List<BusinessHoursSlot>.from(business.operatingHours.slots)
          : _operatingHoursSlots;
      _discountController.text = business.discount;
      _initialWhatsapp = business.whatsapp;
      _instagramController.text = business.instagram ?? '';
      _meniuzMenuUrlController.text = business.meniuzMenuUrl ?? '';
      _conditionsController.text = business.conditions ?? '';
      _existingImageUrl = business.imageUrl;
      _selectedCategory = business.category;
      _benefits
        ..clear()
        ..addAll(business.benefits);
      _selectedModalities
        ..clear()
        ..addAll(
          business.applicableModalities.isEmpty
              ? MembershipModality.values
              : business.applicableModalities,
        );
      if (business.hasLocation) {
        _selectedLocation = LatLng(business.latitude!, business.longitude!);
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _discountController.dispose();
    _benefitController.dispose();
    _whatsappController.dispose();
    _instagramController.dispose();
    _meniuzMenuUrlController.dispose();
    _conditionsController.dispose();
    super.dispose();
  }

  void _addBenefit() {
    final value = _benefitController.text.trim();
    if (value.isEmpty) {
      return;
    }
    setState(() {
      _benefits.add(value);
      _benefitController.clear();
    });
  }

  void _removeBenefit(int index) {
    setState(() => _benefits.removeAt(index));
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );

    if (picked != null && mounted) {
      setState(() => _selectedPhoto = picked);
    }
  }

  void _clearSelectedPhoto() {
    setState(() => _selectedPhoto = null);
  }

  Future<bool> _uploadSelectedPhoto(String businessId) async {
    final photo = _selectedPhoto;
    if (photo == null) {
      return true;
    }

    final adminBusiness = context.read<AdminBusinessProvider>();
    final url = await adminBusiness.uploadPhoto(businessId, file: photo);
    if (!mounted) {
      return false;
    }
    if (url == null && adminBusiness.error != null) {
      AppSnackBar.showError(context, adminBusiness.error);
      return false;
    }
    return true;
  }

  String? _formatWhatsappForSave() {
    final local = _whatsappController.text.trim();
    if (local.isEmpty) {
      return null;
    }
    return _whatsappFieldKey.currentState?.formatForStorage() ??
        MembershipHelpers.formatWhatsappForStorage(local);
  }

  String? _formatMeniuzMenuUrlForSave() {
    if (!Helpers.isRestaurantCategory(_selectedCategory)) {
      return null;
    }

    final trimmed = _meniuzMenuUrlController.text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final hoursError = BusinessHoursHelpers.validateSlots(_operatingHoursSlots);
    if (hoursError != null) {
      AppSnackBar.show(context, hoursError);
      return;
    }

    final operatingHours = BusinessOperatingHours(slots: _operatingHoursSlots);
    final summaryHours =
        BusinessHoursHelpers.toDisplaySummary(_operatingHoursSlots);

    final adminBusiness = context.read<AdminBusinessProvider>();
    final allModalitiesSelected =
        _selectedModalities.length == MembershipModality.values.length;
    final business = BusinessModel(
      id: widget.businessId ?? '',
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      hours: summaryHours,
      operatingHours: operatingHours,
      category: _selectedCategory,
      benefits: List.unmodifiable(_benefits),
      discount: _discountController.text.trim(),
      latitude: _selectedLocation?.latitude,
      longitude: _selectedLocation?.longitude,
      whatsapp: _formatWhatsappForSave(),
      instagram: _instagramController.text.trim(),
      meniuzMenuUrl: _formatMeniuzMenuUrlForSave(),
      conditions: _conditionsController.text.trim(),
      applicableModalities: allModalitiesSelected
          ? const []
          : _selectedModalities.toList(growable: false),
    );

    if (widget.isEditing) {
      final success = await adminBusiness.updateBusiness(business);
      if (!mounted) {
        return;
      }
      if (success) {
        final photoUploaded = await _uploadSelectedPhoto(business.id);
        if (!mounted) {
          return;
        }
        if (!photoUploaded) {
          AppSnackBar.show(
            context,
            'Marca actualizada, pero no se pudo subir la foto.',
          );
          return;
        }
        AppSnackBar.show(context, 'Marca aliada actualizada.');
        context.pop();
      } else if (adminBusiness.error != null) {
        AppSnackBar.showError(context, adminBusiness.error);
      }
      return;
    }

    final businessId = await adminBusiness.createBusiness(business: business);
    if (!mounted) {
      return;
    }

    if (businessId != null) {
      final photoUploaded = await _uploadSelectedPhoto(businessId);
      if (!mounted) {
        return;
      }
      if (!photoUploaded) {
        AppSnackBar.show(
          context,
          'Marca creada, pero no se pudo subir la foto.',
        );
        return;
      }
      AppSnackBar.show(context, 'Marca aliada creada correctamente.');
      context.pop();
    } else if (adminBusiness.error != null) {
      AppSnackBar.showError(context, adminBusiness.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final adminBusiness = context.watch<AdminBusinessProvider>();

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: CustomAppBar(
        title: widget.isEditing ? 'Editar marca aliada' : 'Nueva marca aliada',
        leading: HapticIconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ModernTextField(
                      controller: _nameController,
                      labelText: 'Nombre de la marca aliada',
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Ingresa el nombre'
                              : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ModernTextField(
                      controller: _descriptionController,
                      labelText: 'Descripción',
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Ingresa una descripción'
                              : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ModernTextField(
                      controller: _discountController,
                      labelText: 'Descuento',
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Ingresa el descuento'
                              : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ModernTextField(
                      controller: _addressController,
                      labelText: 'Dirección',
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Ingresa la dirección'
                              : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    BusinessLocationPicker(
                      initialLocation: _selectedLocation,
                      onChanged: (location) {
                        setState(() => _selectedLocation = location);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ModernTextField(
                      controller: _phoneController,
                      labelText: 'Teléfono',
                      keyboardType: TextInputType.phone,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Ingresa el teléfono'
                              : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    BusinessHoursEditor(
                      slots: _operatingHoursSlots,
                      legacyHours: _legacyHours,
                      enabled: !adminBusiness.isSaving,
                      onChanged: (slots) {
                        setState(() => _operatingHoursSlots = slots);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    InternationalPhoneField(
                      key: _whatsappFieldKey,
                      controller: _whatsappController,
                      labelText: 'WhatsApp',
                      initialStoredNumber: _initialWhatsapp,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ModernTextField(
                      controller: _instagramController,
                      labelText: 'Instagram',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ModernTextField(
                      controller: _conditionsController,
                      labelText: 'Condiciones del beneficio',
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Modalidades aplicables',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...MembershipModality.values.map(
                      (modality) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _selectedModalities.contains(modality),
                        onChanged: AppHaptics.wrapValue((value) {
                          setState(() {
                            if (value == true) {
                              _selectedModalities.add(modality);
                            } else {
                              _selectedModalities.remove(modality);
                            }
                          });
                        }),
                        title: Text(modality.displayName),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CategorySelector(
                      selectedCategory: _selectedCategory,
                      onCategorySelected: (category) {
                        setState(() => _selectedCategory = category);
                      },
                    ),
                    if (Helpers.isRestaurantCategory(_selectedCategory)) ...[
                      const SizedBox(height: AppSpacing.md),
                      ModernTextField(
                        controller: _meniuzMenuUrlController,
                        labelText: 'Enlace de menú en Meniuz',
                        keyboardType: TextInputType.url,
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return null;
                          }
                          if (!Helpers.isValidHttpUrl(trimmed)) {
                            return 'Ingresa un enlace válido (https://...)';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Beneficios',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: ModernTextField(
                            controller: _benefitController,
                            labelText: 'Agregar beneficio',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        HapticIconButton(
                          onPressed: _addBenefit,
                          icon: const Icon(Icons.add_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: palette.accentPrimary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    if (_benefits.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: _benefits.asMap().entries.map((entry) {
                          return Chip(
                            label: Text(entry.value),
                            onDeleted: AppHaptics.wrap(() => _removeBenefit(entry.key)),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _BusinessPhotoSection(
                      existingImageUrl: _existingImageUrl,
                      selectedPhoto: _selectedPhoto,
                      onPickPhoto: _pickPhoto,
                      onClearPhoto: _selectedPhoto == null ? null : _clearSelectedPhoto,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: widget.isEditing ? 'Guardar cambios' : 'Crear marca',
                      onPressed: adminBusiness.isSaving ? null : _submit,
                      isLoading: adminBusiness.isSaving,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _BusinessPhotoSection extends StatelessWidget {
  const _BusinessPhotoSection({
    required this.existingImageUrl,
    required this.selectedPhoto,
    required this.onPickPhoto,
    this.onClearPhoto,
  });

  final String? existingImageUrl;
  final XFile? selectedPhoto;
  final VoidCallback onPickPhoto;
  final VoidCallback? onClearPhoto;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final previewUrl = selectedPhoto == null ? existingImageUrl : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Foto de la marca',
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Portada visible en el listado y detalle del negocio.',
          style: TextStyle(color: palette.textMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: selectedPhoto != null
                ? Image.file(
                    File(selectedPhoto!.path),
                    fit: BoxFit.cover,
                  )
                : previewUrl != null && previewUrl.isNotEmpty
                    ? Image.network(
                        previewUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _PhotoPlaceholder(palette: palette),
                      )
                    : _PhotoPlaceholder(palette: palette),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: AppHaptics.wrap(onPickPhoto),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  previewUrl != null || selectedPhoto != null
                      ? 'Cambiar imagen'
                      : 'Seleccionar imagen',
                ),
              ),
            ),
            if (onClearPhoto != null) ...[
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                onPressed: AppHaptics.wrap(onClearPhoto),
                child: const Text('Quitar'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: palette.inputFill,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 40,
            color: palette.textMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Sin foto',
            style: TextStyle(color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}
