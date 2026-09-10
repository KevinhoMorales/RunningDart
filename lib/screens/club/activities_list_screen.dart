import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/activity_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/activity_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/activity_helpers.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';

class ActivitiesListScreen extends StatefulWidget {
  const ActivitiesListScreen({
    super.key,
    this.embedded = false,
  });

  /// Cuando es tab del shell, el AppBar lo pone HomeScreen.
  final bool embedded;

  @override
  State<ActivitiesListScreen> createState() => _ActivitiesListScreenState();
}

class _ActivitiesListScreenState extends State<ActivitiesListScreen> {
  bool _generating = false;

  Future<void> _generateSocialRuns() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final auth = context.read<AuthProvider>();
      final created =
          await context.read<ActivityService>().ensureUpcomingSocialRuns(
                weeksAhead: 4,
                createdBy: auth.user?.id,
              );
      if (!mounted) return;
      AppSnackBar.show(
        context,
        created == 0
            ? 'Los Social Runs de las próximas semanas ya existen.'
            : 'Se crearon $created Social Runs (mar/jue 19:00).',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<ActivityService>();
    final palette = context.palette;
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;

    final body = StreamBuilder<List<ActivityModel>>(
      stream: service.watchUpcomingActivities(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final activities = snapshot.data ?? const <ActivityModel>[];
        if (activities.isEmpty) {
          return HapticRefreshIndicator(
            onRefresh: () async {
              // El stream se actualiza solo; el gesto confirma que no hay filas.
              await Future<void>.delayed(const Duration(milliseconds: 400));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
                EmptyStateCard(
                  icon: Icons.directions_run_rounded,
                  message: 'Aún no hay Social Runs',
                  subtitle: isAdmin
                      ? 'Los martes y jueves son el corazón del club. '
                          'Genera las próximas semanas o crea una actividad '
                          'para que la comunidad pueda confirmar.'
                      : 'Aquí verás los Social Runs de martes y jueves. '
                          'Cuando el club publique el próximo, podrás '
                          'confirmar y sumar a la Liga. Desliza para actualizar.',
                  actionLabel: isAdmin
                      ? (_generating
                          ? 'Generando…'
                          : 'Generar Social Runs')
                      : null,
                  onAction: isAdmin
                      ? AppHaptics.wrap(_generateSocialRuns)
                      : null,
                ),
                if (isAdmin) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: TextButton(
                      onPressed: AppHaptics.wrap(
                        () => context.push('/admin/activities/new'),
                      ),
                      child: const Text('Crear actividad'),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return HapticRefreshIndicator(
          onRefresh: () async {
            await Future<void>.delayed(const Duration(milliseconds: 300));
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
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
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: palette.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color:
                                palette.accentPrimary.withValues(alpha: 0.12),
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
          ),
        );
      },
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Actividades'),
      body: body,
    );
  }
}
