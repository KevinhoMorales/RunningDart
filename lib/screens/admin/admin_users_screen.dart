import 'package:flutter/material.dart';

import 'admin_panel_screen.dart';
import 'admin_users_tab.dart';

const adminUsersHomeTabIndex = adminPanelHomeTabIndex;

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminUsersTab();
  }
}
