import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/activity_model.dart';
import '../../models/points_config_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/activity_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/activity_helpers.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/app_snackbar.dart';

class AdminActivitiesTab extends StatefulWidget {
  const AdminActivitiesTab({super.key});

  @override
  State<AdminActivitiesTab> createState() => _AdminActivitiesTabState();
}

class _AdminActivitiesTabState extends State<AdminActivitiesTab> {
  bool _generating = false;
  bool _savingPoints = false;
  final _checkInPointsController = TextEditingController(
    text: '${PointsConfigModel.defaultCheckInPoints}',
  );
  final _bonusController = TextEditingController(
    text: '${PointsConfigModel.defaultWeeklyDoubleBonus}',
  );

  @override
  void initState() {
    super.initState();
    _loadPointsConfig();
  }

  Future<void> _loadPointsConfig() async {
    final config = await context.read<ActivityService>().getPointsConfig();
    if (!mounted) return;
    _checkInPointsController.text = '${config.checkInPoints}';
    _bonusController.text = '${config.weeklyDoubleBonus}';
  }

  @override
  void dispose() {
    _checkInPointsController.dispose();
    _bonusController.dispose();
    super.dispose();
  }

  Future<void> _generateSocialRuns() async {
    setState(() => _generating = true);
    try {
      final auth = context.read<AuthProvider>();
      final created = await context.read<ActivityService>().ensureUpcomingSocialRuns(
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

  Future<void> _savePointsConfig() async {
    setState(() => _savingPoints = true);
    try {
      final checkIn =
          int.tryParse(_checkInPointsController.text.trim()) ?? 10;
      final bonus = int.tryParse(_bonusController.text.trim()) ?? 5;
      await context.read<ActivityService>().savePointsConfig(
            PointsConfigModel(
              checkInPoints: checkIn,
              weeklyDoubleBonus: bonus,
            ),
          );
      if (!mounted) return;
      AppSnackBar.show(context, 'Puntos guardados.');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _savingPoints = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<ActivityService>();
    final palette = context.palette;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _generating
                    ? null
                    : AppHaptics.wrap(_generateSocialRuns),
                icon: _generating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: const Text('Generar Social Runs (4 semanas)'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: AppHaptics.wrap(
                  () => context.push('/admin/league'),
                ),
                icon: const Icon(Icons.emoji_events_outlined),
                label: const Text('Ver liga del mes'),
              ),
              const SizedBox(height: AppSpacing.sm),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Puntos por check-in',
                  style: AppTypography.body(context, weight: FontWeight.w600),
                ),
                children: [
                  TextField(
                    controller: _checkInPointsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Puntos por check-in',
                    ),
                  ),
                  TextField(
                    controller: _bonusController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Bonus mar+jue misma semana',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _savingPoints
                          ? null
                          : AppHaptics.wrap(_savePointsConfig),
                      child: const Text('Guardar puntos'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ActivityModel>>(
            stream: service.watchAllActivitiesForAdmin(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final activities = snapshot.data ?? const <ActivityModel>[];
              if (activities.isEmpty) {
                return Center(
                  child: Text(
                    'No hay actividades. Genera Social Runs o crea una.',
                    style: AppTypography.muted(context),
                    textAlign: TextAlign.center,
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
                        () => context.push(
                          '/admin/activities/${activity.id}',
                        ),
                      ),
                      enableFeedback: false,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(color: palette.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    activity.title,
                                    style: AppTypography.body(
                                      context,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (!activity.isPublished)
                                  Text(
                                    'Borrador',
                                    style: AppTypography.caption(
                                      context,
                                      color: palette.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ActivityHelpers.formatActivityWhen(
                                activity.startsAt,
                              ),
                              style: AppTypography.caption(
                                context,
                                color: palette.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${activity.confirmedCount} confirmados · '
                              '${activity.checkedInCount} check-in'
                              '${activity.checkInEnabled ? ' · QR activo' : ''}',
                              style: AppTypography.caption(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
