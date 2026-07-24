import 'package:flutter/material.dart';

import '../models/public_profile.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';
import 'user_avatar.dart';

class FollowUserRow extends StatelessWidget {
  const FollowUserRow({
    super.key,
    required this.profile,
    required this.showFollowButton,
    required this.isFollowing,
    required this.onOpenProfile,
    required this.onToggleFollow,
  });

  final PublicProfile profile;
  final bool showFollowButton;
  final bool isFollowing;
  final VoidCallback onOpenProfile;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final name = profile.displayName.trim().isEmpty
        ? 'Miembro SAINTS'
        : profile.displayName.trim();
    final username = profile.username?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Material(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: InkWell(
          onTap: AppHaptics.wrap(onOpenProfile),
          enableFeedback: false,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Row(
              children: [
                UserAvatar(
                  displayName: name,
                  photoUrl: profile.photoUrl,
                  radius: 22,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.title(context),
                      ),
                      if (username.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '@$username',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(
                            context,
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showFollowButton) ...[
                  const SizedBox(width: AppSpacing.sm),
                  isFollowing
                      ? OutlinedButton(
                          onPressed: AppHaptics.wrap(onToggleFollow),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                          ),
                          child: const Text('Siguiendo'),
                        )
                      : FilledButton(
                          onPressed: AppHaptics.wrap(onToggleFollow),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: palette.accentPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                          ),
                          child: const Text('Seguir'),
                        ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
