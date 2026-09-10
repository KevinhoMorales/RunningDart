import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/monthly_challenge_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/challenge_service.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../utils/league_helpers.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/modern_text_field.dart';

class AdminChallengeFormScreen extends StatefulWidget {
  const AdminChallengeFormScreen({super.key, this.challengeId});

  final String? challengeId;
  bool get isEditing => challengeId != null;

  @override
  State<AdminChallengeFormScreen> createState() =>
      _AdminChallengeFormScreenState();
}

class _AdminChallengeFormScreenState extends State<AdminChallengeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetController = TextEditingController(text: '8');
  final _spotsController = TextEditingController(text: '10');
  final _pointsController = TextEditingController(text: '20');
  final _badgeNameController = TextEditingController(text: 'Insignia del mes');
  final _badgeDescController = TextEditingController();

  ChallengeGoalType _goalType = ChallengeGoalType.checkIns;
  ChallengeStatus _status = ChallengeStatus.draft;
  late DateTime _startsAt;
  late DateTime _endsAt;
  bool _loading = false;
  MonthlyChallengeModel? _existing;

  @override
  void initState() {
    super.initState();
    final now = LeagueHelpers.ecuadorNow();
    _startsAt = DateTime(now.year, now.month, 1);
    _endsAt = DateTime(now.year, now.month + 1, 0, 23, 59);
    if (widget.isEditing) {
      _load();
    } else {
      _nameController.text =
          'Reto ${LeagueHelpers.periodLabel(LeagueHelpers.currentPeriodKey())}';
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final challenge =
        await context.read<ChallengeService>().getChallenge(widget.challengeId!);
    if (!mounted) return;
    if (challenge != null) {
      _existing = challenge;
      _nameController.text = challenge.name;
      _descriptionController.text = challenge.description ?? '';
      _targetController.text = '${challenge.goalTarget}';
      _spotsController.text = '${challenge.rewardSpots}';
      _pointsController.text = '${challenge.completionPoints}';
      _badgeNameController.text = challenge.badge.name;
      _badgeDescController.text = challenge.badge.description ?? '';
      _goalType = challenge.goalType;
      _status = challenge.status;
      _startsAt = challenge.startsAt;
      _endsAt = challenge.endsAt;
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _spotsController.dispose();
    _pointsController.dispose();
    _badgeNameController.dispose();
    _badgeDescController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      helpText: 'Inicio del reto',
    );
    if (date == null || !mounted) return;
    setState(() => _startsAt = DateTime(date.year, date.month, date.day));
  }

  Future<void> _pickEnd() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endsAt,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      helpText: 'Fin del reto',
    );
    if (date == null || !mounted) return;
    setState(
      () => _endsAt = DateTime(date.year, date.month, date.day, 23, 59),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final target = int.tryParse(_targetController.text.trim());
    final spots = int.tryParse(_spotsController.text.trim());
    final points = int.tryParse(_pointsController.text.trim());
    if (target == null || target <= 0) {
      AppSnackBar.showError(context, 'La meta debe ser mayor a 0.');
      return;
    }
    if (spots == null || spots < 0) {
      AppSnackBar.showError(context, 'Reward Spots inválidos.');
      return;
    }
    if (points == null || points < 0) {
      AppSnackBar.showError(context, 'Puntos por completar inválidos.');
      return;
    }
    if (_endsAt.isBefore(_startsAt)) {
      AppSnackBar.showError(context, 'El fin debe ser después del inicio.');
      return;
    }

    setState(() => _loading = true);
    try {
      final service = context.read<ChallengeService>();
      final auth = context.read<AuthProvider>();
      final badge = ChallengeBadgeMeta(
        name: _badgeNameController.text.trim().isEmpty
            ? 'Insignia del mes'
            : _badgeNameController.text.trim(),
        description: _badgeDescController.text.trim(),
      );
      final periodKey = LeagueHelpers.periodKeyFor(_startsAt);

      if (widget.isEditing && _existing != null) {
        await service.updateChallenge(
          _existing!.copyWith(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            clearDescription: _descriptionController.text.trim().isEmpty,
            status: _status,
            goalType: _goalType,
            goalTarget: target,
            startsAt: _startsAt,
            endsAt: _endsAt,
            periodKey: periodKey,
            rewardSpots: spots,
            completionPoints: points,
            badge: badge,
          ),
        );
      } else {
        final id = await service.createChallenge(
          MonthlyChallengeModel(
            id: '',
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            status: _status,
            goalType: _goalType,
            goalTarget: target,
            startsAt: _startsAt,
            endsAt: _endsAt,
            periodKey: periodKey,
            rewardSpots: spots,
            completionPoints: points,
            badge: badge,
            createdBy: auth.user?.id,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        if (!mounted) return;
        context.pop();
        context.push('/admin/challenges/$id');
        AppSnackBar.show(context, 'Reto creado.');
        return;
      }
      if (!mounted) return;
      AppSnackBar.show(context, 'Reto guardado.');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.isEditing ? 'Editar reto' : 'Nuevo reto',
      ),
      body: _loading && widget.isEditing && _existing == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  ModernTextField(
                    controller: _nameController,
                    labelText: 'Nombre',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ModernTextField(
                    controller: _descriptionController,
                    labelText: 'Descripción',
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<ChallengeGoalType>(
                    // ignore: deprecated_member_use
                    value: _goalType,
                    decoration: const InputDecoration(labelText: 'Tipo de meta'),
                    items: ChallengeGoalType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _goalType = v);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ModernTextField(
                    controller: _targetController,
                    labelText: _goalType.targetHint(),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Inicio'),
                    subtitle: Text(
                      '${_startsAt.day.toString().padLeft(2, '0')}/'
                      '${_startsAt.month.toString().padLeft(2, '0')}/'
                      '${_startsAt.year}',
                    ),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: AppHaptics.wrap(_pickStart),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fin'),
                    subtitle: Text(
                      '${_endsAt.day.toString().padLeft(2, '0')}/'
                      '${_endsAt.month.toString().padLeft(2, '0')}/'
                      '${_endsAt.year}',
                    ),
                    trailing: const Icon(Icons.event_outlined),
                    onTap: AppHaptics.wrap(_pickEnd),
                  ),
                  ModernTextField(
                    controller: _spotsController,
                    labelText: 'Reward Spots (premios físicos)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ModernTextField(
                    controller: _pointsController,
                    labelText: 'Puntos al completar (default 20)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Insignia digital',
                    style: AppTypography.body(context, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ModernTextField(
                    controller: _badgeNameController,
                    labelText: 'Nombre de la insignia',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ModernTextField(
                    controller: _badgeDescController,
                    labelText: 'Descripción de la insignia',
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<ChallengeStatus>(
                    // ignore: deprecated_member_use
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: ChallengeStatus.values
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
                    },
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Activo = visible y evaluado en check-ins. '
                    'Cerrado = deja de contar progreso nuevo.',
                    style: AppTypography.caption(context),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _loading ? null : AppHaptics.wrap(_save),
                    child: Text(widget.isEditing ? 'Guardar' : 'Crear'),
                  ),
                ],
              ),
            ),
    );
  }
}
