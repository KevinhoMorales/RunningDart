import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/activity_checkin_model.dart';
import '../../models/activity_model.dart';
import '../../models/activity_rsvp_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/activity_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/activity_helpers.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';

class ActivityDetailScreen extends StatefulWidget {
  const ActivityDetailScreen({super.key, required this.activityId});

  final String activityId;

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  bool _busy = false;

  Future<void> _confirm(ActivityService service, AuthProvider auth) async {
    final user = auth.user;
    if (user == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await service.confirmAttendance(
        activityId: widget.activityId,
        userId: user.id,
        displayName: user.displayName,
      );
      if (!mounted) return;
      AppSnackBar.show(context, 'Asistencia confirmada. ¡Te esperamos!');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(ActivityService service, AuthProvider auth) async {
    final user = auth.user;
    if (user == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await service.cancelAttendance(
        activityId: widget.activityId,
        userId: user.id,
        displayName: user.displayName,
      );
      if (!mounted) return;
      AppSnackBar.show(context, 'Cancelaste tu asistencia.');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<ActivityService>();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final palette = context.palette;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Actividad'),
      body: StreamBuilder<ActivityModel?>(
        stream: service.watchActivity(widget.activityId),
        builder: (context, activitySnap) {
          final activity = activitySnap.data;
          if (activitySnap.connectionState == ConnectionState.waiting &&
              activity == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (activity == null) {
            return Center(
              child: Text(
                'No se encontró la actividad.',
                style: AppTypography.muted(context),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                activity.title,
                style: AppTypography.sectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                activity.type.displayName,
                style: AppTypography.caption(
                  context,
                  color: palette.accentPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _InfoRow(
                icon: Icons.schedule_rounded,
                label: ActivityHelpers.formatActivityWhen(activity.startsAt),
              ),
              if (activity.venue != null && activity.venue!.isNotEmpty)
                _InfoRow(
                  icon: Icons.place_outlined,
                  label: [
                    activity.venue!,
                    if (activity.location != null &&
                        activity.location!.isNotEmpty)
                      activity.location!,
                  ].join(' · '),
                ),
              if (activity.description != null &&
                  activity.description!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  activity.description!,
                  style: AppTypography.body(context),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: palette.cardBackground,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: palette.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        value: '${activity.confirmedCount}',
                        label: 'Confirmados',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: palette.cardBorder,
                    ),
                    Expanded(
                      child: _Stat(
                        value: '${activity.checkedInCount}',
                        label: 'Check-in',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (user != null)
                StreamBuilder<ActivityRsvpModel?>(
                  stream: service.watchMyRsvp(
                    activityId: widget.activityId,
                    userId: user.id,
                  ),
                  builder: (context, rsvpSnap) {
                    final confirmed = rsvpSnap.data?.isConfirmed == true;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '¿Vas a venir?',
                          style: AppTypography.body(
                            context,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (confirmed)
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : AppHaptics.wrap(
                                    () => _cancel(service, auth),
                                  ),
                            child: const Text('Cancelar asistencia'),
                          )
                        else
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : AppHaptics.wrap(
                                    () => _confirm(service, auth),
                                  ),
                            child: const Text('Confirmar asistencia'),
                          ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Confirmar no suma puntos. Los puntos se otorgan al '
                          'hacer check-in con QR en el lugar.',
                          style: AppTypography.caption(
                            context,
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: AppSpacing.lg),
              if (user != null)
                StreamBuilder<ActivityCheckInModel?>(
                  stream: service.watchMyCheckIn(
                    activityId: widget.activityId,
                    userId: user.id,
                  ),
                  builder: (context, checkInSnap) {
                    final checkedIn = checkInSnap.data != null;
                    if (checkedIn) {
                      final pts = checkInSnap.data!.pointsAwarded;
                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: palette.accentPrimary.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                        child: Text(
                          pts > 0
                              ? 'Ya registraste tu check-in (+$pts pts).'
                              : 'Ya registraste tu check-in.',
                          style: AppTypography.body(
                            context,
                            weight: FontWeight.w600,
                          ),
                        ),
                      );
                    }

                    final windowOpen = activity.isCheckInWindowOpen();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Check-in',
                          style: AppTypography.body(
                            context,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FilledButton.icon(
                          onPressed: windowOpen
                              ? AppHaptics.wrap(
                                  () => context.push(
                                    '/activities/${widget.activityId}/check-in',
                                  ),
                                )
                              : null,
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: Text(
                            windowOpen
                                ? 'Escanear QR de check-in'
                                : 'Check-in cerrado',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          windowOpen
                              ? 'Escanea el QR del Social Run en Jelen Tenka.'
                              : 'El check-in se habilita cerca de la hora de la actividad.',
                          style: AppTypography.caption(
                            context,
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: palette.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTypography.body(context))),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.sectionTitle(context),
        ),
        Text(
          label,
          style: AppTypography.caption(context),
        ),
      ],
    );
  }
}
