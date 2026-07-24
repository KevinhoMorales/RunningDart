import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/news_model.dart';
import '../../providers/admin_news_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../utils/app_haptics.dart';
import '../../utils/helpers.dart';
import '../../utils/membership_helpers.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/international_phone_field.dart';
import '../../widgets/modern_text_field.dart';

class AdminNewsFormScreen extends StatefulWidget {
  const AdminNewsFormScreen({
    super.key,
    this.newsId,
  });

  final String? newsId;

  bool get isEditing => newsId != null;

  @override
  State<AdminNewsFormScreen> createState() => _AdminNewsFormScreenState();
}

class _AdminNewsFormScreenState extends State<AdminNewsFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _bodyController = TextEditingController();
  final _locationController = TextEditingController();
  final _linkController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _whatsappFieldKey = GlobalKey<InternationalPhoneFieldState>();
  final _moreInfoController = TextEditingController();
  String? _initialWhatsapp;

  DateTime _eventDate = DateTime.now().add(const Duration(days: 7));
  bool _isPublished = false;
  bool _isLoading = false;
  String? _existingImageUrl;
  XFile? _selectedPhoto;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadNews();
    }
  }

  Future<void> _loadNews() async {
    setState(() => _isLoading = true);

    final news =
        await context.read<AdminNewsProvider>().getNewsById(widget.newsId!);

    if (!mounted) {
      return;
    }

    if (news != null) {
      _titleController.text = news.title;
      _summaryController.text = news.summary;
      _bodyController.text = news.body;
      _locationController.text = news.location ?? '';
      _linkController.text = news.link ?? '';
      _initialWhatsapp = news.whatsapp;
      _moreInfoController.text = news.moreInfo ?? '';
      _eventDate = news.eventDate;
      _isPublished = news.isPublished;
      _existingImageUrl = news.imageUrl;
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _bodyController.dispose();
    _locationController.dispose();
    _linkController.dispose();
    _whatsappController.dispose();
    _moreInfoController.dispose();
    super.dispose();
  }

  Future<void> _pickEventDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null && mounted) {
      setState(() => _eventDate = picked);
    }
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

  String? _formatWhatsappForSave() {
    final local = _whatsappController.text.trim();
    if (local.isEmpty) {
      return null;
    }
    return _whatsappFieldKey.currentState?.formatForStorage() ??
        MembershipHelpers.formatWhatsappForStorage(local);
  }

  Future<bool> _uploadSelectedPhoto(String newsId) async {
    final photo = _selectedPhoto;
    if (photo == null) {
      return true;
    }

    final adminNews = context.read<AdminNewsProvider>();
    final url = await adminNews.uploadPhoto(newsId, file: photo);
    if (!mounted) {
      return false;
    }
    if (url == null && adminNews.error != null) {
      AppSnackBar.showError(context, adminNews.error);
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final adminNews = context.read<AdminNewsProvider>();
    final location = _locationController.text.trim();
    final link = _linkController.text.trim();
    final moreInfo = _moreInfoController.text.trim();
    final news = NewsModel(
      id: widget.newsId ?? '',
      title: _titleController.text.trim(),
      summary: _summaryController.text.trim(),
      body: _bodyController.text.trim(),
      eventDate: _eventDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      location: location.isEmpty ? null : location,
      link: link.isEmpty ? null : link,
      whatsapp: _formatWhatsappForSave(),
      moreInfo: moreInfo.isEmpty ? null : moreInfo,
      isPublished: _isPublished,
    );

    if (widget.isEditing) {
      final success = await adminNews.updateNews(news);
      if (!mounted) {
        return;
      }
      if (success) {
        final photoUploaded = await _uploadSelectedPhoto(news.id);
        if (!mounted) {
          return;
        }
        if (!photoUploaded) {
          AppSnackBar.show(
            context,
            'Evento actualizado, pero no se pudo subir la foto.',
          );
          return;
        }
        AppSnackBar.show(context, 'Evento actualizado.');
        context.pop();
      } else if (adminNews.error != null) {
        AppSnackBar.showError(context, adminNews.error);
      }
      return;
    }

    final newsId = await adminNews.createNews(news: news);
    if (!mounted) {
      return;
    }

    if (newsId != null) {
      final photoUploaded = await _uploadSelectedPhoto(newsId);
      if (!mounted) {
        return;
      }
      if (!photoUploaded) {
        AppSnackBar.show(
          context,
          'Evento creado, pero no se pudo subir la foto.',
        );
        return;
      }
      AppSnackBar.show(context, 'Evento creado correctamente.');
      context.pop();
    } else if (adminNews.error != null) {
      AppSnackBar.showError(context, adminNews.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final adminNews = context.watch<AdminNewsProvider>();

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: CustomAppBar(
        title: widget.isEditing ? 'Editar evento' : 'Nuevo evento',
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
                      controller: _titleController,
                      labelText: 'Título',
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Ingresa el título'
                              : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ModernTextField(
                      controller: _summaryController,
                      labelText: 'Resumen',
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Ingresa un resumen'
                              : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ModernTextField(
                      controller: _bodyController,
                      labelText: 'Descripción',
                      maxLines: 6,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Ingresa la descripción'
                              : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ModernTextField(
                      controller: _locationController,
                      labelText: 'Lugar (opcional)',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ModernTextField(
                      controller: _linkController,
                      labelText: 'Enlace (opcional)',
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
                    const SizedBox(height: AppSpacing.md),
                    InternationalPhoneField(
                      key: _whatsappFieldKey,
                      controller: _whatsappController,
                      labelText: 'WhatsApp de contacto (opcional)',
                      initialStoredNumber: _initialWhatsapp,
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return null;
                        }
                        if (!MembershipHelpers.isValidWhatsapp(trimmed)) {
                          return 'Ingresa un número válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ModernTextField(
                      controller: _moreInfoController,
                      labelText: 'Información adicional (opcional)',
                      maxLines: 4,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    HapticListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Fecha del evento',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        Helpers.formatDate(_eventDate),
                        style: TextStyle(color: palette.textMuted),
                      ),
                      trailing: const Icon(Icons.calendar_month_rounded),
                      onTap: _pickEventDate,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Publicado',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Solo los eventos publicados son visibles para todos.',
                        style: TextStyle(color: palette.textMuted),
                      ),
                      value: _isPublished,
                      onChanged: AppHaptics.wrapValue((value) {
                        setState(() => _isPublished = value);
                      }),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _NewsPhotoSection(
                      existingImageUrl: _existingImageUrl,
                      selectedPhoto: _selectedPhoto,
                      onPickPhoto: _pickPhoto,
                      onClearPhoto:
                          _selectedPhoto == null ? null : _clearSelectedPhoto,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label:
                          widget.isEditing ? 'Guardar cambios' : 'Crear evento',
                      onPressed: adminNews.isSaving ? null : _submit,
                      isLoading: adminNews.isSaving,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _NewsPhotoSection extends StatelessWidget {
  const _NewsPhotoSection({
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
          'Foto del evento',
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Portada visible en el listado y detalle del evento.',
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
            Icons.event_outlined,
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
