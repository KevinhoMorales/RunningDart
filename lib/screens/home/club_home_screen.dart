import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/activity_model.dart';
import '../../models/training_schedule_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/activity_service.dart';
import '../../services/qr_service.dart';
import '../../services/training_schedule_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/activity_helpers.dart';
import '../../utils/app_haptics.dart';
import '../../utils/membership_helpers.dart';
import '../../utils/schedule_helpers.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/league_home_card.dart';
import '../../widgets/challenge_progress_card.dart';
import '../../widgets/membership_credential_card.dart';
import '../../widgets/membership_upsell_card.dart';

/// Inicio compacto: credencial, próximo Social Run, resumen de Liga y
/// tease de beneficios. Sin feed ni listado largo de noticias.
class ClubHomeScreen extends StatefulWidget {
  const ClubHomeScreen({super.key});

  @override
  State<ClubHomeScreen> createState() => _ClubHomeScreenState();
}

class _ClubHomeScreenState extends State<ClubHomeScreen> {
  final _scheduleService = TrainingScheduleService();
  final _qrService = QRService();
  final _leagueCardKey = GlobalKey<LeagueHomeCardState>();

  TrainingScheduleModel? _schedule;
  ActivityModel? _nextActivity;
  bool _loadingSchedule = true;
  bool _loadingActivity = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSchedule();
      _loadNextActivity();
    });
  }

  Future<void> _loadSchedule() async {
    final schedule = await _scheduleService.getSchedule();
    if (!mounted) {
      return;
    }
    setState(() {
      _schedule = schedule;
      _loadingSchedule = false;
    });
  }

  Future<void> _loadNextActivity() async {
    try {
      final activity = await context.read<ActivityService>().getNextActivity();
      if (!mounted) return;
      setState(() {
        _nextActivity = activity;
        _loadingActivity = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingActivity = false);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _loadSchedule(),
      _loadNextActivity(),
      context.read<AuthProvider>().refreshAccountStatus(),
      _leagueCardKey.currentState?.reload() ?? Future<void>.value(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return HapticRefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          Text(
            'Tu club',
            style: AppTypography.sectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Próximo Social Run, tu liga del mes y beneficios.',
            style: AppTypography.muted(context),
          ),
          const SizedBox(height: AppSpacing.md),
          if (user != null)
            _CredentialBlock(user: user, qrService: _qrService),
          const SizedBox(height: AppSpacing.md),
          _NextActivityCard(
            activity: _nextActivity,
            isLoading: _loadingActivity,
            fallbackSchedule: _schedule,
            fallbackLoading: _loadingSchedule,
            user: user,
          ),
          const SizedBox(height: AppSpacing.md),
          LeagueHomeCard(key: _leagueCardKey),
          const SizedBox(height: AppSpacing.md),
          const ChallengeProgressCard(compact: true),
          const SizedBox(height: AppSpacing.md),
          const _BenefitsTeaseCard(),
        ],
      ),
    );
  }
}

class _BenefitsTeaseCard extends StatelessWidget {
  const _BenefitsTeaseCard();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.cardBackground,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: AppHaptics.wrap(() => context.push('/businesses')),
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
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: palette.accentPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(
                  Icons.storefront_outlined,
                  color: palette.accentPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Beneficios SAINTS',
                      style: AppTypography.body(
                        context,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Marcas aliadas con descuentos para socios.',
                      style: AppTypography.caption(
                        context,
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CredentialBlock extends StatelessWidget {
  const _CredentialBlock({required this.user, required this.qrService});

  final UserModel user;
  final QRService qrService;

  @override
  Widget build(BuildContext context) {
    final canShowQr = user.hasMembershipPrivileges;

    if (!canShowQr) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MembershipUpsellCard(
            message: user.isMembershipExpired
                ? 'Tu membresía SAINTS venció. Contacta a SAINTS para reactivarla y volver a usar beneficios y credencial digital.'
                : MembershipHelpers.credentialLockedMessage(
                    modality: user.membershipModality,
                    isPending: user.isMembershipPending,
                    isExpired: user.isMembershipExpired,
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: AppHaptics.wrap(() => context.push('/membership')),
            icon: const Icon(Icons.badge_outlined, size: 18),
            label: const Text('Ver mi membresía'),
          ),
        ],
      );
    }

    return MembershipCredentialCard(
      user: user,
      qrPayload: qrService.generatePayload(user),
    );
  }
}

class _NextActivityCard extends StatelessWidget {
  const _NextActivityCard({
    required this.activity,
    required this.isLoading,
    required this.fallbackSchedule,
    required this.fallbackLoading,
    required this.user,
  });

  final ActivityModel? activity;
  final bool isLoading;
  final TrainingScheduleModel? fallbackSchedule;
  final bool fallbackLoading;
  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (activity != null) {
      return Material(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: InkWell(
          onTap: AppHaptics.wrap(
            () => context.push('/activities/${activity!.id}'),
          ),
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
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: palette.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
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
                        'Próximo Social Run',
                        style: AppTypography.caption(
                          context,
                          color: palette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ActivityHelpers.formatActivityWhen(activity!.startsAt),
                        style: AppTypography.body(
                          context,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (activity!.venue != null) activity!.venue!,
                          '${activity!.confirmedCount} confirmados',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(
                          context,
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: palette.textMuted),
              ],
            ),
          ),
        ),
      );
    }

    // Fallback al horario CMS mientras no haya actividades generadas.
    return _LegacyNextTrainingCard(
      user: user,
      schedule: fallbackSchedule,
      isLoading: isLoading || fallbackLoading,
    );
  }
}

class _LegacyNextTrainingCard extends StatelessWidget {
  const _LegacyNextTrainingCard({
    required this.user,
    required this.schedule,
    required this.isLoading,
  });

  final UserModel? user;
  final TrainingScheduleModel? schedule;
  final bool isLoading;

  TrainingScheduleSection? _sectionForUser() {
    final sections = schedule?.sections ?? const <TrainingScheduleSection>[];
    if (sections.isEmpty) {
      return null;
    }

    bool matches(TrainingScheduleSection section, String needle) =>
        section.title.toLowerCase().contains(needle);

    final modality = user?.membershipModality.name ?? '';
    if (modality == 'official') {
      for (final section in sections) {
        if (matches(section, 'oficial')) {
          return section;
        }
      }
    } else {
      for (final section in sections) {
        if (matches(section, 'comunidad')) {
          return section;
        }
      }
    }
    return sections.first;
  }

  String? _highlightLine(TrainingScheduleSection section) {
    for (final line in section.lines) {
      final parsed = ScheduleHelpers.parseLine(line);
      if (parsed.isTimeSlot) {
        return parsed.secondary == null || parsed.secondary!.isEmpty
            ? parsed.primary
            : '${parsed.primary} · ${parsed.secondary}';
      }
    }
    return section.lines.isEmpty ? null : section.lines.first;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final section = _sectionForUser();
    final highlight = section == null ? null : _highlightLine(section);
    final venue = schedule?.venue;

    return Material(
      color: palette.cardBackground,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: AppHaptics.wrap(() => context.push('/activities')),
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
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: palette.accentPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: palette.accentPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Próximo Social Run',
                      style: AppTypography.caption(
                        context,
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (isLoading)
                      Text('Cargando…', style: AppTypography.body(context))
                    else if (section == null)
                      Text(
                        'Ver actividades',
                        style: AppTypography.body(
                          context,
                          weight: FontWeight.w600,
                        ),
                      )
                    else ...[
                      Text(
                        highlight ?? section.title,
                        style: AppTypography.body(
                          context,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          section.title,
                          if (venue != null && venue.trim().isNotEmpty)
                            venue.trim(),
                        ].join(' · '),
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
              Icon(Icons.chevron_right_rounded, color: palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
