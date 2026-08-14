import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../utils/app_haptics.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.displayName,
    this.photoUrl,
    this.radius = 40,
    this.showBackground = true,
    this.onTap,
  });

  final String displayName;
  final String? photoUrl;
  final double radius;
  final bool showBackground;

  /// Cuando hay foto (o siempre, si se pasa), un toque dispara esta acción —
  /// p. ej. abrir el lightbox en el perfil.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final Widget avatar;
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor:
            showBackground ? palette.iconButtonBackground : Colors.transparent,
        backgroundImage: NetworkImage(photoUrl!),
      );
    } else {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: showBackground
            ? palette.accentPrimary.withValues(alpha: 0.15)
            : palette.iconButtonBackground,
        child: Icon(
          Icons.person_rounded,
          size: radius * 1.1,
          color: palette.accentPrimary,
        ),
      );
    }

    if (onTap == null) {
      return avatar;
    }

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: AppHaptics.wrap(onTap!),
        enableFeedback: false,
        child: avatar,
      ),
    );
  }
}
