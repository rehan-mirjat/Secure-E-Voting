import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../organizations/domain/organization_enums.dart';
import '../../organizations/presentation/membership_directory_screen.dart';
import '../../organizations/presentation/providers/organization_providers.dart';
import '../data/department_repository.dart';
import 'add_department_member_dialog.dart';
import 'providers/department_providers.dart';

class DepartmentMembersScreen extends ConsumerWidget {
  const DepartmentMembersScreen({super.key, required this.departmentId});

  final String departmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeContextState = ref.watch(activeOrganizationContextProvider);
    final orgContext = activeContextState.valueOrNull?.context;

    if (orgContext == null) {
      return const Scaffold(body: Center(child: Text('No active organization context.')));
    }

    final isManager = orgContext.member.role == OrganizationRole.owner || orgContext.member.role == OrganizationRole.admin;

    final departmentsAsync = ref.watch(activeOrganizationDepartmentsProvider);
    final department = departmentsAsync.valueOrNull?.where((d) => d.id == departmentId).firstOrNull;

    if (department == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Department Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final membersAsync = ref.watch(organizationMembersDirectoryProvider(orgContext.organization.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(department.name),
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.error))),
        data: (allMembers) {
          final deptMembers = allMembers.where((m) => m['departmentId'] == departmentId).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(department.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy)),
                    if (department.description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(department.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Members (${deptMembers.length})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy)),
                    if (isManager)
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AddDepartmentMemberDialog(
                              organizationId: orgContext.organization.id,
                              departmentId: departmentId,
                              allMembers: allMembers,
                            ),
                          );
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add Member'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: deptMembers.isEmpty
                    ? const Center(
                        child: Text('No members assigned to this department yet.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                        itemCount: deptMembers.length,
                        itemBuilder: (context, index) {
                          final member = deptMembers[index];
                          final name = member['displayName'] as String? ?? 'Unknown User';
                          final email = member['email'] as String? ?? '';
                          final role = (member['role'] as String? ?? 'member').toUpperCase();
                          final status = member['status'] as String? ?? 'active';
                          final targetUid = member['userId'] as String;

                          final isInactive = status == 'inactive';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppTheme.borderLight),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: isInactive ? Colors.grey.shade400 : AppTheme.primaryBlue,
                                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isInactive ? Colors.grey : AppTheme.secondaryNavy, decoration: isInactive ? TextDecoration.lineThrough : null)),
                                        const SizedBox(height: 4),
                                        Text(email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text('Org Role: $role', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy)),
                                      ),
                                      if (isInactive) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.error.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text('INACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.error)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (isManager) ...[
                                    const SizedBox(width: 24),
                                    OutlinedButton.icon(
                                      onPressed: () => _confirmRemoveMember(context, ref, orgContext.organization.id, targetUid, name),
                                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error, side: const BorderSide(color: AppTheme.error)),
                                      icon: const Icon(Icons.person_remove, size: 18),
                                      label: const Text('Remove'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmRemoveMember(BuildContext context, WidgetRef ref, String orgId, String targetUid, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member from department?'),
        content: Text('Are you sure you want to remove $name from this department?\n\nThis only removes their department assignment. They will remain a member of the organization.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(departmentRepositoryProvider).removeMemberFromDepartment(organizationId: orgId, targetUid: targetUid);
        ref.invalidate(organizationMembersDirectoryProvider(orgId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member removed from department.'), backgroundColor: AppTheme.success));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to remove member: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: AppTheme.error));
        }
      }
    }
  }
}
