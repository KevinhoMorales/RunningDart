import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.displayName,
    this.photoUrl,
    this.radius = 40,
    this.showBackground = true,
  });

  final String displayName;
  final String? photoUrl;
  final double radius;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor:
            showBackground ? palette.iconButtonBackground : Colors.transparent,
        backgroundImage: NetworkImage(photoUrl!),
      );
    }

    return CircleAvatar(
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
}
