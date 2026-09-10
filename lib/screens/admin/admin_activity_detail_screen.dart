import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/activity_checkin_model.dart';
import '../../models/activity_model.dart';
import '../../models/activity_rsvp_model.dart';
import '../../models/user_model.dart';
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
import '../../widgets/haptic_controls.dart';

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

  String? _payloadFor(ActivityModel activity) {
    if (_token == null || _token!.isEmpty) {
      return null;
    }
    return _qrService.generateActivityCheckInPayload(
      activityId: activity.id,
      token: _token!,
    );
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

  Future<void> _rotateToken(ActivityModel activity) async {
    setState(() => _busy = true);
    try {
      await context.read<ActivityService>().setCheckInWindow(
            activityId: activity.id,
            enabled: activity.checkInEnabled,
            opensAt: activity.checkInOpensAt,
            closesAt: activity.checkInClosesAt,
            rotateToken: true,
          );
      await _loadToken();
      if (!mounted) return;
      AppSnackBar.show(context, 'QR renovado. El anterior ya no sirve.');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyPayload(ActivityModel activity) async {
    final payload = _payloadFor(activity);
    if (payload == null) {
      AppSnackBar.showError(context, 'Activa el check-in para generar el QR.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    AppSnackBar.show(context, 'Código de check-in copiado.');
  }

  Future<void> _showQrFullscreen(ActivityModel activity) async {
    final payload = _payloadFor(activity);
    if (payload == null) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(AppSpacing.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'QR de check-in',
                  style: AppTypography.sectionTitle(dialogContext),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  activity.title,
                  textAlign: TextAlign.center,
                  style: AppTypography.muted(dialogContext),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: QrImageView(data: payload, size: 280),
                ),
                const SizedBox(height: AppSpacing.md),
                HapticTextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),
        );
      },
    );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar check-in'),
        content: const Text(
          'Se eliminará la asistencia y se revertirán los puntos de este check-in.',
        ),
        actions: [
          HapticTextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          HapticFilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

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

  Future<void> _manualUserPick({
    required Set<String> alreadyCheckedIn,
  }) async {
    final admin = context.read<AdminProvider>();
    if (!admin.isListening) {
      admin.startListening();
    }
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _ManualAttendancePicker(
          users: admin.users,
          alreadyCheckedIn: alreadyCheckedIn,
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
          HapticIconButton(
            onPressed: () =>
                context.push('/admin/activities/${widget.activityId}/edit'),
            tooltip: 'Editar',
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

          return StreamBuilder<List<ActivityCheckInModel>>(
            stream: service.watchCheckIns(widget.activityId),
            builder: (context, checkInSnap) {
              final checkIns =
                  checkInSnap.data ?? const <ActivityCheckInModel>[];
              final checkedInIds =
                  checkIns.map((c) => c.userId).toSet();

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Text(
                    activity.title,
                    style: AppTypography.sectionTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    ActivityHelpers.formatActivityWhen(activity.startsAt),
                    style: AppTypography.muted(context),
                  ),
                  if (activity.venue != null &&
                      activity.venue!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      activity.venue!,
                      style: AppTypography.caption(
                        context,
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _StatChip(
                        label:
                            '${activity.confirmedCount} confirmados',
                        icon: Icons.how_to_reg_outlined,
                      ),
                      _StatChip(
                        label: '${activity.checkedInCount} check-in',
                        icon: Icons.qr_code_2_rounded,
                      ),
                      if (activity.hasCapacity)
                        _StatChip(
                          label: 'Cupo ${activity.capacity}',
                          icon: Icons.groups_outlined,
                        ),
                      if (activity.pointsOverride != null)
                        _StatChip(
                          label: '${activity.pointsOverride} pts',
                          icon: Icons.stars_outlined,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Ventana de check-in',
                    style: AppTypography.body(
                      context,
                      weight: FontWeight.w700,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Habilitar check-in QR'),
                    subtitle: Text(
                      activity.checkInEnabled
                          ? (activity.isCheckInWindowOpen()
                              ? 'Ventana abierta ahora'
                              : 'Habilitado · fuera de horario')
                          : 'Deshabilitado · los socios no pueden escanear',
                    ),
                    value: activity.checkInEnabled,
                    onChanged: _busy
                        ? null
                        : AppHaptics.wrapValue(
                            (v) => _toggleCheckIn(activity, v),
                          ),
                  ),
                  if (activity.checkInOpensAt != null ||
                      activity.checkInClosesAt != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        [
                          if (activity.checkInOpensAt != null)
                            'Abre: ${ActivityHelpers.formatActivityWhen(activity.checkInOpensAt!)}',
                          if (activity.checkInClosesAt != null)
                            'Cierra: ${ActivityHelpers.formatActivityWhen(activity.checkInClosesAt!)}',
                        ].join('\n'),
                        style: AppTypography.caption(
                          context,
                          color: palette.textMuted,
                        ),
                      ),
                    ),
                  if (activity.checkInEnabled) ...[
                    if (_loadingToken)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_token != null && _token!.isNotEmpty) ...[
                      Text(
                        'Muestra este QR en el lugar. Los socios lo escanean '
                        'desde la app (detalle de la actividad).',
                        style: AppTypography.body(context),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: Material(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          child: InkWell(
                            onTap: AppHaptics.wrap(
                              () => _showQrFullscreen(activity),
                            ),
                            enableFeedback: false,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd,
                                ),
                                border: Border.all(color: palette.cardBorder),
                              ),
                              child: QrImageView(
                                data: _payloadFor(activity)!,
                                size: 220,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Toca el QR para verlo a pantalla completa',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption(
                          context,
                          color: palette.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : AppHaptics.wrap(
                                      () => _copyPayload(activity),
                                    ),
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('Copiar código'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : AppHaptics.wrap(
                                      () => _rotateToken(activity),
                                    ),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Renovar QR'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : AppHaptics.wrap(
                            () => _manualUserPick(
                              alreadyCheckedIn: checkedInIds,
                            ),
                          ),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Marcar asistencia manual'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Confirmados (${activity.confirmedCount})',
                    style: AppTypography.body(
                      context,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Quién dijo “Voy” · marca check-in si llegaron sin escanear.',
                    style: AppTypography.caption(
                      context,
                      color: palette.textMuted,
                    ),
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
                        children: rsvps.map((r) {
                          final done = checkedInIds.contains(r.userId);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(r.displayName),
                            subtitle: Text(
                              done ? 'Ya hizo check-in' : 'Confirmado',
                            ),
                            trailing: done
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: palette.accentPrimary,
                                  )
                                : HapticIconButton(
                                    tooltip: 'Marcar check-in',
                                    onPressed: _busy
                                        ? null
                                        : () => _markCheckIn(r.userId),
                                    icon: const Icon(
                                      Icons.how_to_reg_rounded,
                                    ),
                                  ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Asistencia real (${checkIns.length})',
                    style: AppTypography.body(
                      context,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Check-ins válidos (QR o manual). Quita si hay un error.',
                    style: AppTypography.caption(
                      context,
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (checkIns.isEmpty)
                    Text(
                      'Sin check-ins registrados.',
                      style: AppTypography.muted(context),
                    )
                  else
                    Column(
                      children: checkIns
                          .map(
                            (c) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(c.displayName),
                              subtitle: Text(
                                '${c.method.displayName}'
                                '${c.pointsAwarded > 0 ? ' · +${c.pointsAwarded} pts' : ''}',
                              ),
                              trailing: HapticIconButton(
                                tooltip: 'Quitar check-in',
                                onPressed: _busy
                                    ? null
                                    : () => _removeCheckIn(c.userId),
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.chipBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: palette.textMuted),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.caption(context)),
        ],
      ),
    );
  }
}

class _ManualAttendancePicker extends StatefulWidget {
  const _ManualAttendancePicker({
    required this.users,
    required this.alreadyCheckedIn,
  });

  final List<UserModel> users;
  final Set<String> alreadyCheckedIn;

  @override
  State<_ManualAttendancePicker> createState() =>
      _ManualAttendancePickerState();
}

class _ManualAttendancePickerState extends State<_ManualAttendancePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.users.where((user) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) {
        return true;
      }
      return user.displayName.toLowerCase().contains(q) ||
          user.email.toLowerCase().contains(q);
    }).toList(growable: false);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Marcar asistencia manual',
                    style: AppTypography.sectionTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Buscar socio',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        widget.users.isEmpty
                            ? 'Cargando socios… Abre Usuarios si sigue vacío.'
                            : 'Sin coincidencias.',
                        style: AppTypography.muted(context),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final user = filtered[index];
                        final done =
                            widget.alreadyCheckedIn.contains(user.id);
                        return ListTile(
                          title: Text(user.displayName),
                          subtitle: Text(
                            done ? '${user.email} · ya check-in' : user.email,
                          ),
                          enabled: !done,
                          onTap: done
                              ? null
                              : AppHaptics.wrap(
                                  () => Navigator.pop(context, user.id),
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
