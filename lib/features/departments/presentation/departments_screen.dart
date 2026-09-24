import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../organizations/domain/organization_enums.dart';
import '../../organizations/presentation/providers/organization_providers.dart';
import '../domain/department.dart';
import 'create_edit_department_dialog.dart';
import 'providers/department_providers.dart';
import '../data/department_repository.dart';

class DepartmentsScreen extends ConsumerWidget {
  const DepartmentsScreen({super.key});

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Department dept) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Department', style: TextStyle(color: AppTheme.error)),
        content: Text('Are you sure you want to delete "${dept.name}"?\n\nThis permanently deletes the department. Existing member records may retain a reference to the deleted department, but the deleted department will no longer be valid for assignment or voting eligibility.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(departmentRepositoryProvider).deleteDepartment(dept.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Department deleted successfully.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: ${e.toString().replaceAll("Exception: ", "")}'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeContextState = ref.watch(activeOrganizationContextProvider);
    final departmentsAsync = ref.watch(activeOrganizationDepartmentsProvider);

    final orgContext = activeContextState.valueOrNull?.context;
    if (orgContext == null) {
      return const Scaffold(
        body: Center(child: Text('No active organization context.')),
      );
    }

    final isManager = orgContext.member.role == OrganizationRole.owner || orgContext.member.role == OrganizationRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Departments'),
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => CreateEditDepartmentDialog(organizationId: orgContext.organization.id),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('New Department'),
            )
          : null,
      body: departmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: ${err.toString()}', style: const TextStyle(color: AppTheme.error))),
        data: (departments) {
          if (departments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.domain_disabled_outlined, size: 64, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  const Text('No Departments Found', style: TextStyle(fontSize: 20, color: AppTheme.secondaryNavy)),
                  const SizedBox(height: 8),
                  if (isManager)
                    const Text('Create departments to organize members and restrict voting eligibility.', style: TextStyle(color: AppTheme.textSecondary))
                  else
                    const Text('This organization has no departments.', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: departments.length,
            itemBuilder: (context, index) {
              final dept = departments[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppTheme.borderLight),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  hoverColor: AppTheme.surfaceBlue.withValues(alpha: 0.3),
                  onTap: () => context.go('/orgs/departments/${dept.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.domain, color: AppTheme.primaryBlue, size: 28),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dept.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy)),
                              if (dept.description.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(dept.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ]
                            ],
                          ),
                        ),
                        if (isManager) ...[
                          const SizedBox(width: 16),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                            onSelected: (value) {
                              if (value == 'edit') {
                                showDialog(
                                  context: context,
                                  builder: (context) => CreateEditDepartmentDialog(
                                    organizationId: orgContext.organization.id,
                                    departmentToEdit: dept,
                                  ),
                                );
                              } else if (value == 'delete') {
                                _showDeleteConfirmation(context, ref, dept);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: AppTheme.error), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppTheme.error))])),
                            ],
                          ),
                        ],
                      ],
                    ),
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
