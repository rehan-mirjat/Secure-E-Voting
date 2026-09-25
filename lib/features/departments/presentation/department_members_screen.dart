import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/status_badge.dart';
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
      return const Scaffold(
        body: ErrorView(
          title: 'No Active Organization',
          message:
              'Please select an organization context to view department members.',
        ),
      );
    }

    final isManager = orgContext.member.role == OrganizationRole.owner ||
        orgContext.member.role == OrganizationRole.admin;

    final departmentsAsync = ref.watch(activeOrganizationDepartmentsProvider);
    final department = departmentsAsync.valueOrNull
        ?.where((d) => d.id == departmentId)
        .firstOrNull;

    if (department == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Department Members')),
        body: const LoadingView(message: 'Loading department details...'),
      );
    }

    final membersAsync = ref.watch(
        organizationMembersDirectoryProvider(orgContext.organization.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(department.name),
      ),
      body: membersAsync.when(
        loading: () =>
            const LoadingView(message: 'Loading department roster...'),
        error: (err, stack) =>
            ErrorView(message: 'Failed to load roster: $err'),
        data: (allMembers) {
          final compact = MediaQuery.sizeOf(context).width < 500;
          final deptMembers = allMembers.where((m) {
            final deptIds =
                List<String>.from(m['departmentIds'] as List? ?? []);
            final singleDept = m['departmentId'] as String?;
            return deptIds.contains(departmentId) || singleDept == departmentId;
          }).toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(compact ? 12 : 20,
                          compact ? 12 : 20, compact ? 12 : 20, 12),
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(compact ? 16 : 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              compact
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: AppTheme.surfaceBlue,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                  Icons.domain_rounded,
                                                  color: AppTheme.primaryBlue,
                                                  size: 24),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(department.name,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: AppTheme
                                                              .secondaryNavy)),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                      '${deptMembers.length} Assigned Member${deptMembers.length == 1 ? '' : 's'}',
                                                      style: const TextStyle(
                                                          fontSize: 13,
                                                          color: AppTheme
                                                              .textSecondary,
                                                          fontWeight:
                                                              FontWeight.w500)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (isManager) ...[
                                          const SizedBox(height: 12),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: ElevatedButton.icon(
                                              onPressed: () => showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    AddDepartmentMemberDialog(
                                                  organizationId: orgContext
                                                      .organization.id,
                                                  departmentId: department.id,
                                                  allMembers: allMembers,
                                                ),
                                              ),
                                              icon: const Icon(
                                                  Icons
                                                      .person_add_alt_1_rounded,
                                                  size: 16),
                                              label: const Text('Assign'),
                                            ),
                                          ),
                                        ],
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceBlue,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                              Icons.domain_rounded,
                                              color: AppTheme.primaryBlue,
                                              size: 24),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(department.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppTheme
                                                          .secondaryNavy)),
                                              const SizedBox(height: 2),
                                              Text(
                                                  '${deptMembers.length} Assigned Member${deptMembers.length == 1 ? '' : 's'}',
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      color: AppTheme
                                                          .textSecondary,
                                                      fontWeight:
                                                          FontWeight.w500)),
                                            ],
                                          ),
                                        ),
                                        if (isManager)
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    AddDepartmentMemberDialog(
                                                  organizationId: orgContext
                                                      .organization.id,
                                                  departmentId: department.id,
                                                  allMembers: allMembers,
                                                ),
                                              );
                                            },
                                            icon: const Icon(
                                                Icons.person_add_alt_1_rounded,
                                                size: 16),
                                            label: const Text('Assign'),
                                            style: ElevatedButton.styleFrom(
                                              minimumSize: const Size(0, 38),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 8),
                                            ),
                                          ),
                                      ],
                                    ),
                              if (department.description.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(department.description,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                        height: 1.4)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (deptMembers.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyView(
                        icon: Icons.group_off_outlined,
                        title: 'No Members Assigned',
                        message:
                            'No organization members have been assigned to this department yet.',
                        actionLabel: isManager ? 'Assign Member' : null,
                        onAction: isManager
                            ? () {
                                showDialog(
                                  context: context,
                                  builder: (context) =>
                                      AddDepartmentMemberDialog(
                                    organizationId: orgContext.organization.id,
                                    departmentId: department.id,
                                    allMembers: allMembers,
                                  ),
                                );
                              }
                            : null,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                          horizontal: compact ? 12 : 20, vertical: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final member = deptMembers[index];
                            final name =
                                member['displayName'] as String? ?? 'Member';
                            final email = member['email'] as String? ?? '';
                            final photoUrl =
                                member['photoUrl'] as String? ?? '';
                            final role = member['role'] as String? ?? 'member';
                            final userId = member['userId'] as String? ?? '';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: compact ? 10 : 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.surfaceBlue,
                                  backgroundImage: photoUrl.isNotEmpty
                                      ? NetworkImage(photoUrl)
                                      : null,
                                  child: photoUrl.isEmpty
                                      ? Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : 'M',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryBlue),
                                        )
                                      : null,
                                ),
                                title: Text(name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.secondaryNavy)),
                                subtitle: compact
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(email,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppTheme.textSecondary)),
                                          const SizedBox(height: 5),
                                          StatusBadge.role(role),
                                        ],
                                      )
                                    : Text(email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!compact) StatusBadge.role(role),
                                    if (isManager) ...[
                                      if (!compact) const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.remove_circle_outline_rounded,
                                            color: AppTheme.error,
                                            size: 20),
                                        tooltip: 'Remove from Department',
                                        onPressed: () async {
                                          try {
                                            await ref
                                                .read(
                                                    departmentRepositoryProvider)
                                                .removeMemberFromDepartment(
                                                  organizationId: orgContext
                                                      .organization.id,
                                                  targetUid: userId,
                                                );
                                            ref.invalidate(
                                                organizationMembersDirectoryProvider(
                                                    orgContext
                                                        .organization.id));
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'Removed $name from department.')),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text('Failed: $e'),
                                                    backgroundColor:
                                                        AppTheme.error),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: deptMembers.length,
                        ),
                      ),
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
