import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
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
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: membershipsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text('Error loading memberships: ${err.toString()}', style: const TextStyle(color: AppTheme.error)),
              ),
              data: (memberships) {
                if (memberships.isEmpty) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.corporate_fare_outlined,
                        size: 72,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No Joined Organizations',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You do not belong to any active organizations yet. Create an organization or join one with a code.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () {
                          if (onCreateOrgTap != null) {
                            onCreateOrgTap!();
                          } else {
                            context.go('/orgs/create');
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Create Organization'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Joining with code will be enabled in Step 4.')),
                          );
                        },
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Join Organization with Code'),
                      ),
                    ],
                  );
                }

                return orgsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Text('Error loading organization details: ${err.toString()}', style: const TextStyle(color: AppTheme.error)),
                  ),
                  data: (organizations) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Your Active Organizations',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Select an organization to switch your active context.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        ),
                        const SizedBox(height: 20),

                        ...organizations.map((org) {
                          final matchingMember = memberships.where((m) => m.organizationId == org.id).firstOrNull;
                          final isActiveContext = org.id == activeOrgId;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 20),
                            elevation: isActiveContext ? 4 : 0,
                            shadowColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isActiveContext ? AppTheme.primaryBlue : AppTheme.borderLight,
                                width: isActiveContext ? 1.5 : 1.0,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              hoverColor: AppTheme.surfaceBlue.withValues(alpha: 0.3),
                              onTap: isActiveContext ? null : () {
                                ref.read(activeOrgIdProvider.notifier).selectOrganization(org.id);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: isActiveContext ? AppTheme.surfaceBlue : AppTheme.backgroundLight,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        org.type == 'academic' ? Icons.school : Icons.business,
                                        size: 32,
                                        color: isActiveContext ? AppTheme.primaryBlue : AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            org.name,
                                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${org.type.toUpperCase()} • ${org.city}, ${org.country}',
                                                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              if (matchingMember != null) _buildRoleBadge(matchingMember.role),
                                              const SizedBox(width: 8),
                                              _buildStatusBadge(org.status),
                                            ],
                                          ),
                                          if (isActiveContext) ...[
                                            const SizedBox(height: 20),
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 12,
                                              children: [
                                                ElevatedButton.icon(
                                                  onPressed: () => context.go('/orgs/members'),
                                                  icon: const Icon(Icons.people_outline, size: 18),
                                                  label: const Text('Members & Invites'),
                                                ),
                                                OutlinedButton.icon(
                                                  onPressed: () => context.go('/orgs/departments'),
                                                  icon: const Icon(Icons.domain_outlined, size: 18),
                                                  label: const Text('Departments'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (isActiveContext)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceBlue,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle, size: 18, color: AppTheme.primaryBlue),
                                            SizedBox(width: 8),
                                            Text('Active Organization', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                                          ],
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.backgroundLight,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: AppTheme.borderLight),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.swap_horiz, size: 18, color: AppTheme.primaryBlue),
                                            SizedBox(width: 8),
                                            Text('Switch Context', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(width: 16),
                                    const Icon(Icons.chevron_right, color: AppTheme.borderLight),
                                  ],
                                ),
                              ),
                            ),
                          );
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
                          icon: const Icon(Icons.add),
                          label: const Text('Create New Organization'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Joining with code will be enabled in Step 4.')),
                            );
                          },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Join Organization with Code'),
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

  Widget _buildRoleBadge(OrganizationRole role) {
    Color bg;
    Color fg;
    String label;

    switch (role) {
      case OrganizationRole.owner:
        bg = AppTheme.primaryBlue.withValues(alpha: 0.1);
        fg = AppTheme.primaryBlue;
        label = 'OWNER';
        break;
      case OrganizationRole.admin:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        label = 'ADMIN';
        break;
      case OrganizationRole.member:
        bg = Colors.grey.shade100;
        fg = AppTheme.secondaryNavy;
        label = 'MEMBER';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _buildStatusBadge(OrganizationStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case OrganizationStatus.active:
      case OrganizationStatus.verified:
        bg = AppTheme.success.withValues(alpha: 0.1);
        fg = AppTheme.success;
        label = 'VERIFIED';
        break;
      case OrganizationStatus.pending:
      default:
        bg = AppTheme.warning.withValues(alpha: 0.1);
        fg = AppTheme.warning;
        label = 'PENDING VERIFICATION';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}
