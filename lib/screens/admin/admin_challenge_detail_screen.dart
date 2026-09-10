import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/challenge_progress_model.dart';
import '../../models/monthly_challenge_model.dart';
import '../../services/challenge_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../utils/league_helpers.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';

class AdminChallengeDetailScreen extends StatefulWidget {
  const AdminChallengeDetailScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  State<AdminChallengeDetailScreen> createState() =>
      _AdminChallengeDetailScreenState();
}

class _AdminChallengeDetailScreenState
    extends State<AdminChallengeDetailScreen> {
  List<ChallengeProgressModel> _finishers = const [];
  final Set<String> _selectedWinners = {};
  bool _loadingFinishers = true;
  bool _busy = false;
  MonthlyChallengeModel? _challenge;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final service = context.read<ChallengeService>();
    final challenge = await service.getChallenge(widget.challengeId);
    if (!mounted) return;
    setState(() => _challenge = challenge);
    await _reloadFinishers();
  }

  Future<void> _reloadFinishers() async {
    final challenge = _challenge;
    if (challenge == null) return;
    setState(() => _loadingFinishers = true);
    try {
      final period = challenge.periodKey ??
          LeagueHelpers.periodKeyFor(challenge.startsAt);
      final rows = await context.read<ChallengeService>().finishersWithLeagueRank(
            challengeId: challenge.id,
            periodKey: period,
          );
      if (!mounted) return;
      setState(() {
        _finishers = rows;
        _selectedWinners
          ..clear()
          ..addAll(rows.where((r) => r.isWinner).map((r) => r.userId));
        _loadingFinishers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFinishers = false);
      AppSnackBar.showError(context, e.toString());
    }
  }

  Future<void> _setStatus(ChallengeStatus status) async {
    setState(() => _busy = true);
    try {
      await context.read<ChallengeService>().setChallengeStatus(
            challengeId: widget.challengeId,
            status: status,
          );
      await _bootstrap();
      if (!mounted) return;
      AppSnackBar.show(context, 'Estado: ${status.displayName}');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveWinners() async {
    final challenge = _challenge;
    if (challenge == null) return;
    if (_selectedWinners.length > challenge.rewardSpots) {
      AppSnackBar.showError(
        context,
        'Solo hay ${challenge.rewardSpots} Reward Spots.',
      );
      return;
    }

    // Prefer league order for winner ranks.
    final ordered = _finishers
        .where((f) => _selectedWinners.contains(f.userId))
        .map((f) => f.userId)
        .toList(growable: false);

    setState(() => _busy = true);
    try {
      await context.read<ChallengeService>().setWinners(
            challengeId: challenge.id,
            winnerUserIds: ordered,
          );
      await _reloadFinishers();
      if (!mounted) return;
      AppSnackBar.show(
        context,
        'Ganadores guardados (${ordered.length}/${challenge.rewardSpots}).',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleWinner(ChallengeProgressModel row) {
    final challenge = _challenge;
    if (challenge == null) return;
    setState(() {
      if (_selectedWinners.contains(row.userId)) {
        _selectedWinners.remove(row.userId);
      } else {
        if (_selectedWinners.length >= challenge.rewardSpots) {
          AppSnackBar.showError(
            context,
            'Límite de ${challenge.rewardSpots} Reward Spots.',
          );
          return;
        }
        _selectedWinners.add(row.userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final challenge = _challenge;
    final palette = context.palette;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Reto',
        actions: [
          HapticIconButton(
            onPressed: () =>
                context.push('/admin/challenges/${widget.challengeId}/edit'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar',
          ),
        ],
      ),
      body: challenge == null
          ? const Center(child: CircularProgressIndicator())
          : HapticRefreshIndicator(
              onRefresh: _reloadFinishers,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Text(
                    challenge.name,
                    style: AppTypography.sectionTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${challenge.status.displayName} · ${challenge.goalSummary}',
                    style: AppTypography.muted(context),
                  ),
                  if (challenge.description != null &&
                      challenge.description!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(challenge.description!, style: AppTypography.body(context)),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Insignia: ${challenge.badge.name} · '
                    'Reward Spots: ${challenge.rewardSpots} · '
                    '+${challenge.completionPoints} pts al completar',
                    style: AppTypography.caption(context),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      if (challenge.status != ChallengeStatus.active)
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : AppHaptics.wrap(
                                  () => _setStatus(ChallengeStatus.active),
                                ),
                          child: const Text('Activar'),
                        ),
                      if (challenge.status != ChallengeStatus.closed)
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : AppHaptics.wrap(
                                  () => _setStatus(ChallengeStatus.closed),
                                ),
                          child: const Text('Cerrar'),
                        ),
                      if (challenge.status != ChallengeStatus.draft)
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : AppHaptics.wrap(
                                  () => _setStatus(ChallengeStatus.draft),
                                ),
                          child: const Text('A borrador'),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Finalistas (${_finishers.length})',
                    style: AppTypography.body(
                      context,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Ordenados por puntos de Liga del periodo. '
                    'Marca hasta ${challenge.rewardSpots} ganadores de premio físico. '
                    'Empates en el último spot: resuélvelos tú (sin sorteo). '
                    'Oficial = perk pendiente (punto 7).',
                    style: AppTypography.caption(
                      context,
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_loadingFinishers)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_finishers.isEmpty)
                    Text(
                      'Aún nadie completó el reto.',
                      style: AppTypography.muted(context),
                    )
                  else ...[
                    ..._finishers.map((row) {
                      final selected = _selectedWinners.contains(row.userId);
                      final modality = row.membershipModality;
                      final isOfficial = modality == 'official' ||
                          modality == 'proTeam';
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: selected,
                        onChanged: _busy
                            ? null
                            : AppHaptics.wrapValue((_) => _toggleWinner(row)),
                        title: Text(row.displayName),
                        subtitle: Text(
                          [
                            'Liga #${row.leagueRank ?? '—'} · '
                                '${row.leaguePoints ?? 0} pts',
                            if (isOfficial) 'Oficial · perk',
                            if (row.qualifiesForOfficialPerk && selected)
                              'Marcado para perk',
                          ].join(' · '),
                        ),
                        secondary: selected
                            ? Icon(
                                Icons.card_giftcard_rounded,
                                color: palette.accentPrimary,
                              )
                            : null,
                      );
                    }),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _busy ? null : AppHaptics.wrap(_saveWinners),
                      child: Text(
                        'Guardar ganadores '
                        '(${_selectedWinners.length}/${challenge.rewardSpots})',
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
