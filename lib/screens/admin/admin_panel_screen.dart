import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_provider.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/horizontal_chip_tab_bar.dart';
import 'admin_businesses_tab.dart';
import 'admin_news_management_tab.dart';
import 'admin_stats_tab.dart';
import 'admin_training_schedule_tab.dart';
import 'admin_users_tab.dart';

const adminPanelHomeTabIndex = 3;
const adminPanelUsersTabIndex = 0;
const adminPanelEventsTabIndex = 1;
const adminPanelBusinessesTabIndex = 2;
const adminPanelSchedulesTabIndex = 3;
const adminPanelStatsTabIndex = 4;

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  static const _tabLabels = [
    'Usuarios',
    'Eventos',
    'Marcas',
    'Horarios',
    'Estadísticas',
  ];

  static const _tabIcons = [
    Icons.people_outline_rounded,
    Icons.event_outlined,
    Icons.storefront_outlined,
    Icons.schedule_outlined,
    Icons.insights_outlined,
  ];

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              const AdminNewsManagementTab(),
              const AdminBusinessesTab(),
              const AdminTrainingScheduleTab(),
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
    );
  }
}
