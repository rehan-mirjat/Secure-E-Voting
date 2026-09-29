import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/organizations/domain/organization_enums.dart';
import '../../features/organizations/presentation/organization_context_switcher.dart';
import '../../features/organizations/presentation/providers/organization_providers.dart';
import '../../services/auth_service.dart';
import '../layout/responsive.dart';
import '../theme/app_theme.dart';

class AppNavigationShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppNavigationShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeContextState = ref.watch(activeOrganizationContextProvider);
    final orgContext = activeContextState.valueOrNull?.context;

    final bool isAdmin = orgContext != null &&
        (orgContext.member.role == OrganizationRole.owner ||
            orgContext.member.role == OrganizationRole.admin);

    final isDesktop = ResponsiveLayout.isWide(context);
    final compact = ResponsiveLayout.isCompact(context);
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: isDesktop
            ? Row(
                children: [
                  _buildSidebar(context, isAdmin),
                  Expanded(
                    child: Column(
                      children: [
                        const _TopHeader(),
                        Expanded(child: navigationShell),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  const _TopHeader(),
                  Expanded(child: navigationShell),
                ],
              ),
      ),
      bottomNavigationBar: isDesktop || keyboardVisible
          ? null
          : NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _goBranch,
              backgroundColor: Theme.of(context).colorScheme.surface,
              indicatorColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              elevation: 4,
              height: 72,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon:
                      Icon(Icons.home_rounded, color: AppTheme.primaryBlue),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.business_outlined),
                  selectedIcon: const Icon(Icons.business_rounded, color: AppTheme.primaryBlue),
                  label: compact ? 'Orgs' : 'Organizations',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon:
                      Icon(Icons.settings_rounded, color: AppTheme.primaryBlue),
                  label: 'Settings',
                ),
                if (isAdmin)
                  const NavigationDestination(
                    icon: Icon(Icons.admin_panel_settings_outlined),
                    selectedIcon: Icon(Icons.admin_panel_settings_rounded,
                        color: AppTheme.primaryBlue),
                    label: 'Admin',
                  ),
              ],
            ),
    );
  }

  Widget _buildSidebar(BuildContext context, bool isAdmin) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0B132B), // Deep Midnight Navy
            Color(0xFF0F172A), // Slate Navy
            Color(0xFF182238), // Royal Dark Accent
          ],
        ),
        border: Border(
          right: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: Stack(
        children: [
          // Subtle top-left ambient electric blue glow behind logo
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryBlue.withValues(alpha: 0.12),
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/icon/app_icon_transparent.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'SecureVote',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildSidebarItem(
                  context, 0, Icons.home_outlined, Icons.home_rounded, 'Home'),
              _buildSidebarItem(context, 1, Icons.business_outlined,
                  Icons.business_rounded, 'Organizations'),
              _buildSidebarItem(context, 2, Icons.settings_outlined,
                  Icons.settings_rounded, 'Settings'),
              if (isAdmin)
                _buildSidebarItem(context, 3, Icons.admin_panel_settings_outlined,
                    Icons.admin_panel_settings_rounded, 'Admin'),
              const Spacer(),
              const SizedBox(height: 24),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(BuildContext context, int index,
      IconData iconOutlined, IconData iconFilled, String label) {
    final isSelected = navigationShell.currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: InkWell(
        onTap: () => _goBranch(index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? iconFilled : iconOutlined,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                size: 20,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _TopHeader extends ConsumerWidget {
  const _TopHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platformAdmin = ref.watch(platformAdminProvider).valueOrNull == true;
    final pendingInvitations =
        ref.watch(memberInvitationsProvider).valueOrNull?.length ?? 0;
    final compact = ResponsiveLayout.isCompact(context);

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 20, vertical: compact ? 8 : 12),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceWhite,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderLight, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: OrganizationContextSwitcher(),
            ),
          ),
          if (platformAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined,
                  color: AppTheme.primaryBlue),
              tooltip: 'Platform administration',
              onPressed: () => context.go('/platform/organizations'),
            ),
          IconButton(
            icon: Badge(
              isLabelVisible: pendingInvitations > 0,
              label: Text('$pendingInvitations'),
              child: Icon(Icons.notifications_none_rounded,
                  color: Theme.of(context).colorScheme.onSurface, size: 22),
            ),
            tooltip: 'Notifications',
            onPressed: () => context.go('/orgs/invitations'),
          ),
        ],
      ),
    );
  }
}
