import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'admin_training_schedule_tab.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';

class AdminTrainingScheduleScreen extends StatelessWidget {
  const AdminTrainingScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Editar horarios',
        leading: HapticIconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: const AdminTrainingScheduleTab(),
    );
  }
}
