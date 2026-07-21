import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/news_model.dart';
import '../../providers/admin_news_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../utils/app_haptics.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';
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

  DateTime _eventDate = DateTime.now().add(const Duration(days: 7));
  bool _isPublished = false;
  bool _isLoading = false;
  bool _uploadPhotoAfterSave = false;

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
      _eventDate = news.eventDate;
      _isPublished = news.isPublished;
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _bodyController.dispose();
    _locationController.dispose();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final adminNews = context.read<AdminNewsProvider>();
    final location = _locationController.text.trim();
    final news = NewsModel(
      id: widget.newsId ?? '',
      title: _titleController.text.trim(),
      summary: _summaryController.text.trim(),
      body: _bodyController.text.trim(),
      eventDate: _eventDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      location: location.isEmpty ? null : location,
      isPublished: _isPublished,
    );

    if (widget.isEditing) {
      final success = await adminNews.updateNews(news);
      if (!mounted) {
        return;
      }
      if (success) {
        if (_uploadPhotoAfterSave) {
          await adminNews.uploadPhoto(news.id);
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
      if (_uploadPhotoAfterSave) {
        await adminNews.uploadPhoto(newsId);
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
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Subir foto del evento',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        widget.isEditing
                            ? 'Selecciona una imagen para la portada.'
                            : 'Después de crear el evento se subirá la foto.',
                        style: TextStyle(color: palette.textMuted),
                      ),
                      value: _uploadPhotoAfterSave,
                      onChanged: AppHaptics.wrapValue((value) {
                        setState(() => _uploadPhotoAfterSave = value);
                      }),
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
