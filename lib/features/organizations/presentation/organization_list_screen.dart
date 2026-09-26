import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/organization.dart';
import '../domain/organization_enums.dart';
import 'providers/organization_providers.dart';

class OrganizationListScreen extends ConsumerWidget {
  const OrganizationListScreen({
    super.key,
    this.onCreateOrgTap,
    this.onSignOutTap,
  });

  final VoidCallback? onCreateOrgTap;
  final VoidCallback? onSignOutTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membershipsAsync = ref.watch(userMembershipsProvider);
    final orgsAsync = ref.watch(userOrganizationsProvider);
    final activeOrgStateAsync = ref.watch(activeOrganizationContextProvider);

    final activeOrgId = activeOrgStateAsync.valueOrNull?.context?.organization.id;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: membershipsAsync.when(
              loading: () => const LoadingView(message: 'Loading memberships...'),
              error: (err, stack) => ErrorView(
                message: 'Error loading memberships: $err',
                onRetry: () => ref.invalidate(userMembershipsProvider),
              ),
              data: (memberships) {
                if (memberships.isEmpty) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.corporate_fare_outlined,
                          size: 56, color: AppTheme.primaryBlue),
                      const SizedBox(height: 16),
                      Text('No joined organizations yet',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text(
                        'Accept an invitation, join with an organization code, or create a new organization.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => context.go('/orgs/accept-invitation'),
                        icon: const Icon(Icons.mark_email_read_outlined),
                        label: const Text('Accept Invitation'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/orgs/join'),
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Join with Organization Code'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          if (onCreateOrgTap != null) {
                            onCreateOrgTap!();
                          } else {
                            context.go('/orgs/create');
                          }
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create Organization'),
                      ),
                    ],
                  );
                }

                return orgsAsync.when(
                  loading: () => const LoadingView(message: 'Loading organization details...'),
                  error: (err, stack) => ErrorView(
                    message: 'Error loading organizations: $err',
                    onRetry: () => ref.invalidate(userOrganizationsProvider),
                  ),
                  data: (organizations) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Your Active Organizations',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Select an organization to switch your active context.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        ),
                        const SizedBox(height: 20),

                        ...organizations.map((org) {
                          final matchingMember = memberships.where((m) => m.organizationId == org.id).firstOrNull;
                          final isActiveContext = org.id == activeOrgId;

                          return _buildOrgCard(context, ref, org, matchingMember?.role, isActiveContext);
                        }),

                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (onCreateOrgTap != null) {
                              onCreateOrgTap!();
                            } else {
                              context.go('/orgs/create');
                            }
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Create New Organization'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            context.go('/orgs/join');
                          },
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                          label: const Text('Join Organization with Code'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => context.go('/orgs/accept-invitation'),
                          icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                          label: const Text('Accept an Invitation'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrgCard(
    BuildContext context,
    WidgetRef ref,
    Organization org,
    OrganizationRole? role,
    bool isActiveContext,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActiveContext ? AppTheme.primaryBlue : AppTheme.borderLight,
          width: isActiveContext ? 1.8 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isActiveContext
            ? null
            : () {
                ref.read(activeOrgIdProvider.notifier).selectOrganization(org.id);
              },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isActiveContext ? AppTheme.surfaceBlue : AppTheme.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      org.type == 'academic' ? Icons.school_rounded : Icons.business_rounded,
                      size: 26,
                      color: isActiveContext ? AppTheme.primaryBlue : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          org.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textSecondary),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                '${org.type.toUpperCase()} • ${org.city}, ${org.country}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (role != null) StatusBadge.role(role.value),
                  _buildOrgStatusBadge(org.status),
                ],
              ),
              if (isActiveContext) ...[
                const Divider(height: 28),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.go('/orgs/members'),
                      icon: const Icon(Icons.people_outline_rounded, size: 16),
                      label: const Text('Directory'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/orgs/departments'),
                      icon: const Icon(Icons.domain_outlined, size: 16),
                      label: const Text('Departments'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                    if (role == OrganizationRole.owner)
                      OutlinedButton.icon(
                        onPressed: () => context.go('/orgs/settings'),
                        icon: const Icon(Icons.palette_outlined, size: 16),
                        label: const Text('Branding'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    if (role == OrganizationRole.owner || role == OrganizationRole.admin)
                      OutlinedButton.icon(
                        onPressed: () => context.go('/orgs/audit'),
                        icon: const Icon(Icons.history_rounded, size: 16),
                        label: const Text('Activity'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrgStatusBadge(OrganizationStatus status) {
    if (status == OrganizationStatus.active || status == OrganizationStatus.verified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 13, color: AppTheme.success),
            SizedBox(width: 4),
            Text('VERIFIED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.success, letterSpacing: 0.5)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pending_rounded, size: 13, color: AppTheme.warning),
          SizedBox(width: 4),
          Text('PENDING VERIFICATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.warning, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}
