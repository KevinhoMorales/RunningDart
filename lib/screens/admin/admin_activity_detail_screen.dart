import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/activity_checkin_model.dart';
import '../../models/activity_model.dart';
import '../../models/activity_rsvp_model.dart';
import '../../providers/admin_provider.dart';
import '../../services/activity_service.dart';
import '../../services/qr_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/activity_helpers.dart';
import '../../utils/app_haptics.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';

class AdminActivityDetailScreen extends StatefulWidget {
  const AdminActivityDetailScreen({super.key, required this.activityId});

  final String activityId;

  @override
  State<AdminActivityDetailScreen> createState() =>
      _AdminActivityDetailScreenState();
}

class _AdminActivityDetailScreenState extends State<AdminActivityDetailScreen> {
  final _qrService = QRService();
  String? _token;
  bool _loadingToken = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    setState(() => _loadingToken = true);
    try {
      final token =
          await context.read<ActivityService>().getCheckInToken(widget.activityId);
      if (!mounted) return;
      setState(() => _token = token);
    } catch (_) {
      // Admin without secret yet.
    } finally {
      if (mounted) setState(() => _loadingToken = false);
    }
  }

  Future<void> _toggleCheckIn(ActivityModel activity, bool enabled) async {
    setState(() => _busy = true);
    try {
      final service = context.read<ActivityService>();
      await service.setCheckInWindow(
        activityId: activity.id,
        enabled: enabled,
        opensAt: enabled
            ? (activity.checkInOpensAt ??
                ActivityHelpers.defaultCheckInOpensAt(activity.startsAt))
            : activity.checkInOpensAt,
        closesAt: enabled
            ? (activity.checkInClosesAt ??
                ActivityHelpers.defaultCheckInClosesAt(activity.startsAt))
            : activity.checkInClosesAt,
        rotateToken: enabled && (_token == null || _token!.isEmpty),
      );
      await _loadToken();
      if (!mounted) return;
      AppSnackBar.show(
        context,
        enabled ? 'Check-in habilitado.' : 'Check-in deshabilitado.',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markCheckIn(String userId) async {
    setState(() => _busy = true);
    try {
      final result = await context.read<ActivityService>().adminMarkCheckIn(
            activityId: widget.activityId,
            userId: userId,
          );
      if (!mounted) return;
      AppSnackBar.show(
        context,
        result.message ?? 'Asistencia marcada.',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeCheckIn(String userId) async {
    setState(() => _busy = true);
    try {
      await context.read<ActivityService>().adminRemoveCheckIn(
            activityId: widget.activityId,
            userId: userId,
          );
      if (!mounted) return;
      AppSnackBar.show(context, 'Check-in eliminado.');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manualUserPick() async {
    final admin = context.read<AdminProvider>();
    if (!admin.isListening) {
      admin.startListening();
    }
    if (!mounted) return;
    // Esperar un momento a que llegue la primera página.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final users = admin.users;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'Marcar asistencia manual',
                    style: AppTypography.sectionTitle(context),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        title: Text(user.displayName),
                        subtitle: Text(user.email),
                        onTap: () => Navigator.pop(context, user.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) {
      await _markCheckIn(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<ActivityService>();
    final palette = context.palette;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Gestionar actividad',
        actions: [
          IconButton(
            onPressed: AppHaptics.wrap(
              () => context.push('/admin/activities/${widget.activityId}/edit'),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: StreamBuilder<ActivityModel?>(
        stream: service.watchActivity(widget.activityId),
        builder: (context, activitySnap) {
          final activity = activitySnap.data;
          if (activity == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(activity.title, style: AppTypography.sectionTitle(context)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                ActivityHelpers.formatActivityWhen(activity.startsAt),
                style: AppTypography.muted(context),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${activity.confirmedCount} confirmados · '
                '${activity.checkedInCount} con check-in',
                style: AppTypography.body(context, weight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.lg),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Habilitar check-in QR'),
                subtitle: Text(
                  activity.isCheckInWindowOpen()
                      ? 'Ventana abierta ahora'
                      : 'Ventana según horario configurado',
                ),
                value: activity.checkInEnabled,
                onChanged: _busy
                    ? null
                    : AppHaptics.wrapValue(
                        (v) => _toggleCheckIn(activity, v),
                      ),
              ),
              if (activity.checkInEnabled) ...[
                const SizedBox(height: AppSpacing.md),
                if (_loadingToken)
                  const Center(child: CircularProgressIndicator())
                else if (_token != null && _token!.isNotEmpty)
                  Column(
                    children: [
                      Text(
                        'Muestra este QR en el lugar para el check-in',
                        style: AppTypography.body(context),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(color: palette.cardBorder),
                        ),
                        child: QrImageView(
                          data: _qrService.generateActivityCheckInPayload(
                            activityId: activity.id,
                            token: _token!,
                          ),
                          size: 220,
                        ),
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: _busy ? null : AppHaptics.wrap(_manualUserPick),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Marcar asistencia manual'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Confirmados',
                style: AppTypography.body(context, weight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              StreamBuilder<List<ActivityRsvpModel>>(
                stream: service.watchConfirmedRsvps(widget.activityId),
                builder: (context, snap) {
                  final rsvps = snap.data ?? const <ActivityRsvpModel>[];
                  if (rsvps.isEmpty) {
                    return Text(
                      'Nadie ha confirmado todavía.',
                      style: AppTypography.muted(context),
                    );
                  }
                  return Column(
                    children: rsvps
                        .map(
                          (r) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(r.displayName),
                            trailing: IconButton(
                              tooltip: 'Marcar check-in',
                              onPressed: _busy
                                  ? null
                                  : AppHaptics.wrap(() => _markCheckIn(r.userId)),
                              icon: const Icon(Icons.how_to_reg_rounded),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Check-ins',
                style: AppTypography.body(context, weight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              StreamBuilder<List<ActivityCheckInModel>>(
                stream: service.watchCheckIns(widget.activityId),
                builder: (context, snap) {
                  final checkIns =
                      snap.data ?? const <ActivityCheckInModel>[];
                  if (checkIns.isEmpty) {
                    return Text(
                      'Sin check-ins registrados.',
                      style: AppTypography.muted(context),
                    );
                  }
                  return Column(
                    children: checkIns
                        .map(
                          (c) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(c.displayName),
                            subtitle: Text(
                              '${c.method.displayName}'
                              '${c.pointsAwarded > 0 ? ' · +${c.pointsAwarded} pts' : ''}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Quitar check-in',
                              onPressed: _busy
                                  ? null
                                  : AppHaptics.wrap(
                                      () => _removeCheckIn(c.userId),
                                    ),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                          ),
                        )
                        .toList(),
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
