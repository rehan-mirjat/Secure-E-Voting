import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../domain/organization_enums.dart';
import 'providers/organization_providers.dart';

class OrganizationDashboardScreen extends ConsumerWidget {
  const OrganizationDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeOrganizationContextProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Organization dashboard')),
      body: state.when(
        loading: () => const LoadingView(message: 'Loading organization…'),
        error: (error, _) => ErrorView(
          message: 'Could not load the active organization: $error',
          onRetry: () => ref.invalidate(activeOrganizationContextProvider),
        ),
        data: (active) {
          final org = active.context?.organization;
          final member = active.context?.member;
          if (org == null || member == null) {
            return const ErrorView(
              title: 'Select an organization',
              message: 'Choose an organization to open its administration dashboard.',
            );
          }
          if (member.role != OrganizationRole.owner && member.role != OrganizationRole.admin) {
            return const ErrorView(
              title: 'Administrator access required',
              message: 'This dashboard is available to the organization Owner and Admins.',
            );
          }

          final compact = MediaQuery.sizeOf(context).width < 650;
          final links = <_DashboardLink>[
            _DashboardLink('Members & invitations', 'Manage members and review invitations sent by this organization.', Icons.people_alt_outlined, '/orgs/members'),
            _DashboardLink('Joining codes', 'Create, review and revoke access codes.', Icons.key_outlined, '/orgs/joining-codes'),
            _DashboardLink('Departments', 'Organize members into groups.', Icons.domain_outlined, '/orgs/departments'),
            _DashboardLink('Voting events', 'Create events and monitor participation.', Icons.how_to_vote_outlined, '/admin/events'),
            _DashboardLink('Activity log', 'Review administrative changes.', Icons.history_rounded, '/orgs/audit'),
            if (member.role == OrganizationRole.owner)
              _DashboardLink('Organization branding', 'Update name, logo and colors.', Icons.palette_outlined, '/orgs/settings'),
          ];

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: ListView(
                padding: EdgeInsets.all(compact ? 16 : 28),
                children: [
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 18 : 26),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: compact ? 24 : 30,
                            child: const Icon(Icons.business_rounded, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(org.name, style: Theme.of(context).textTheme.headlineSmall),
                                const SizedBox(height: 5),
                                Text('${member.role.value.toUpperCase()}  •  ${org.status.value.toUpperCase()}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Manage your organization', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 900 ? 3 : constraints.maxWidth >= 560 ? 2 : 1;
                      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final link in links)
                            SizedBox(
                              width: width,
                              child: _DashboardCard(
                                link: link,
                                onTap: () => context.go(link.route),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashboardLink {
  const _DashboardLink(this.title, this.description, this.icon, this.route);
  final String title;
  final String description;
  final IconData icon;
  final String route;
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.link, required this.onTap});
  final _DashboardLink link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(link.icon, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(link.title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(link.description, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      );
}
