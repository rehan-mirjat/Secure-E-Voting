import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/organization_enums.dart';
import '../data/organization_repository.dart';
import 'invite_member_dialog.dart';
import 'member_profile_dialog.dart';
import 'providers/organization_providers.dart';
import 'pending_invitations_widget.dart';

final organizationMembersDirectoryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, orgId) async {
  final repo = ref.watch(organizationRepositoryProvider);
  final result = await repo.getOrganizationMembers(organizationId: orgId);
  return result.members;
});

class MembershipDirectoryScreen extends ConsumerStatefulWidget {
  const MembershipDirectoryScreen({super.key});

  @override
  ConsumerState<MembershipDirectoryScreen> createState() => _MembershipDirectoryScreenState();
}

class _MembershipDirectoryScreenState extends ConsumerState<MembershipDirectoryScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _selectedRoleFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeContextState = ref.watch(activeOrganizationContextProvider);
    final orgContext = activeContextState.valueOrNull?.context;

    if (orgContext == null) {
      return const Scaffold(
        body: Center(child: Text('No active organization selected.')),
      );
    }

    final orgId = orgContext.organization.id;
    final callerRole = orgContext.member.role;
    final membersAsync = ref.watch(organizationMembersDirectoryProvider(orgId));

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.slash): () => _searchFocusNode.requestFocus(),
      },
      child: FocusScope(
        autofocus: true,
        child: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Member Directory',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondaryNavy,
                                ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Manage organization members, roles, and status.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    if (callerRole == OrganizationRole.owner || callerRole == OrganizationRole.admin)
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => InviteMemberDialog(
                              organizationId: orgId,
                              organizationName: orgContext.organization.name,
                              isOwner: callerRole == OrganizationRole.owner,
                            ),
                          );
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Invite Member'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: membersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Text('Error loading directory: ${err.toString()}', style: const TextStyle(color: AppTheme.error)),
                  ),
                  data: (members) {
                    final filtered = members.where((m) {
                      final name = (m['displayName'] as String? ?? '').toLowerCase();
                      final email = (m['email'] as String? ?? '').toLowerCase();
                      final role = (m['role'] as String? ?? '').toLowerCase();

                      final matchesQuery = _searchQuery.isEmpty || name.contains(_searchQuery) || email.contains(_searchQuery);
                      final matchesRole = _selectedRoleFilter == 'all' || role == _selectedRoleFilter;

                      return matchesQuery && matchesRole;
                    }).toList();

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      textInputAction: TextInputAction.search,
                                      decoration: InputDecoration(
                                        hintText: 'Search members by name or email... (Press /)',
                                        prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: AppTheme.borderLight),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: AppTheme.borderLight),
                                        ),
                                      ),
                                      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 1,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppTheme.borderLight),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          value: _selectedRoleFilter,
                                          icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
                                          items: const [
                                            DropdownMenuItem(value: 'all', child: Text('All Roles')),
                                            DropdownMenuItem(value: 'owner', child: Text('Owners')),
                                            DropdownMenuItem(value: 'admin', child: Text('Admins')),
                                            DropdownMenuItem(value: 'member', child: Text('Members')),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) setState(() => _selectedRoleFilter = val);
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: () async {
                                  ref.invalidate(organizationMembersDirectoryProvider(orgId));
                                  try {
                                    await ref.read(organizationMembersDirectoryProvider(orgId).future);
                                  } catch (_) {}
                                },
                                child: SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      if (callerRole == OrganizationRole.owner || callerRole == OrganizationRole.admin)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                                          child: PendingInvitationsWidget(
                                            organizationId: orgId,
                                            isOwner: callerRole == OrganizationRole.owner,
                                          ),
                                        ),
                                      if (filtered.isEmpty)
                                        Container(
                                          height: MediaQuery.of(context).size.height * 0.3,
                                          alignment: Alignment.center,
                                          child: const Text('No members found.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                                        )
                                      else
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                                          itemCount: filtered.length,
                                          itemBuilder: (context, index) {
                                            final member = filtered[index];
                                            final name = member['displayName'] as String? ?? 'Unknown User';
                                            final email = member['email'] as String? ?? '';
                                            final role = (member['role'] as String? ?? 'member').toUpperCase();
                                            final status = member['status'] as String? ?? 'active';
                                            final deptName = member['departmentName'] as String?;

                                            final isInactive = status == 'inactive';

                                            return Card(
                                              margin: const EdgeInsets.only(bottom: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                                side: const BorderSide(color: AppTheme.borderLight),
                                              ),
                                              child: InkWell(
                                                borderRadius: BorderRadius.circular(16),
                                                hoverColor: AppTheme.surfaceBlue.withValues(alpha: 0.3),
                                                onTap: (callerRole == OrganizationRole.owner || callerRole == OrganizationRole.admin)
                                                    ? () {
                                                        showDialog(
                                                          context: context,
                                                          builder: (ctx) => MemberProfileDialog(
                                                            organizationId: orgId,
                                                            callerRole: callerRole,
                                                            memberData: member,
                                                            onChanged: () => ref.invalidate(organizationMembersDirectoryProvider(orgId)),
                                                          ),
                                                        );
                                                      }
                                                    : null,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(20),
                                                  child: Row(
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 24,
                                                        backgroundColor: isInactive ? Colors.grey.shade300 : AppTheme.primaryBlue.withValues(alpha: 0.1),
                                                        child: Text(
                                                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                                          style: TextStyle(color: isInactive ? Colors.grey.shade600 : AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 18),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 20),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              name,
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                fontWeight: FontWeight.bold,
                                                                color: isInactive ? Colors.grey : AppTheme.secondaryNavy,
                                                                decoration: isInactive ? TextDecoration.lineThrough : null,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Row(
                                                              children: [
                                                                const Icon(Icons.email_outlined, size: 14, color: AppTheme.textSecondary),
                                                                const SizedBox(width: 6),
                                                                Text(email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                                              ],
                                                            ),
                                                            if (deptName != null && deptName.isNotEmpty) ...[
                                                              const SizedBox(height: 4),
                                                              Row(
                                                                children: [
                                                                  const Icon(Icons.domain_outlined, size: 14, color: AppTheme.textSecondary),
                                                                  const SizedBox(width: 6),
                                                                  Text(deptName, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                                                ],
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                      Column(
                                                        crossAxisAlignment: CrossAxisAlignment.end,
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: role == 'OWNER' ? AppTheme.primaryBlue.withValues(alpha: 0.1) : Colors.grey.shade100,
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: Text(
                                                              role,
                                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: role == 'OWNER' ? AppTheme.primaryBlue : AppTheme.secondaryNavy),
                                                            ),
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
                                                      if (callerRole == OrganizationRole.owner || callerRole == OrganizationRole.admin) ...[
                                                        const SizedBox(width: 16),
                                                        const Icon(Icons.chevron_right, color: AppTheme.borderLight),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
