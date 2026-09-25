import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/layout/responsive.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
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

  Widget _directoryHeading(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Member Directory', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Manage organization members, roles, and status.', style: Theme.of(context).textTheme.bodyMedium),
        ],
      );

  Widget _inviteButton(BuildContext context, String orgId, String orgName, OrganizationRole role) =>
      ElevatedButton.icon(
        onPressed: () => showDialog(
          context: context,
          builder: (ctx) => InviteMemberDialog(
            organizationId: orgId,
            organizationName: orgName,
            isOwner: role == OrganizationRole.owner,
          ),
        ),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Invite member'),
      );

  Widget _memberSearchField() => TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Search members by name or email',
          prefixIcon: Icon(Icons.search_rounded),
        ),
        onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
      );

  Widget _roleFilter(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: _selectedRoleFilter,
        decoration: const InputDecoration(labelText: 'Filter by role'),
        isExpanded: true,
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All roles')),
          DropdownMenuItem(value: 'owner', child: Text('Owners')),
          DropdownMenuItem(value: 'admin', child: Text('Admins')),
          DropdownMenuItem(value: 'member', child: Text('Members')),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _selectedRoleFilter = value);
        },
      );

  @override
  Widget build(BuildContext context) {
    final activeContextState = ref.watch(activeOrganizationContextProvider);

    return activeContextState.when(
      loading: () => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: const LoadingView(message: 'Restoring active organization context...'),
      ),
      error: (err, stack) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ErrorView(
          message: 'Failed to load organization context: $err',
          onRetry: () => ref.invalidate(activeOrganizationContextProvider),
        ),
      ),
      data: (state) {
        final compact = ResponsiveLayout.isCompact(context);
        final orgContext = state.context;

        if (orgContext == null) {
          return Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const EmptyView(
              icon: Icons.corporate_fare_outlined,
              title: 'No Active Organization Selected',
              message: 'Please select an organization context to view the member directory.',
            ),
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
            child: Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(compact ? 16 : 32, compact ? 20 : 32, compact ? 16 : 32, 16),
                    child: compact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _directoryHeading(context),
                              if (callerRole == OrganizationRole.owner || callerRole == OrganizationRole.admin) ...[
                                const SizedBox(height: 14),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _inviteButton(context, orgId, orgContext.organization.name, callerRole),
                                ),
                              ],
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: _directoryHeading(context)),
                              if (callerRole == OrganizationRole.owner || callerRole == OrganizationRole.admin)
                                _inviteButton(context, orgId, orgContext.organization.name, callerRole),
                            ],
                          ),
                  ),
                  Expanded(
                    child: membersAsync.when(
                      loading: () => const LoadingView(message: 'Loading member directory...'),
                      error: (err, stack) => ErrorView(
                        message: 'Error loading directory: $err',
                        onRetry: () => ref.invalidate(organizationMembersDirectoryProvider(orgId)),
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
                                  padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 32, vertical: 12),
                                  child: compact
                                      ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [_memberSearchField(), const SizedBox(height: 10), _roleFilter(context)],
                                        )
                                      : Row(
                                          children: [
                                            Expanded(flex: 3, child: _memberSearchField()),
                                            const SizedBox(width: 16),
                                            Expanded(flex: 1, child: _roleFilter(context)),
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
                                          padding: EdgeInsets.fromLTRB(compact ? 16 : 32, 0, compact ? 16 : 32, 20),
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
                                          padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 32, vertical: 8),
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
                                                  padding: EdgeInsets.all(compact ? 12 : 20),
                                                  child: Row(
                                                    children: [
                                                      CircleAvatar(
                                                        radius: compact ? 20 : 24,
                                                        backgroundColor: isInactive ? Colors.grey.shade300 : AppTheme.primaryBlue.withValues(alpha: 0.1),
                                                        child: Text(
                                                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                                          style: TextStyle(color: isInactive ? Colors.grey.shade600 : AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 18),
                                                        ),
                                                      ),
                                                      SizedBox(width: compact ? 12 : 20),
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
                                                                Flexible(
                                                                  child: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis,
                                                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                                                ),
                                                              ],
                                                            ),
                                                            if (deptName != null && deptName.isNotEmpty) ...[
                                                              const SizedBox(height: 4),
                                                              Row(
                                                                children: [
                                                                  const Icon(Icons.domain_outlined, size: 14, color: AppTheme.textSecondary),
                                                                  const SizedBox(width: 6),
                                                                  Flexible(
                                                                    child: Text(deptName, maxLines: 1, overflow: TextOverflow.ellipsis,
                                                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                                                  ),
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
                                                        SizedBox(width: compact ? 6 : 16),
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
  },
);
}
}
