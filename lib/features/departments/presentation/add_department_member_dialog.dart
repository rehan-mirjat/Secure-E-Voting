import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../organizations/presentation/membership_directory_screen.dart';
import '../data/department_repository.dart';

class AddDepartmentMemberDialog extends ConsumerStatefulWidget {
  const AddDepartmentMemberDialog({
    super.key,
    required this.organizationId,
    required this.departmentId,
    required this.allMembers,
  });

  final String organizationId;
  final String departmentId;
  final List<Map<String, dynamic>> allMembers;

  @override
  ConsumerState<AddDepartmentMemberDialog> createState() => _AddDepartmentMemberDialogState();
}

class _AddDepartmentMemberDialogState extends ConsumerState<AddDepartmentMemberDialog> {
  String _searchQuery = '';
  bool _isLoading = false;

  Future<void> _assignMember(String targetUid) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(departmentRepositoryProvider).assignMemberToDepartment(
            organizationId: widget.organizationId,
            targetUid: targetUid,
            departmentId: widget.departmentId,
          );
      ref.invalidate(organizationMembersDirectoryProvider(widget.organizationId));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member assigned successfully.'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign member: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final compact = screenSize.width < 440;
    final availableMembers = widget.allMembers.where((m) {
      final isNotInDept = m['departmentId'] != widget.departmentId;
      final isActive = m['status'] == 'active';
      final name = (m['displayName'] as String? ?? '').toLowerCase();
      final email = (m['email'] as String? ?? '').toLowerCase();
      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery) || email.contains(_searchQuery);
      return isNotInDept && isActive && matchesSearch;
    }).toList();

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Add Member to Department'),
      content: SizedBox(
        width: (screenSize.width - 80).clamp(200.0, 560.0).toDouble(),
        height: (screenSize.height * 0.58).clamp(240.0, 500.0).toDouble(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search active members...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: availableMembers.isEmpty
                  ? const Center(child: Text('No eligible members found.', style: TextStyle(color: AppTheme.textSecondary)))
                  : ListView.separated(
                      itemCount: availableMembers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final member = availableMembers[index];
                        final name = member['displayName'] as String? ?? 'Unknown User';
                        final email = member['email'] as String? ?? '';
                        final targetUid = member['userId'] as String;
                        final currentDept = member['departmentName'] as String?;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryBlue,
                            child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy)),
                          subtitle: Text('$email${currentDept != null ? ' • currently in $currentDept' : ''}', style: const TextStyle(color: AppTheme.textSecondary)),
                          trailing: compact
                              ? IconButton.filledTonal(
                                  tooltip: 'Add member',
                                  onPressed: _isLoading ? null : () => _assignMember(targetUid),
                                  icon: const Icon(Icons.person_add_alt_1_rounded),
                                )
                              : ElevatedButton(
                                  onPressed: _isLoading ? null : () => _assignMember(targetUid),
                                  child: const Text('Add member'),
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
