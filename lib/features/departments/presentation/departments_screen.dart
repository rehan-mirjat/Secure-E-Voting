import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
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
        body: ErrorView(
          title: 'No Active Organization',
          message: 'Please select an organization context to view departments.',
        ),
      );
    }

    final isManager = orgContext.member.role == OrganizationRole.owner || orgContext.member.role == OrganizationRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Departments'),
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              key: const ValueKey('departments_screen_fab'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => CreateEditDepartmentDialog(organizationId: orgContext.organization.id),
                );
              },
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Department'),
            )
          : null,
      body: departmentsAsync.when(
        loading: () => const LoadingView(message: 'Loading departments...'),
        error: (err, stack) => ErrorView(
          message: 'Failed to load departments: $err',
          onRetry: () => ref.invalidate(activeOrganizationDepartmentsProvider),
        ),
        data: (departments) {
          if (departments.isEmpty) {
            return EmptyView(
              icon: Icons.domain_disabled_outlined,
              title: 'No Departments Found',
              message: isManager
                  ? 'Create departments to organize members and restrict voting eligibility.'
                  : 'This organization has no departments.',
              actionLabel: isManager ? 'Create Department' : null,
              onAction: isManager
                  ? () {
                      showDialog(
                        context: context,
                        builder: (context) => CreateEditDepartmentDialog(organizationId: orgContext.organization.id),
                      );
                    }
                  : null,
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceBlue,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.domain_rounded, color: AppTheme.primaryBlue, size: 26),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dept.name,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
                                  ),
                                  if (dept.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      dept.description,
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isManager) ...[
                              const SizedBox(width: 12),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
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
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('Edit')]),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: AppTheme.error), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppTheme.error))]),
                                  ),
                                ],
                              ),
                            ] else
                              const Icon(Icons.chevron_right_rounded, color: AppTheme.borderLight),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
