import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.domain, color: AppTheme.primaryBlue),
                  title: Text(dept.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(dept.description.isNotEmpty ? dept.description : 'No description', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: isManager
                      ? PopupMenuButton<String>(
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
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.error))),
                          ],
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
