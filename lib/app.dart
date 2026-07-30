import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'config/app_environment.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/admin_business_provider.dart';
import 'providers/admin_news_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/admin_reports_provider.dart';
import 'providers/app_update_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/business_provider.dart';
import 'providers/feed_provider.dart';
import 'providers/news_provider.dart';
import 'providers/social_provider.dart';
import 'providers/notification_preferences_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/visit_provider.dart';
import 'screens/admin/admin_business_form_screen.dart';
import 'screens/admin/admin_businesses_screen.dart';
import 'screens/admin/admin_news_form_screen.dart';
import 'screens/admin/admin_user_detail_screen.dart';
import 'screens/admin/admin_validations_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/account_disabled_screen.dart';
import 'screens/auth/membership_pending_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/admin/admin_training_schedule_screen.dart';
import 'screens/club/pro_team_screen.dart';
import 'screens/club/training_schedule_screen.dart';
import 'screens/business/business_detail_screen.dart';
import 'screens/feed/create_post_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/news/news_detail_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/onboarding/notifications_onboarding_screen.dart';
import 'screens/settings/contact_screen.dart';
import 'screens/settings/delete_account_screen.dart';
import 'screens/social/blocked_users_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/social/follow_list_screen.dart';
import 'screens/social/user_profile_screen.dart';
import 'services/business_service.dart';
import 'services/firestore_business_service.dart';
import 'services/firestore_news_service.dart';
import 'services/firestore_post_service.dart';
import 'services/news_service.dart';
import 'services/notification_service.dart';
import 'services/post_service.dart';
import 'services/social_service.dart';
import 'services/user_service.dart';
import 'services/visit_service.dart';
import '../theme/app_theme.dart';
import 'widgets/app_startup_loading.dart';
import 'widgets/environment_banner.dart';
import 'widgets/force_update_gate.dart';
import 'widgets/router_error_screen.dart';

class RunningDartApp extends StatefulWidget {
  const RunningDartApp({
    super.key,
    required this.authProvider,
    required this.themeProvider,
    this.appUpdateProvider,
    this.notificationService,
    this.sharedPreferences,
    this.adminProvider,
    this.adminBusinessProvider,
    this.adminNewsProvider,
    this.visitProvider,
    this.businessService,
    this.newsService,
    this.postService,
    this.socialService,
  });

  final AuthProvider authProvider;
  final ThemeProvider themeProvider;
  final AppUpdateProvider? appUpdateProvider;
  final NotificationService? notificationService;
  final SharedPreferences? sharedPreferences;
  final AdminProvider? adminProvider;
  final AdminBusinessProvider? adminBusinessProvider;
  final AdminNewsProvider? adminNewsProvider;
  final VisitProvider? visitProvider;
  final BusinessService? businessService;
  final NewsService? newsService;
  final PostService? postService;
  final SocialService? socialService;

  @override
  State<RunningDartApp> createState() => _RunningDartAppState();
}

class _RunningDartAppState extends State<RunningDartApp> {
  // Perezosos a propósito: los `create` de MultiProvider tampoco corren hasta
  // que alguien lee el provider, y así una pantalla sin feed (el login) no
  // obliga a tener Firebase inicializado.
  late final BusinessService _businessService =
      widget.businessService ?? FirestoreBusinessService();
  late final NewsService _newsService =
      widget.newsService ?? FirestoreNewsService();
  late final PostService _postService =
      widget.postService ?? FirestorePostService();
  late final SocialService _socialService =
      widget.socialService ?? SocialService();
  late final AdminProvider _adminProvider;
  late final AdminBusinessProvider _adminBusinessProvider;
  late final AdminNewsProvider _adminNewsProvider;
  late final VisitProvider _visitProvider;
  late final AppUpdateProvider _appUpdateProvider;
  late final NotificationPreferencesProvider? _notificationPreferencesProvider;
  late final GoRouter _router;

  String _initialLocation(AuthProvider auth) {
    return auth.postAuthRoute;
  }

  bool _isAdminRoute(String location) {
    return location.startsWith('/admin/');
  }

  @override
  void initState() {
    super.initState();
    _adminProvider = widget.adminProvider ?? AdminProvider(UserService());
    _adminBusinessProvider = widget.adminBusinessProvider ??
        AdminBusinessProvider(_businessService);
    _adminNewsProvider =
        widget.adminNewsProvider ?? AdminNewsProvider(_newsService);
    _visitProvider = widget.visitProvider ?? VisitProvider(VisitService());
    _appUpdateProvider =
        widget.appUpdateProvider ?? AppUpdateProvider.notRequired();
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
      refreshListenable: Listenable.merge([
        widget.authProvider,
        if (_notificationPreferencesProvider != null)
          _notificationPreferencesProvider,
      ]),
      errorBuilder: (context, state) => RouterErrorScreen(error: state.error),
      redirect: (context, state) {
        final auth = widget.authProvider;
        final location = state.matchedLocation;
        final isAuthRoute =
            location == '/login' || location == '/register';
        final isOnboardingRoute = location == '/onboarding/notifications';
        final isDisabledRoute = location == '/account-disabled';
        final isProtectedRoute = location == '/home' ||
            location == '/settings' ||
            location == '/settings/contact' ||
            location == '/settings/blocked' ||
            location == '/settings/delete-account' ||
            location == '/profile' ||
            location == '/profile/edit' ||
            location == '/membership-pending' ||
            location == '/training-schedule' ||
            location == '/pro-team' ||
            location == '/post/new' ||
            location.startsWith('/business/') ||
            location.startsWith('/news/') ||
            location.startsWith('/user/') ||
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

        final notifications = _notificationPreferencesProvider;
        if (notifications != null &&
            notifications.onboardingPending &&
            !isOnboardingRoute) {
          return '/onboarding/notifications';
        }

        if (auth.isMembershipPending) {
          if (location == '/membership-pending') {
            return null;
          }
          return '/membership-pending';
        }

        if (location == '/membership-pending') {
          return '/home';
        }

        if (_isAdminRoute(location) && !auth.canAccessAdminPanel) {
          if (location == '/admin/training-schedule' &&
              auth.canManageSchedules) {
            return null;
          }
          return '/home';
        }

        if (isAuthRoute || isDisabledRoute) {
          return '/home';
        }

        if (isOnboardingRoute) {
          return null;
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/onboarding/notifications',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: NotificationsOnboardingScreen(),
          ),
        ),
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
          path: '/membership-pending',
          builder: (context, state) => const MembershipPendingScreen(),
        ),
        GoRoute(
          path: '/training-schedule',
          builder: (context, state) => const TrainingScheduleScreen(),
        ),
        GoRoute(
          path: '/pro-team',
          builder: (context, state) => const ProTeamScreen(),
        ),
        GoRoute(
          path: '/admin/training-schedule',
          builder: (context, state) => const AdminTrainingScheduleScreen(),
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
          path: '/settings/contact',
          builder: (context, state) => const ContactScreen(),
        ),
        GoRoute(
          path: '/settings/blocked',
          builder: (context, state) => const BlockedUsersScreen(),
        ),
        GoRoute(
          path: '/settings/delete-account',
          builder: (context, state) => const DeleteAccountScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
        ),
        GoRoute(
          path: '/profile/edit',
          builder: (context, state) => const EditProfileScreen(),
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
          path: '/post/new',
          builder: (context, state) => const CreatePostScreen(),
        ),
        GoRoute(
          path: '/user/:id/followers',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return FollowListScreen(
              userId: id,
              mode: FollowListMode.followers,
            );
          },
        ),
        GoRoute(
          path: '/user/:id/following',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return FollowListScreen(
              userId: id,
              mode: FollowListMode.following,
            );
          },
        ),
        GoRoute(
          path: '/user/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return UserProfileScreen(userId: id);
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
          path: '/admin/validations',
          builder: (context, state) {
            final approvedOnly =
                state.uri.queryParameters['approved'] == 'true';
            return AdminValidationsScreen(approvedOnly: approvedOnly);
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
        ChangeNotifierProvider.value(value: _appUpdateProvider),
        ChangeNotifierProvider(
          create: (_) => BusinessProvider(_businessService),
        ),
        ChangeNotifierProvider(
          create: (_) => NewsProvider(_newsService),
        ),
        ChangeNotifierProvider(
          create: (_) => FeedProvider(_postService, _socialService),
        ),
        ChangeNotifierProvider(
          create: (_) => SocialProvider(_socialService),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminReportsProvider(_socialService, _postService),
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
            title: AppEnvironment.appTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: _router,
            builder: (context, child) {
              final brightness = Theme.of(context).brightness;
              return ForceUpdateGate(
                child: EnvironmentBanner(
                  child: AnnotatedRegion<SystemUiOverlayStyle>(
                    value: AppTheme.systemOverlayStyle(brightness),
                    child: child ?? const AppStartupLoading(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
