import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/email_verification_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/organizations/presentation/organization_list_screen.dart';
import '../../features/organizations/presentation/membership_directory_screen.dart';
import '../../features/departments/presentation/departments_screen.dart';
import '../../features/organizations/presentation/join_organization_screen.dart';
import '../../features/organizations/presentation/create_organization_screen.dart';
import '../../features/voting_events/presentation/dashboard/admin_event_dashboard_screen.dart';
import '../../features/voting_events/presentation/builder/event_builder_screen.dart';
import '../../features/voting/presentation/cast_vote_screen.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../../features/organizations/presentation/providers/organization_providers.dart';
import '../../features/organizations/domain/organization_enums.dart';

import '../presentation/home_screen.dart';
import '../presentation/splash_screen.dart';
import '../presentation/app_navigation_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorHomeKey = GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final GlobalKey<NavigatorState> _shellNavigatorOrgsKey = GlobalKey<NavigatorState>(debugLabel: 'shellOrgs');
final GlobalKey<NavigatorState> _shellNavigatorSettingsKey = GlobalKey<NavigatorState>(debugLabel: 'shellSettings');
final GlobalKey<NavigatorState> _shellNavigatorAdminKey = GlobalKey<NavigatorState>(debugLabel: 'shellAdmin');

/// We construct a Listenable that merges the auth stream, the user's email verification state,
/// and the active organization context to proactively trigger GoRouter evaluations.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  bool _isAuthLoading = true;
  bool _isAuth = false;
  bool _isEmailVerified = false;
  bool _isOrgLoading = true;
  OrganizationRole? _activeRole;

  RouterNotifier(this._ref) {
    _ref.listen(authStateChangesProvider, (_, next) {
      if (next.isLoading) {
        _isAuthLoading = true;
      } else {
        _isAuthLoading = false;
        final user = next.value;
        _isAuth = user != null;
        
        // EMULATOR BYPASS: Treat any authenticated user as verified if running on emulator.
        // This is strictly gated by the environment and never applied in production.
        final bool isEmulator = FirebaseService.isEmulatorMode;
        _isEmailVerified = isEmulator ? true : (user?.emailVerified ?? false);
      }
      notifyListeners();
    });

    _ref.listen(activeOrganizationContextProvider, (_, next) {
      if (next.isLoading) {
        _isOrgLoading = true;
      } else {
        _isOrgLoading = false;
        final orgContext = next.valueOrNull?.context;
        _activeRole = orgContext?.member.role;
      }
      notifyListeners();
    });
  }

  bool get isAuthLoading => _isAuthLoading;
  bool get isAuth => _isAuth;
  bool get isEmailVerified => _isEmailVerified;
  bool get isOrgLoading => _isOrgLoading;
  bool get isAdmin => _activeRole == OrganizationRole.owner || _activeRole == OrganizationRole.admin;
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isAuth = notifier.isAuth;
      final isVerified = notifier.isEmailVerified;
      final isAdmin = notifier.isAdmin;
      
      final location = state.matchedLocation;
      
      // 0. Hold navigation during critical loading phases
      if (notifier.isAuthLoading) {
         return '/splash'; // Wait for auth stream
      }

      final isUnauthRoute = location == '/login' || location == '/register' || location == '/forgot-password';
      final isVerifyRoute = location == '/verify-email';
      final isSplashRoute = location == '/splash';
      final isAdminRoute = location.startsWith('/admin');

      // 1. Unauthenticated -> Force /login
      if (!isAuth) {
        return isUnauthRoute ? null : '/login';
      }

      // 2. Authenticated but Email Unverified -> Force /verify-email
      if (!isVerified) {
        return isVerifyRoute ? null : '/verify-email';
      }

      // 3. Authenticated + Verified visiting auth routes, splash, or root '/' -> Redirect to /home
      if (isUnauthRoute || isVerifyRoute || isSplashRoute || location == '/') {
        return '/home';
      }

      // 4. Role Guard for /admin/* routes
      if (isAdminRoute) {
        if (notifier.isOrgLoading) {
           return null; // Hold redirect until org role is known
        }
        if (!isAdmin) {
          // Non-administrators reaching administrative routes are redirected to /home
          return '/home';
        }
      }

      return null; // Allow navigation
    },
    routes: [
      // --- SPLASH / LOADING ROUTE ---
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // --- UNAUTHENTICATED ROUTES ---
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          onRegisterTap: () => context.go('/register'),
          onForgotPasswordTap: () => context.go('/forgot-password'),
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterScreen(
          onBackToLoginTap: () => context.go('/login'),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => ForgotPasswordScreen(
          onBackToLoginTap: () => context.go('/login'),
        ),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => EmailVerificationScreen(
          onSignOut: () async {
            await ref.read(authServiceProvider).signOut();
            // Router listener will handle redirect
          },
          onVerified: () {
            ref.invalidate(authStateChangesProvider);
          },
        ),
      ),

      // --- AUTHENTICATED SHELL ROUTES ---
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppNavigationShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Home / Election Feed
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHomeKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
              // M5/M6 Controlled Future Stubs
              GoRoute(
                path: '/elections/:eventId',
                builder: (context, state) => Scaffold(body: Center(child: Text('Election Details M5 Stub - ${state.pathParameters['eventId']}'))),
                routes: [
                   GoRoute(
                     path: 'vote',
                     builder: (context, state) => CastVoteScreen(eventId: state.pathParameters['eventId']!),
                   ),
                   GoRoute(
                     path: 'results',
                     builder: (context, state) => Scaffold(body: Center(child: Text('Results M6 Stub - ${state.pathParameters['eventId']}'))),
                   ),
                ]
              ),
            ],
          ),
          
          // Branch 1: Organizations (Includes Join/Create stubs/implementations)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorOrgsKey,
            routes: [
              GoRoute(
                path: '/orgs',
                builder: (context, state) => const OrganizationListScreen(),
                routes: [
                  GoRoute(
                    path: 'join',
                    builder: (context, state) => const JoinOrganizationScreen(),
                  ),
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => CreateOrganizationScreen(
                      onOrganizationCreated: (orgId) {
                         // Once created and selected, route the user dynamically
                         context.go('/orgs');
                      },
                      onCancelTap: () => context.go('/orgs'),
                    ),
                  ),
                  GoRoute(
                    path: 'members',
                    builder: (context, state) => const MembershipDirectoryScreen(),
                  ),
                  GoRoute(
                    path: 'departments',
                    builder: (context, state) => const DepartmentsScreen(),
                  ),
                ]
              ),
            ],
          ),

          // Branch 2: Settings / Profile
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSettingsKey,
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) {
                  final user = ref.read(authServiceProvider).currentUser;
                  if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  return ProfileScreen(
                    uid: user.uid,
                    onSignOut: () {
                       ref.read(activeOrgIdProvider.notifier).clearSelection();
                    },
                  );
                },
              ),
            ],
          ),

          // Branch 3: Admin Dashboard (Guarded by redirect, conditionally rendered by shell)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorAdminKey,
            routes: [
              GoRoute(
                path: '/admin/events',
                builder: (context, state) => const AdminEventDashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const EventBuilderScreen(),
                  ),
                  GoRoute(
                    path: ':eventId/edit',
                    builder: (context, state) => EventBuilderScreen(existingEventId: state.pathParameters['eventId']),
                  ),
                  // Stubs for future choices/review mapping
                  GoRoute(
                    path: ':eventId/choices',
                    builder: (context, state) => const Scaffold(body: Center(child: Text('Manage Choices Stub'))),
                  ),
                  GoRoute(
                    path: ':eventId/review',
                    builder: (context, state) => const Scaffold(body: Center(child: Text('Review Stub'))),
                  ),
                ]
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
