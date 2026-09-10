import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_provider.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/horizontal_chip_tab_bar.dart';
import 'admin_activities_tab.dart';
import 'admin_businesses_tab.dart';
import 'admin_challenges_tab.dart';
import 'admin_news_management_tab.dart';
import 'admin_reports_tab.dart';
import 'admin_stats_tab.dart';
import 'admin_training_schedule_tab.dart';
import 'admin_users_tab.dart';

/// Índice del tab Admin en el shell (6.º destino: Inicio…Perfil + Admin).
const adminPanelHomeTabIndex = 5;
const adminPanelUsersTabIndex = 0;
const adminPanelActivitiesTabIndex = 1;
const adminPanelChallengesTabIndex = 2;
const adminPanelEventsTabIndex = 3;
const adminPanelBusinessesTabIndex = 4;
const adminPanelSchedulesTabIndex = 5;
const adminPanelReportsTabIndex = 6;
const adminPanelStatsTabIndex = 7;

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  static const _tabLabels = [
    'Usuarios',
    'Actividades',
    'Reto',
    'Eventos',
    'Marcas',
    'Horarios',
    'Reportes',
    'Estadísticas',
  ];

  static const _tabIcons = [
    Icons.people_outline_rounded,
    Icons.directions_run_rounded,
    Icons.flag_outlined,
    Icons.event_outlined,
    Icons.storefront_outlined,
    Icons.schedule_outlined,
    Icons.report_outlined,
    Icons.insights_outlined,
  ];

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget? _fabForTab() {
    final index = _tabController.index;
    if (index == adminPanelEventsTabIndex) {
      return HapticFloatingActionButton(
        onPressed: () => context.push('/admin/news/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Evento'),
      );
    }
    if (index == adminPanelBusinessesTabIndex) {
      return HapticFloatingActionButton(
        onPressed: () => context.push('/admin/businesses/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Marca'),
      );
    }
    if (index == adminPanelActivitiesTabIndex) {
      return HapticFloatingActionButton(
        onPressed: () => context.push('/admin/activities/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Actividad'),
      );
    }
    if (index == adminPanelChallengesTabIndex) {
      return HapticFloatingActionButton(
        onPressed: () => context.push('/admin/challenges/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Reto'),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fab = _fabForTab();

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                'Panel de administración',
                style: AppTypography.sectionTitle(context),
              ),
            ),
            HorizontalChipTabBar(
              labels: _tabLabels,
              icons: _tabIcons,
              controller: _tabController,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  const AdminUsersTab(),
                  const AdminActivitiesTab(),
                  const AdminChallengesTab(),
                  const AdminNewsManagementTab(),
                  const AdminBusinessesTab(),
                  const AdminTrainingScheduleTab(),
                  const AdminReportsTab(),
                  AdminStatsTab(
                    onNavigateToUsers: (filter) {
                      context.read<AdminProvider>().setUserFilter(filter);
                      _tabController.animateTo(adminPanelUsersTabIndex);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        if (fab != null)
          Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: fab,
          ),
      ],
    );
  }
}
