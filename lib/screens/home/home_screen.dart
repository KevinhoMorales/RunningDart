import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_business_provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/admin_news_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_haptics.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/user_avatar.dart';
import '../admin/admin_panel_screen.dart';
import '../business/business_list_screen.dart';
import '../business/operator_scan_screen.dart';
import '../news/news_list_screen.dart';

enum _HomeMode { member, operator, admin }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  _HomeMode _mode(AuthProvider auth) {
    if (auth.isAdmin) {
      return _HomeMode.admin;
    }
    if (auth.isBusinessOperator) {
      return _HomeMode.operator;
    }
    return _HomeMode.member;
  }

  String _homeAppBarTitle(String? displayName) {
    if (displayName != null && displayName.trim().isNotEmpty) {
      return Helpers.greetingForUser(displayName);
    }
    return Helpers.timeOfDayGreeting();
  }

  List<Widget> _pages(_HomeMode mode) {
    switch (mode) {
      case _HomeMode.operator:
        return const [
          OperatorScanScreen(),
          BusinessListScreen(),
          NewsListScreen(),
        ];
      case _HomeMode.admin:
        return const [
          BusinessListScreen(),
          NewsListScreen(),
          AdminPanelScreen(),
        ];
      case _HomeMode.member:
        return const [
          BusinessListScreen(),
          NewsListScreen(),
        ];
    }
  }

  List<NavigationDestination> _destinations(_HomeMode mode) {
    switch (mode) {
      case _HomeMode.operator:
        return const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Escanear',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Marcas',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_rounded),
            label: 'Noticias',
          ),
        ];
      case _HomeMode.admin:
        return const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Marcas',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_rounded),
            label: 'Noticias',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings_rounded),
            label: 'Admin',
          ),
        ];
      case _HomeMode.member:
        return const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Marcas',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_rounded),
            label: 'Noticias',
          ),
        ];
    }
  }

  Future<void> _refreshAdminPanel() async {
    await context.read<AuthProvider>().refreshAccountStatus();
    if (!mounted) {
      return;
    }

    if (context.read<AuthProvider>().isAdmin) {
      await Future.wait([
        context.read<AdminProvider>().refresh(),
        context.read<AdminNewsProvider>().refresh(),
        context.read<AdminBusinessProvider>().refresh(),
      ]);
    } else {
      context.read<AdminProvider>().stopListening();
      context.read<AdminNewsProvider>().stopListening();
      context.read<AdminBusinessProvider>().stopListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final auth = context.watch<AuthProvider>();
    final mode = _mode(auth);
    final pages = _pages(mode);
    final safeIndex = _currentIndex.clamp(0, pages.length - 1);
    final adminUpcomingNewsCount = auth.isAdmin
        ? context
            .watch<AdminNewsProvider>()
            .news
            .where((item) => Helpers.isEventUpcoming(item.eventDate))
            .length
        : 0;
    final showAdminBusinessFab = mode == _HomeMode.admin && safeIndex == 0;
    final showAdminNewsFab = mode == _HomeMode.admin &&
        safeIndex == adminNewsHomeTabIndex &&
        adminUpcomingNewsCount > 0;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: CustomAppBar(
        title: _homeAppBarTitle(auth.user?.displayName),
        actions: [
          HapticIconButton(
            onPressed: () => context.push('/profile'),
            tooltip: 'Mi perfil',
            icon: UserAvatar(
              displayName: auth.user?.displayName ?? '',
              photoUrl: auth.user?.photoUrl,
              radius: 16,
              showBackground: false,
            ),
          ),
        ],
      ),
      floatingActionButton: showAdminBusinessFab
          ? HapticFloatingActionButton(
              onPressed: () => context.push('/admin/businesses/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Marca'),
            )
          : showAdminNewsFab
              ? HapticFloatingActionButton(
                  onPressed: () => context.push('/admin/news/new'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Evento'),
                )
              : null,
      body: IndexedStack(
        index: safeIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: palette.navBarBackground,
          boxShadow: [
            BoxShadow(
              color: palette.navBarShadow,
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: AppHaptics.wrapValue((index) {
              setState(() {
                _currentIndex = index;
              });
              if (mode == _HomeMode.admin && index == adminPanelHomeTabIndex) {
                _refreshAdminPanel();
              }
            }),
            destinations: _destinations(mode),
          ),
        ),
      ),
    );
  }
}
