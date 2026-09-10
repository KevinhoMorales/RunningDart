import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';

class AdminActivitiesTab extends StatefulWidget {
  const AdminActivitiesTab({super.key});

  @override
  State<AdminActivitiesTab> createState() => _AdminActivitiesTabState();
}

class _AdminActivitiesTabState extends State<AdminActivitiesTab> {
  bool _generating = false;
  bool _savingPoints = false;
  bool _loadingPoints = true;
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
    setState(() => _loadingPoints = true);
    try {
      final config = await context.read<ActivityService>().getPointsConfig();
      if (!mounted) return;
      _checkInPointsController.text = '${config.checkInPoints}';
      _bonusController.text = '${config.weeklyDoubleBonus}';
    } finally {
      if (mounted) setState(() => _loadingPoints = false);
    }
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

  Future<void> _savePointsConfig() async {
    final checkIn = int.tryParse(_checkInPointsController.text.trim());
    final bonus = int.tryParse(_bonusController.text.trim());
    if (checkIn == null || checkIn < 0) {
      AppSnackBar.showError(
        context,
        'Puntos por check-in: usa un número ≥ 0 (recomendado 10).',
      );
      return;
    }
    if (bonus == null || bonus < 0) {
      AppSnackBar.showError(
        context,
        'Bonus mar+jue: usa un número ≥ 0 (recomendado 5).',
      );
      return;
    }

    setState(() => _savingPoints = true);
    try {
      await context.read<ActivityService>().savePointsConfig(
            PointsConfigModel(
              checkInPoints: checkIn,
              weeklyDoubleBonus: bonus,
            ),
          );
      if (!mounted) return;
      AppSnackBar.show(
        context,
        'Puntos guardados (+$checkIn check-in'
        '${bonus > 0 ? ', +$bonus bonus mar+jue' : ''}).',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _savingPoints = false);
    }
  }

  Future<void> _resetPointsDefaults() async {
    setState(() {
      _checkInPointsController.text =
          '${PointsConfigModel.defaultCheckInPoints}';
      _bonusController.text =
          '${PointsConfigModel.defaultWeeklyDoubleBonus}';
    });
    await _savePointsConfig();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<ActivityService>();
    final palette = context.palette;

    return StreamBuilder<List<ActivityModel>>(
      stream: service.watchAllActivitiesForAdmin(),
      builder: (context, snapshot) {
        final activities = snapshot.data ?? const <ActivityModel>[];
        final loadingList = snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData;

        return HapticRefreshIndicator(
          onRefresh: _loadPointsConfig,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Ciclo de asistencia',
                        style: AppTypography.sectionTitle(context),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Crea Social Runs, abre el QR de check-in y corrige '
                        'asistencias. La liga del mes suma solo check-ins.',
                        style: AppTypography.muted(context),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _generating
                                  ? null
                                  : AppHaptics.wrap(_generateSocialRuns),
                              icon: _generating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.auto_awesome_rounded),
                              label: const Text('Generar mar/jue'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: AppHaptics.wrap(
                                () => context.push('/admin/league'),
                              ),
                              icon: const Icon(Icons.emoji_events_outlined),
                              label: const Text('Liga del mes'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _PointsConfigCard(
                        loading: _loadingPoints,
                        saving: _savingPoints,
                        checkInController: _checkInPointsController,
                        bonusController: _bonusController,
                        onSave: _savePointsConfig,
                        onResetDefaults: _resetPointsDefaults,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Próximas y pasadas',
                        style: AppTypography.body(
                          context,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Toca una actividad para QR, confirmados y asistencia.',
                        style: AppTypography.caption(
                          context,
                          color: palette.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ),
              ),
              if (loadingList)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (activities.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: EmptyStateCard(
                      icon: Icons.directions_run_rounded,
                      message: 'Aún no hay actividades',
                      subtitle:
                          'Genera los Social Runs de martes y jueves '
                          'o crea una actividad con el botón +.',
                      actionLabel: 'Generar Social Runs',
                      onAction: _generating ? null : _generateSocialRuns,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
                  sliver: SliverList.separated(
                    itemCount: activities.length,
                    separatorBuilder: (_, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      return _ActivityAdminTile(activity: activities[index]);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PointsConfigCard extends StatelessWidget {
  const _PointsConfigCard({
    required this.loading,
    required this.saving,
    required this.checkInController,
    required this.bonusController,
    required this.onSave,
    required this.onResetDefaults,
  });

  final bool loading;
  final bool saving;
  final TextEditingController checkInController;
  final TextEditingController bonusController;
  final VoidCallback onSave;
  final VoidCallback onResetDefaults;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Puntos (club_settings)',
            style: AppTypography.body(context, weight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Valores por defecto: '
            '+${PointsConfigModel.defaultCheckInPoints} por check-in, '
            '+${PointsConfigModel.defaultWeeklyDoubleBonus} si hace mar+jue '
            'en la misma semana. Comunidad y Oficial suman igual.',
            style: AppTypography.caption(context, color: palette.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            TextField(
              controller: checkInController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Puntos por check-in',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: bonusController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Bonus mar + jue (misma semana)',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                TextButton(
                  onPressed: saving ? null : AppHaptics.wrap(onResetDefaults),
                  child: const Text('Restablecer 10 / 5'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: saving ? null : AppHaptics.wrap(onSave),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar puntos'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityAdminTile extends StatelessWidget {
  const _ActivityAdminTile({required this.activity});

  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.cardBackground,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: AppHaptics.wrap(
          () => context.push('/admin/activities/${activity.id}'),
        ),
        enableFeedback: false,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
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
                  if (activity.checkInEnabled)
                    _Badge(
                      label: activity.isCheckInWindowOpen()
                          ? 'QR abierto'
                          : 'QR on',
                      emphasize: activity.isCheckInWindowOpen(),
                    )
                  else if (!activity.isPublished)
                    const _Badge(label: 'Borrador'),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                ActivityHelpers.formatActivityWhen(activity.startsAt),
                style: AppTypography.caption(
                  context,
                  color: palette.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  activity.type.displayName,
                  '${activity.confirmedCount} confirmados',
                  '${activity.checkedInCount} check-in',
                  if (activity.hasCapacity) 'cupo ${activity.capacity}',
                ].join(' · '),
                style: AppTypography.caption(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.emphasize = false});

  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: emphasize
            ? palette.accentPrimary.withValues(alpha: 0.15)
            : palette.chipBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Text(
        label,
        style: AppTypography.caption(
          context,
          color: emphasize ? palette.accentPrimary : palette.textMuted,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
