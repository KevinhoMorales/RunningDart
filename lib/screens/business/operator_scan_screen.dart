import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import 'qr_scanner_screen.dart';
import 'visit_history_screen.dart';

class OperatorScanScreen extends StatefulWidget {
  const OperatorScanScreen({super.key});

  @override
  State<OperatorScanScreen> createState() => _OperatorScanScreenState();
}

class _OperatorScanScreenState extends State<OperatorScanScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _scannerActive = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }

    final isScanTab = _tabController.index == 0;
    if (_scannerActive != isScanTab) {
      setState(() => _scannerActive = isScanTab);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          labelColor: palette.accentPrimary,
          unselectedLabelColor: palette.textMuted,
          indicatorColor: palette.accentPrimary,
          tabs: const [
            Tab(
              icon: Icon(Icons.qr_code_scanner_rounded, size: 20),
              text: 'Escanear',
            ),
            Tab(
              icon: Icon(Icons.history_rounded, size: 20),
              text: 'Visitas',
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              QrScannerScreen(isActive: _scannerActive),
              const VisitHistoryScreen(),
            ],
          ),
        ),
      ],
    );
  }
}
