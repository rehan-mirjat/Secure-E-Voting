import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'providers/organization_providers.dart';

class OrganizationContextSwitcher extends ConsumerWidget {
  const OrganizationContextSwitcher({super.key});

  void _showSwitcherModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final membershipsAsync = ref.watch(userMembershipsProvider);
            final orgsAsync = ref.watch(userOrganizationsProvider);
            final activeOrgStateAsync = ref.watch(activeOrganizationContextProvider);

            final activeOrgId = activeOrgStateAsync.valueOrNull?.context?.organization.id;
            final memberships = membershipsAsync.valueOrNull ?? [];
            final organizations = orgsAsync.valueOrNull ?? [];

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Switch Organization',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (organizations.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No joined organizations found.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ] else ...[
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: organizations.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final org = organizations[index];
                          final member = memberships.where((m) => m.organizationId == org.id).firstOrNull;
                          final isSelected = org.id == activeOrgId;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            leading: Icon(
                              isSelected ? Icons.check_circle : Icons.business,
                              color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
                            ),
                            title: Text(
                              org.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppTheme.primaryBlue : AppTheme.textPrimary,
                              ),
                            ),
                            subtitle: member != null
                                ? Text(
                                    'Role: ${member.role.value.toUpperCase()}',
                                    style: const TextStyle(fontSize: 12),
                                  )
                                : null,
                            trailing: isSelected
                                ? const Icon(Icons.check, color: AppTheme.primaryBlue)
                                : null,
                            onTap: () {
                              ref.read(activeOrgIdProvider.notifier).selectOrganization(org.id);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Close the bottom sheet
                      context.go('/orgs/create'); // Use GoRouter instead of Navigator.push
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Organization'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeContextState = ref.watch(activeOrganizationContextProvider);

    return activeContextState.when(
      loading: () => const SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const Text('Org Context Error'),
      data: (state) {
        final contextObj = state.context;

        if (contextObj == null) {
          return ActionChip(
            avatar: const Icon(Icons.business_outlined, size: 16),
            label: const Text('Select Organization'),
            onPressed: () => _showSwitcherModal(context, ref),
          );
        }

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showSwitcherModal(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.business_rounded, color: AppTheme.primaryBlue, size: 20),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contextObj.organization.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.secondaryNavy),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      contextObj.member.role.value.toUpperCase(),
                      style: const TextStyle(fontSize: 10, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}
