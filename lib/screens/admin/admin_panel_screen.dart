import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'admin_businesses_tab.dart';
import 'admin_news_management_tab.dart';
import 'admin_users_tab.dart';

const adminPanelHomeTabIndex = 2;

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DefaultTabController(
      length: 3,
      child: Column(
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
          TabBar(
            labelColor: palette.accentPrimary,
            unselectedLabelColor: palette.textMuted,
            indicatorColor: palette.accentPrimary,
            tabs: const [
              Tab(text: 'Usuarios'),
              Tab(text: 'Eventos'),
              Tab(text: 'Negocios'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                AdminUsersTab(),
                AdminNewsManagementTab(),
                AdminBusinessesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
