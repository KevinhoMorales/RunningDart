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
import '../admin/admin_panel_screen.dart';
import '../business/operator_scan_screen.dart';
import '../club/activities_list_screen.dart';
import '../club/league_screen.dart';
import '../feed/feed_screen.dart';
import '../profile/profile_tab_screen.dart';
import 'club_home_screen.dart';

enum _HomeMode { member, operator, admin }

/// Índices de la nav de socio (Inicio / Actividades / Liga / Comunidad / Perfil).
const homeTabIndex = 0;
const activitiesTabIndex = 1;
const leagueTabIndex = 2;
const profileTabIndex = 4;

/// Sexto destino solo para admin u operador.
const roleExtraTabIndex = 5;

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

  String _appBarTitle(_HomeMode mode, int index, String? displayName) {
    if (index == homeTabIndex) {
      if (displayName != null && displayName.trim().isNotEmpty) {
        return Helpers.greetingForUser(displayName);
      }
      return Helpers.timeOfDayGreeting();
    }
    if (index == activitiesTabIndex) {
      return 'Actividades';
    }
    if (index == leagueTabIndex) {
      return 'Liga';
    }
    if (index == communityHomeTabIndex) {
      return 'Comunidad';
    }
    if (index == profileTabIndex) {
      return 'Perfil';
    }
    if (index == roleExtraTabIndex) {
      return mode == _HomeMode.admin ? 'Admin' : 'Escanear';
    }
    return 'SAINTS';
  }

  /// Inicio → Actividades → Liga → Comunidad → Perfil → (Admin|Escanear).
  List<Widget> _pages(_HomeMode mode) {
    const primary = <Widget>[
      ClubHomeScreen(),
      ActivitiesListScreen(embedded: true),
      LeagueScreen(embedded: true),
      FeedScreen(),
      ProfileTabScreen(),
    ];

    switch (mode) {
      case _HomeMode.operator:
        return const [
          ...primary,
          OperatorScanScreen(),
        ];
      case _HomeMode.admin:
        return const [
          ...primary,
          AdminPanelScreen(),
        ];
      case _HomeMode.member:
        return primary;
    }
  }

  List<NavigationDestination> _destinations(_HomeMode mode) {
    const shared = <NavigationDestination>[
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Inicio',
      ),
      NavigationDestination(
        icon: Icon(Icons.directions_run_outlined),
        selectedIcon: Icon(Icons.directions_run_rounded),
        label: 'Actividades',
      ),
      NavigationDestination(
        icon: Icon(Icons.emoji_events_outlined),
        selectedIcon: Icon(Icons.emoji_events_rounded),
        label: 'Liga',
      ),
      NavigationDestination(
        icon: Icon(Icons.people_alt_outlined),
        selectedIcon: Icon(Icons.people_alt_rounded),
        label: 'Comunidad',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Perfil',
      ),
    ];

    switch (mode) {
      case _HomeMode.operator:
        return [
          ...shared,
          const NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Escanear',
          ),
        ];
      case _HomeMode.admin:
        return [
          ...shared,
          const NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings_rounded),
            label: 'Admin',
          ),
        ];
      case _HomeMode.member:
        return shared;
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
    final showMembershipQr = safeIndex != profileTabIndex &&
        safeIndex != roleExtraTabIndex;
    // Publicar solo en Comunidad.
    final showPublishFab = safeIndex == communityHomeTabIndex;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: CustomAppBar(
        title: _appBarTitle(mode, safeIndex, auth.user?.displayName),
        actions: [
          if (showMembershipQr)
            HapticIconButton(
              onPressed: () => context.push('/membership'),
              tooltip: 'Mi QR',
              icon: Icon(Icons.qr_code_2_rounded, color: palette.textPrimary),
            ),
          if (safeIndex == profileTabIndex)
            HapticIconButton(
              onPressed: () => context.push('/settings'),
              tooltip: 'Ajustes',
              icon: Icon(Icons.settings_rounded, color: palette.textPrimary),
            ),
        ],
      ),
      floatingActionButton: showPublishFab
          ? HapticFloatingActionButton(
              onPressed: () => context.push('/post/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Publicar'),
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
              if (mode == _HomeMode.admin && index == roleExtraTabIndex) {
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
