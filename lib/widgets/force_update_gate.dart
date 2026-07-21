import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_update_provider.dart';
import 'app_startup_loading.dart';
import 'force_update_screen.dart';

class ForceUpdateGate extends StatelessWidget {
  const ForceUpdateGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppUpdateProvider>(
      builder: (context, updateProvider, _) {
        if (!updateProvider.isChecked) {
          return const AppStartupLoading();
        }

        if (updateProvider.requiresUpdate) {
          return ForceUpdateScreen(
            currentVersion: updateProvider.currentVersion,
            requiredVersion: updateProvider.requiredVersion,
          );
        }

        return child;
      },
    );
  }
}
