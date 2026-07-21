import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/app_haptics.dart';
import '../providers/auth_provider.dart';
import '../services/profile_photo_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'user_avatar.dart';

enum CameraButtonStyle {
  filled,
  minimal,
}

class ProfilePhotoPicker extends StatefulWidget {
  const ProfilePhotoPicker({
    super.key,
    required this.userId,
    required this.displayName,
    this.photoUrl,
    this.radius = 40,
    this.showLabel = true,
    this.labelColor,
    this.cameraStyle = CameraButtonStyle.filled,
  });

  final String userId;
  final String displayName;
  final String? photoUrl;
  final double radius;
  final bool showLabel;
  final Color? labelColor;
  final CameraButtonStyle cameraStyle;

  @override
  State<ProfilePhotoPicker> createState() => _ProfilePhotoPickerState();
}

class _ProfilePhotoPickerState extends State<ProfilePhotoPicker> {
  final _photoService = ProfilePhotoService();
  bool _isUploading = false;
  String? _localPhotoUrl;

  String? get _currentPhotoUrl => _localPhotoUrl ?? widget.photoUrl;

  Future<void> _handlePickPhoto() async {
    if (_isUploading) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final downloadUrl =
          await _photoService.pickAndUploadProfilePhoto(widget.userId);

      if (!mounted) {
        return;
      }

      if (downloadUrl != null) {
        setState(() {
          _localPhotoUrl = downloadUrl;
        });
        await context.read<AuthProvider>().refreshAccountStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto de perfil actualizada.')),
          );
        }
      }
    } on ProfilePhotoException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo subir la foto. Intenta de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildCameraButton(AppPalette palette) {
    final iconSize = widget.radius * 0.32;

    if (widget.cameraStyle == CameraButtonStyle.minimal) {
      return Material(
        color: palette.cardBackground,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: AppHaptics.wrap(_handlePickPhoto),
          enableFeedback: false,
          child: Ink(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: palette.cardBorder),
              boxShadow: palette.iconButtonShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.camera_alt_outlined,
                size: iconSize,
                color: palette.textPrimary,
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: palette.accentPrimary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: AppHaptics.wrap(_handlePickPhoto),
        enableFeedback: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            Icons.camera_alt_rounded,
            size: iconSize,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            UserAvatar(
              displayName: widget.displayName,
              photoUrl: _currentPhotoUrl,
              radius: widget.radius,
            ),
            if (_isUploading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            if (!_isUploading) _buildCameraButton(palette),
          ],
        ),
        if (widget.showLabel) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Foto opcional · toca para cambiar',
            style: AppTypography.caption(
              context,
              color: widget.labelColor ?? palette.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
