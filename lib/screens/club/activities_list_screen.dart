import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/activity_helpers.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/custom_app_bar.dart';

class ActivitiesListScreen extends StatelessWidget {
  const ActivitiesListScreen({
    super.key,
    this.embedded = false,
  });

  /// Cuando es tab del shell, el AppBar lo pone HomeScreen.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final service = context.read<ActivityService>();
    final palette = context.palette;

    final body = StreamBuilder<List<ActivityModel>>(
      stream: service.watchUpcomingActivities(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final activities = snapshot.data ?? const <ActivityModel>[];
        if (activities.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Pronto verás aquí los Social Runs de martes y jueves.',
                textAlign: TextAlign.center,
                style: AppTypography.muted(context),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: activities.length,
          separatorBuilder: (_, index) =>
              const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final activity = activities[index];
            return Material(
              color: palette.cardBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: InkWell(
                onTap: AppHaptics.wrap(
                  () => context.push('/activities/${activity.id}'),
                ),
                enableFeedback: false,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: palette.accentPrimary.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Icon(
                          Icons.directions_run_rounded,
                          color: palette.accentPrimary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.title,
                              style: AppTypography.body(
                                context,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ActivityHelpers.formatActivityWhen(
                                activity.startsAt,
                              ),
                              style: AppTypography.caption(
                                context,
                                color: palette.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (activity.venue != null) activity.venue!,
                                '${activity.confirmedCount} confirmados',
                              ].join(' · '),
                              style: AppTypography.caption(
                                context,
                                color: palette.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: palette.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (embedded) {
      return body;
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Actividades'),
      body: body,
    );
  }
}
