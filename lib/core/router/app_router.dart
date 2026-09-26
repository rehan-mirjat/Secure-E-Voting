import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/email_verification_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/organizations/presentation/organization_list_screen.dart';
import '../../features/organizations/presentation/organization_settings_screen.dart';
import '../../features/organizations/presentation/organization_audit_screen.dart';
import '../../features/organizations/presentation/platform_organizations_screen.dart';
import '../../features/organizations/presentation/membership_directory_screen.dart';
import '../../features/departments/presentation/department_members_screen.dart';
import '../../features/departments/presentation/departments_screen.dart';
import '../../features/organizations/presentation/join_organization_screen.dart';
import '../../features/organizations/presentation/accept_invitation_screen.dart';
import '../../features/organizations/presentation/create_organization_screen.dart';
import '../../features/voting_events/presentation/dashboard/admin_event_dashboard_screen.dart';
import '../../features/voting_events/presentation/builder/event_builder_screen.dart';
import '../../features/voting_events/presentation/event_detail_screen.dart';
import '../../features/voting_events/presentation/event_results_screen.dart';
import '../../features/voting_events/presentation/event_monitoring_screen.dart';
import '../../features/voting/presentation/cast_vote_screen.dart';
import '../../features/voting/presentation/vote_receipt_screen.dart';
import '../../features/voting/domain/vote_receipt.dart';
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
      
      if (notifier.isAuthLoading) {
         return '/splash';
      }

      final isUnauthRoute = location == '/login' || location == '/register' || location == '/forgot-password';
      final isVerifyRoute = location == '/verify-email';
      final isSplashRoute = location == '/splash';
      final isAdminRoute = location.startsWith('/admin');

      if (!isAuth) {
        return isUnauthRoute ? null : '/login';
      }

      if (!isVerified) {
        return isVerifyRoute ? null : '/verify-email';
      }

      if (isUnauthRoute || isVerifyRoute || isSplashRoute || location == '/') {
        return '/home';
      }

      if (isAdminRoute) {
        if (notifier.isOrgLoading) {
           return null;
        }
        if (!isAdmin) {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

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
          },
          onVerified: () {
            ref.invalidate(authStateChangesProvider);
          },
        ),
      ),
      GoRoute(
        path: '/receipt',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final receipt = extra['receipt'] as VoteReceipt;
          final eventTitle = extra['eventTitle'] as String?;
          return VoteReceiptScreen(receipt: receipt, eventTitle: eventTitle);
        },
      ),
      GoRoute(
        path: '/platform/organizations',
        builder: (context, state) => const PlatformOrganizationsScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppNavigationShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHomeKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
              GoRoute(
                path: '/elections/:eventId',
                builder: (context, state) => EventDetailScreen(
                  eventId: state.pathParameters['eventId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'results',
                    builder: (context, state) => EventResultsScreen(
                      eventId: state.pathParameters['eventId']!,
                    ),
                  ),
                   GoRoute(
                     path: 'vote',
                     builder: (context, state) => CastVoteScreen(
                       eventId: state.pathParameters['eventId']!,
                     ),
                   ),
                ],
              ),
            ],
          ),
          
          StatefulShellBranch(
            navigatorKey: _shellNavigatorOrgsKey,
            routes: [
              GoRoute(
                path: '/orgs',
                builder: (context, state) => const OrganizationListScreen(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const OrganizationSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'audit',
                    builder: (context, state) => const OrganizationAuditScreen(),
                  ),
                  GoRoute(
                    path: 'join',
                    builder: (context, state) => const JoinOrganizationScreen(),
                  ),
                  GoRoute(
                    path: 'accept-invitation',
                    builder: (context, state) => const AcceptInvitationScreen(),
                  ),
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => CreateOrganizationScreen(
                      onOrganizationCreated: (orgId) {
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
                  GoRoute(
                    path: 'departments/:id',
                    builder: (context, state) => DepartmentMembersScreen(
                      departmentId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),

          StatefulShellBranch(
            navigatorKey: _shellNavigatorSettingsKey,
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) {
                  final user = ref.watch(authServiceProvider).currentUser;
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

          StatefulShellBranch(
            navigatorKey: _shellNavigatorAdminKey,
            routes: [
              GoRoute(
                path: '/admin/events',
                builder: (context, state) => const AdminEventDashboardScreen(),
                routes: [
                  GoRoute(
                    path: ':eventId/monitor',
                    builder: (context, state) => EventMonitoringScreen(
                      eventId: state.pathParameters['eventId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const EventBuilderScreen(),
                  ),
                  GoRoute(
                    path: ':eventId/edit',
                    builder: (context, state) => EventBuilderScreen(existingEventId: state.pathParameters['eventId']),
                  ),
                  GoRoute(
                    path: ':eventId/choices',
                    builder: (context, state) => EventBuilderScreen(
                      existingEventId: state.pathParameters['eventId'],
                      initialStep: 3,
                    ),
                  ),
                  GoRoute(
                    path: ':eventId/review',
                    builder: (context, state) => EventBuilderScreen(
                      existingEventId: state.pathParameters['eventId'],
                      initialStep: 4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
