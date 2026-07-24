import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../services/social_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/modern_text_field.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();
  final _socialService = SocialService();

  XFile? _selectedPhoto;
  bool _isPublishing = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
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

  Future<void> _publish() async {
    final photo = _selectedPhoto;
    if (photo == null) {
      AppSnackBar.show(context, 'Elige una foto para publicar.');
      return;
    }

    final user = context.read<AuthProvider>().user;
    if (user == null) {
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final post = PostModel(
        id: '',
        authorId: user.id,
        authorName: user.displayName,
        authorPhotoUrl: user.photoUrl,
        caption: _captionController.text.trim(),
        createdAt: DateTime.now(),
      );

      await context.read<FeedProvider>().createPost(post: post, image: photo);

      await _socialService.upsertPublicProfile(
        userId: user.id,
        displayName: user.displayName,
        photoUrl: user.photoUrl,
        bio: user.bio,
        username: user.username,
      );

      if (!mounted) {
        return;
      }
      AppSnackBar.show(context, 'Publicado. ¡Gracias por compartir!');
      context.pop();
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'No se pudo publicar. Intenta de nuevo.');
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: CustomAppBar(
        title: 'Nueva publicación',
        leading: HapticIconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PhotoPicker(
              selectedPhoto: _selectedPhoto,
              onPickPhoto: _isPublishing ? null : _pickPhoto,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Descripción',
              style: AppTypography.title(context, weight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            ModernTextField(
              controller: _captionController,
              labelText: '¿Qué quieres compartir?',
              textCapitalization: TextCapitalization.sentences,
              maxLines: 5,
              enabled: !_isPublishing,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Publicar',
              isLoading: _isPublishing,
              onPressed: _isPublishing ? null : _publish,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.selectedPhoto,
    required this.onPickPhoto,
  });

  final XFile? selectedPhoto;
  final VoidCallback? onPickPhoto;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasPhoto = selectedPhoto != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Foto',
          style: AppTypography.title(context, weight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Una imagen cuadrada se ve mejor en el feed.',
          style: AppTypography.muted(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          onTap: onPickPhoto == null ? null : AppHaptics.wrap(onPickPhoto),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: AspectRatio(
              aspectRatio: 1,
              child: hasPhoto
                  ? Image.file(
                      File(selectedPhoto!.path),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: palette.inputFill,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 44,
                            color: palette.textMuted,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Toca para elegir una foto',
                            style: AppTypography.muted(context),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: onPickPhoto == null ? null : AppHaptics.wrap(onPickPhoto),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(hasPhoto ? 'Cambiar foto' : 'Seleccionar foto'),
        ),
      ],
    );
  }
}
