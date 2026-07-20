import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'providers/admin_business_provider.dart';
import 'providers/admin_news_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/business_provider.dart';
import 'providers/news_provider.dart';
import 'providers/notification_preferences_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/visit_provider.dart';
import 'screens/admin/admin_business_form_screen.dart';
import 'screens/admin/admin_businesses_screen.dart';
import 'screens/admin/admin_news_form_screen.dart';
import 'screens/admin/admin_user_detail_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/account_disabled_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/business/business_detail_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/news/news_detail_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'services/business_service.dart';
import 'services/firestore_business_service.dart';
import 'services/firestore_news_service.dart';
import 'services/news_service.dart';
import 'services/notification_service.dart';
import 'services/user_service.dart';
import 'services/visit_service.dart';
import 'theme/app_theme.dart';

class RunningDartApp extends StatefulWidget {
  const RunningDartApp({
    super.key,
    required this.authProvider,
    required this.themeProvider,
    this.notificationService,
    this.sharedPreferences,
    this.adminProvider,
    this.adminBusinessProvider,
    this.adminNewsProvider,
    this.visitProvider,
    this.businessService,
    this.newsService,
  });

  final AuthProvider authProvider;
  final ThemeProvider themeProvider;
  final NotificationService? notificationService;
  final SharedPreferences? sharedPreferences;
  final AdminProvider? adminProvider;
  final AdminBusinessProvider? adminBusinessProvider;
  final AdminNewsProvider? adminNewsProvider;
  final VisitProvider? visitProvider;
  final BusinessService? businessService;
  final NewsService? newsService;

  @override
  State<RunningDartApp> createState() => _RunningDartAppState();
}

class _RunningDartAppState extends State<RunningDartApp> {
  late final BusinessService _businessService;
  late final NewsService _newsService;
  late final AdminProvider _adminProvider;
  late final AdminBusinessProvider _adminBusinessProvider;
  late final AdminNewsProvider _adminNewsProvider;
  late final VisitProvider _visitProvider;
  late final NotificationPreferencesProvider? _notificationPreferencesProvider;
  late final GoRouter _router;

  String _initialLocation(AuthProvider auth) {
    if (auth.canAccessApp) {
      return '/home';
    }
    if (auth.isAccountDisabled) {
      return '/account-disabled';
    }
    return '/login';
  }

  bool _isAdminRoute(String location) {
    return location.startsWith('/admin/');
  }

  @override
  void initState() {
    super.initState();
    _businessService =
        widget.businessService ?? FirestoreBusinessService();
    _newsService = widget.newsService ?? FirestoreNewsService();
    _adminProvider = widget.adminProvider ?? AdminProvider(UserService());
    _adminBusinessProvider = widget.adminBusinessProvider ??
        AdminBusinessProvider(_businessService);
    _adminNewsProvider =
        widget.adminNewsProvider ?? AdminNewsProvider(_newsService);
    _visitProvider = widget.visitProvider ?? VisitProvider(VisitService());
    if (widget.notificationService != null && widget.sharedPreferences != null) {
      _notificationPreferencesProvider = NotificationPreferencesProvider(
        widget.sharedPreferences!,
        widget.notificationService!,
      );
    } else {
      _notificationPreferencesProvider = null;
    }

    _router = GoRouter(
      initialLocation: _initialLocation(widget.authProvider),
      refreshListenable: widget.authProvider,
      redirect: (context, state) {
        final auth = widget.authProvider;
        final location = state.matchedLocation;
        final isAuthRoute =
            location == '/login' || location == '/register';
        final isDisabledRoute = location == '/account-disabled';
        final isProtectedRoute = location == '/home' ||
            location == '/settings' ||
            location == '/profile' ||
            location.startsWith('/business/') ||
            location.startsWith('/news/') ||
            _isAdminRoute(location);

        if (!auth.hasSession) {
          if (isDisabledRoute || isProtectedRoute) {
            return '/login';
          }
          return null;
        }

        if (auth.isAccountDisabled) {
          if (isDisabledRoute) {
            return null;
          }
          return '/account-disabled';
        }

        if (_isAdminRoute(location) && !auth.canAccessAdminPanel) {
          return '/home';
        }

        if (isAuthRoute || isDisabledRoute) {
          return '/home';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/account-disabled',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AccountDisabledScreen(),
          ),
        ),
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
        ),
        GoRoute(
          path: '/business/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return BusinessDetailScreen(businessId: id);
          },
        ),
        GoRoute(
          path: '/news/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return NewsDetailScreen(newsId: id);
          },
        ),
        GoRoute(
          path: '/admin/users/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return AdminUserDetailScreen(userId: id);
          },
        ),
        GoRoute(
          path: '/admin/businesses',
          builder: (context, state) => const AdminBusinessesScreen(),
        ),
        GoRoute(
          path: '/admin/businesses/new',
          builder: (context, state) => const AdminBusinessFormScreen(),
        ),
        GoRoute(
          path: '/admin/businesses/:id/edit',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return AdminBusinessFormScreen(businessId: id);
          },
        ),
        GoRoute(
          path: '/admin/news/new',
          builder: (context, state) => const AdminNewsFormScreen(),
        ),
        GoRoute(
          path: '/admin/news/:id/edit',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return AdminNewsFormScreen(newsId: id);
          },
        ),
      ],
    );

    final notificationService = widget.notificationService;
    if (notificationService != null) {
      notificationService.onNavigate = (route) {
        _router.go(route);
      };
      notificationService.bindRouterHandlers();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notificationService.handleInitialMessage();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.themeProvider),
        ChangeNotifierProvider.value(value: widget.authProvider),
        ChangeNotifierProvider(
          create: (_) => BusinessProvider(_businessService),
        ),
        ChangeNotifierProvider(
          create: (_) => NewsProvider(_newsService),
        ),
        ChangeNotifierProvider.value(value: _adminProvider),
        ChangeNotifierProvider.value(value: _adminBusinessProvider),
        ChangeNotifierProvider.value(value: _adminNewsProvider),
        ChangeNotifierProvider.value(value: _visitProvider),
        if (_notificationPreferencesProvider != null)
          ChangeNotifierProvider.value(
            value: _notificationPreferencesProvider,
          ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'SAINTS',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: _router,
            builder: (context, child) {
              final brightness = Theme.of(context).brightness;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: AppTheme.systemOverlayStyle(brightness),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
