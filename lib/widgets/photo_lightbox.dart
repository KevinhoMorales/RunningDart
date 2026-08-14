import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../utils/app_haptics.dart';
import 'haptic_controls.dart';

/// Abre una foto de perfil (o cualquier URL) a pantalla completa, con cierre
/// por arrastre o con el botón. Reutiliza el mismo gesto que el visor de posts.
Future<void> showPhotoLightbox(
  BuildContext context, {
  required String? photoUrl,
  String? displayName,
}) {
  final url = photoUrl?.trim();
  if (url == null || url.isEmpty) {
    return Future.value();
  }

  AppHaptics.lightTap();
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondary, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (context, animation, secondary) => PhotoLightbox(
        photoUrl: url,
        displayName: displayName,
      ),
    ),
  );
}

class PhotoLightbox extends StatefulWidget {
  const PhotoLightbox({
    super.key,
    required this.photoUrl,
    this.displayName,
  });

  final String photoUrl;
  final String? displayName;

  static const dismissDistance = 120.0;

  @override
  State<PhotoLightbox> createState() => _PhotoLightboxState();
}

class _PhotoLightboxState extends State<PhotoLightbox> {
  double _dragOffset = 0;

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() => _dragOffset += details.delta.dy);
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (_dragOffset.abs() > PhotoLightbox.dismissDistance ||
        velocity.abs() > 700) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        (_dragOffset.abs() / (PhotoLightbox.dismissDistance * 2)).clamp(0.0, 1.0);
    final name = widget.displayName?.trim();

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 1 - progress * 0.7),
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: AppHaptics.wrap(() => Navigator.of(context).pop()),
            onVerticalDragUpdate: _handleDragUpdate,
            onVerticalDragEnd: _handleDragEnd,
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Center(
                child: Hero(
                  tag: 'photo-lightbox-${widget.photoUrl}',
                  child: InteractiveViewer(
                    maxScale: 4,
                    child: Image.network(
                      widget.photoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person_rounded,
                        color: Colors.white54,
                        size: 96,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: Row(
                    children: [
                      HapticIconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                      if (name != null && name.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
