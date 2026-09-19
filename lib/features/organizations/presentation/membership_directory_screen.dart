import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/organization_repository.dart';
import 'member_profile_dialog.dart';
import 'providers/organization_providers.dart';

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
  String _searchQuery = '';
  String _selectedRoleFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Directory',
            onPressed: () => ref.invalidate(organizationMembersDirectoryProvider(orgId)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search by name or email...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedRoleFilter,
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

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No members found.', style: TextStyle(color: AppTheme.textSecondary)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final member = filtered[index];
                    final name = member['displayName'] as String? ?? 'Unknown User';
                    final email = member['email'] as String? ?? '';
                    final role = (member['role'] as String? ?? 'member').toUpperCase();
                    final status = member['status'] as String? ?? 'active';
                    final deptName = member['departmentName'] as String?;

                    final isInactive = status == 'inactive';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isInactive ? Colors.grey.shade400 : AppTheme.primaryBlue,
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white)),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isInactive ? Colors.grey : AppTheme.secondaryNavy,
                                decoration: isInactive ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: role == 'OWNER'
                                  ? Colors.amber.shade100
                                  : role == 'ADMIN'
                                      ? Colors.blue.shade100
                                      : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              role,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: role == 'OWNER'
                                    ? Colors.amber.shade900
                                    : role == 'ADMIN'
                                        ? Colors.blue.shade900
                                        : Colors.grey.shade800,
                              ),
                            ),
                          ),
                          if (isInactive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'INACTIVE',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        '$email${deptName != null ? " • $deptName" : ""}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => MemberProfileDialog(
                            organizationId: orgId,
                            callerRole: callerRole,
                            memberData: member,
                            onChanged: () => ref.invalidate(organizationMembersDirectoryProvider(orgId)),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
