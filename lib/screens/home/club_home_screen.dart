import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/training_schedule_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/news_provider.dart';
import '../../services/qr_service.dart';
import '../../services/training_schedule_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../utils/membership_helpers.dart';
import '../../utils/schedule_helpers.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/membership_credential_card.dart';
import '../../widgets/membership_upsell_card.dart';
import '../../widgets/news_card.dart';

/// Primera pantalla después del login: saludo, credencial/QR, próximo
/// entrenamiento y un par de eventos. Marcas queda como tab aparte.
class ClubHomeScreen extends StatefulWidget {
  const ClubHomeScreen({super.key});

  @override
  State<ClubHomeScreen> createState() => _ClubHomeScreenState();
}

class _ClubHomeScreenState extends State<ClubHomeScreen> {
  final _scheduleService = TrainingScheduleService();
  final _qrService = QRService();

  TrainingScheduleModel? _schedule;
  bool _loadingSchedule = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NewsProvider>().startListening();
      _loadSchedule();
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

  Future<void> _refresh() async {
    await Future.wait([
      context.read<NewsProvider>().refresh(),
      _loadSchedule(),
      context.read<AuthProvider>().refreshAccountStatus(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final newsProvider = context.watch<NewsProvider>();
    final upcoming = newsProvider.news.take(2).toList(growable: false);

    return HapticRefreshIndicator(
      onRefresh: _refresh,
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
                    'Tu club',
                    style: AppTypography.sectionTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Credencial, entrenamientos y lo que viene en SAINTS.',
                    style: AppTypography.muted(context),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (user != null) _CredentialBlock(user: user, qrService: _qrService),
                  const SizedBox(height: AppSpacing.md),
                  _NextTrainingCard(
                    user: user,
                    schedule: _schedule,
                    isLoading: _loadingSchedule,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Próximos eventos',
                    style: AppTypography.sectionTitle(context),
                  ),
                ],
              ),
            ),
          ),
          if (newsProvider.isLoading && upcoming.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (upcoming.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: EmptyStateCard(
                  icon: Icons.event_note_outlined,
                  message: 'Sin eventos por ahora',
                  subtitle:
                      'Cuando haya rodadas o actividades, las verás aquí.',
                ),
              ),
            )
          else
            ...upcoming.map(
              (item) => SliverToBoxAdapter(
                child: NewsCard(
                  news: item,
                  onTap: () => context.push('/news/${item.id}'),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MembershipCredentialCard(
          user: user,
          qrPayload: qrService.generatePayload(user),
        ),
      ],
    );
  }
}

class _NextTrainingCard extends StatelessWidget {
  const _NextTrainingCard({
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
    if (modality == 'proTeam') {
      for (final section in sections) {
        if (matches(section, 'pro')) {
          return section;
        }
      }
    } else if (modality == 'official') {
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
        onTap: AppHaptics.wrap(() => context.push('/training-schedule')),
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
                      'Próximo entrenamiento',
                      style: AppTypography.caption(context, color: palette.textMuted),
                    ),
                    const SizedBox(height: 2),
                    if (isLoading)
                      Text('Cargando…', style: AppTypography.body(context))
                    else if (section == null)
                      Text(
                        'Horarios no disponibles',
                        style: AppTypography.body(context, weight: FontWeight.w600),
                      )
                    else ...[
                      Text(
                        highlight ?? section.title,
                        style: AppTypography.body(context, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          section.title,
                          if (venue != null && venue.trim().isNotEmpty) venue.trim(),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(context, color: palette.textMuted),
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
