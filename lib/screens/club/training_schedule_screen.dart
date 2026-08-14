import 'package:flutter/material.dart';

import '../../models/training_schedule_model.dart';
import '../../services/training_schedule_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../utils/constants.dart';
import '../../utils/schedule_helpers.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/schedule_card.dart';

class TrainingScheduleScreen extends StatelessWidget {
  const TrainingScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = TrainingScheduleService();
    final palette = context.palette;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Horarios de entrenamiento'),
      body: StreamBuilder<TrainingScheduleModel>(
        stream: service.watchSchedule(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final schedule =
              snapshot.data ?? TrainingScheduleService.defaultSchedule;
          final location = schedule.location ?? AppConstants.clubLocation;
          final venue = schedule.venue ?? AppConstants.clubVenue;
          final sections = schedule.sections;

          if (sections.isEmpty) {
            return Center(
              child: Text(
                'Horarios no disponibles por ahora.',
                style: AppTypography.muted(context),
              ),
            );
          }

          return _TrainingScheduleTabs(
            sections: sections,
            location: location,
            venue: venue,
            palette: palette,
          );
        },
      ),
    );
  }

  static String _tabLabel(String title) {
    if (title.contains('Pro Team')) {
      return 'Pro Team';
    }
    if (title.contains('Oficial')) {
      return 'Oficial';
    }
    if (title.contains('Comunidad')) {
      return 'Comunidad';
    }
    return title.split(' ').first;
  }
}

class _TrainingScheduleTabs extends StatefulWidget {
  const _TrainingScheduleTabs({
    required this.sections,
    required this.location,
    required this.venue,
    required this.palette,
  });

  final List<TrainingScheduleSection> sections;
  final String location;
  final String venue;
  final AppPalette palette;

  @override
  State<_TrainingScheduleTabs> createState() => _TrainingScheduleTabsState();
}

class _TrainingScheduleTabsState extends State<_TrainingScheduleTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.sections.length,
      vsync: this,
    );
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }
    AppHaptics.lightTap();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: ScheduleLocationBanner(
            location: widget.location,
            venue: widget.venue,
          ),
        ),
        TabBar(
          controller: _tabController,
          isScrollable: widget.sections.length > 2,
          labelColor: palette.accentPrimary,
          unselectedLabelColor: palette.textMuted,
          indicatorColor: palette.accentPrimary,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: palette.cardBorder,
          tabs: widget.sections
              .map(
                (section) => Tab(
                  text: TrainingScheduleScreen._tabLabel(section.title),
                ),
              )
              .toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: widget.sections
                .map(
                  (section) => ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      ScheduleCard(
                        title: section.title,
                        subtitle: section.subtitle,
                        icon: ScheduleHelpers.iconFor(section.iconName),
                        scheduleLines: section.lines,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Los horarios pueden variar según el calendario del club. '
                        'Consulta comunicados para cambios puntuales.',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption(
                          context,
                          color: palette.textMuted,
                        ).copyWith(height: 1.4),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
