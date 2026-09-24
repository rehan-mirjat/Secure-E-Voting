import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/organizations/domain/organization_enums.dart';
import '../../features/organizations/presentation/organization_context_switcher.dart';
import '../../features/organizations/presentation/providers/organization_providers.dart';
import '../theme/app_theme.dart';

class AppNavigationShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppNavigationShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeContextState = ref.watch(activeOrganizationContextProvider);
    final orgContext = activeContextState.valueOrNull?.context;
    
    final bool isAdmin = orgContext != null && 
        (orgContext.member.role == OrganizationRole.owner || orgContext.member.role == OrganizationRole.admin);

    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: isDesktop
          ? Row(
              children: [
                _buildSidebar(context, isAdmin),
                Expanded(
                  child: Column(
                    children: [
                      _buildTopHeader(context),
                      Expanded(child: navigationShell),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _buildTopHeader(context),
                Expanded(child: navigationShell),
              ],
            ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _goBranch,
              backgroundColor: Colors.white,
              indicatorColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home, color: AppTheme.primaryBlue),
                  label: 'Home',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.business_outlined),
                  selectedIcon: Icon(Icons.business, color: AppTheme.primaryBlue),
                  label: 'Orgs',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings, color: AppTheme.primaryBlue),
                  label: 'Settings',
                ),
                if (isAdmin)
                  const NavigationDestination(
                    icon: Icon(Icons.admin_panel_settings_outlined),
                    selectedIcon: Icon(Icons.admin_panel_settings, color: AppTheme.primaryBlue),
                    label: 'Admin',
                  ),
              ],
            ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundLight,
      ),
      child: Row(
        children: [
          const OrganizationContextSwitcher(),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, color: AppTheme.secondaryNavy, size: 22),
            tooltip: 'Notifications',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, bool isAdmin) {
    return Container(
      width: 260,
      color: AppTheme.secondaryNavy,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.how_to_vote, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'SecureVote',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildSidebarItem(context, 0, Icons.home_outlined, Icons.home, 'Home'),
          _buildSidebarItem(context, 1, Icons.business_outlined, Icons.business, 'Organizations'),
          _buildSidebarItem(context, 2, Icons.settings_outlined, Icons.settings, 'Settings'),
          if (isAdmin) _buildSidebarItem(context, 3, Icons.admin_panel_settings_outlined, Icons.admin_panel_settings, 'Admin'),
          const Spacer(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(BuildContext context, int index, IconData iconOutlined, IconData iconFilled, String label) {
    final isSelected = navigationShell.currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: InkWell(
        onTap: () => _goBranch(index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
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
