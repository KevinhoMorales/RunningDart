import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:latlong2/latlong.dart';

import '../../models/business_model.dart';
import '../../providers/admin_business_provider.dart';
import '../../providers/business_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../utils/constants.dart';
import '../../widgets/business_location_picker.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/custom_app_bar.dart';
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
  final _hoursController = TextEditingController();
  final _discountController = TextEditingController();
  final _benefitController = TextEditingController();

  String _selectedCategory = AppConstants.businessCategories[1];
  final List<String> _benefits = [];
  LatLng? _selectedLocation;
  bool _isLoading = false;
  bool _uploadPhotoAfterCreate = false;

  @override
  void initState() {
    super.initState();
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
      _hoursController.text = business.hours;
      _discountController.text = business.discount;
      _selectedCategory = business.category;
      _benefits
        ..clear()
        ..addAll(business.benefits);
      if (business.hasLocation) {
        _selectedLocation =
            LatLng(business.latitude!, business.longitude!);
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
    _hoursController.dispose();
    _discountController.dispose();
    _benefitController.dispose();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marca la ubicación del negocio en el mapa.'),
        ),
      );
      return;
    }

    final adminBusiness = context.read<AdminBusinessProvider>();
    final business = BusinessModel(
      id: widget.businessId ?? '',
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      hours: _hoursController.text.trim(),
      category: _selectedCategory,
      benefits: List.unmodifiable(_benefits),
      discount: _discountController.text.trim(),
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
    );

    if (widget.isEditing) {
      final success = await adminBusiness.updateBusiness(business);
      if (!mounted) {
        return;
      }
      if (success) {
        if (_uploadPhotoAfterCreate) {
          await adminBusiness.uploadPhoto(business.id);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Negocio actualizado.')),
        );
        context.pop();
      } else if (adminBusiness.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(adminBusiness.error!)),
        );
      }
      return;
    }

    final businessId = await adminBusiness.createBusiness(business: business);
    if (!mounted) {
      return;
    }

    if (businessId != null) {
      if (_uploadPhotoAfterCreate) {
        await adminBusiness.uploadPhoto(businessId);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Negocio creado correctamente.')),
      );
      context.pop();
    } else if (adminBusiness.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(adminBusiness.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final adminBusiness = context.watch<AdminBusinessProvider>();

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: CustomAppBar(
        title: widget.isEditing ? 'Editar negocio' : 'Nuevo negocio',
        leading: IconButton(
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
                      labelText: 'Nombre del negocio',
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
                    ModernTextField(
                      controller: _hoursController,
                      labelText: 'Horario',
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Ingresa el horario'
                              : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Categoría',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: AppConstants.businessCategories
                          .where((category) => category != 'Todos')
                          .map(
                            (category) => CategoryChip(
                              label: category,
                              category: category,
                              isSelected: _selectedCategory == category,
                              onSelected: () {
                                setState(() => _selectedCategory = category);
                              },
                            ),
                          )
                          .toList(),
                    ),
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
                        IconButton.filled(
                          onPressed: _addBenefit,
                          icon: const Icon(Icons.add_rounded),
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
                            onDeleted: () => _removeBenefit(entry.key),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Subir foto del negocio',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        widget.isEditing
                            ? 'Selecciona una imagen para reemplazar la portada.'
                            : 'Después de crear el negocio se subirá la foto.',
                        style: TextStyle(color: palette.textMuted),
                      ),
                      value: _uploadPhotoAfterCreate,
                      onChanged: (value) {
                        setState(() => _uploadPhotoAfterCreate = value);
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: widget.isEditing ? 'Guardar cambios' : 'Crear negocio',
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
