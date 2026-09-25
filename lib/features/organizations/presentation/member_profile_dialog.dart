import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/organization_repository.dart';
import '../domain/organization_enums.dart';

class MemberProfileDialog extends ConsumerStatefulWidget {
  const MemberProfileDialog({
    super.key,
    required this.organizationId,
    required this.callerRole,
    required this.memberData,
    required this.onChanged,
  });

  final String organizationId;
  final OrganizationRole callerRole;
  final Map<String, dynamic> memberData;
  final VoidCallback onChanged;

  @override
  ConsumerState<MemberProfileDialog> createState() => _MemberProfileDialogState();
}

class _MemberProfileDialogState extends ConsumerState<MemberProfileDialog> {
  bool _isLoading = false;

  Future<void> _performAction(Future<void> Function() action, String successMessage) async {
    setState(() => _isLoading = true);
    try {
      await action();
      if (mounted) {
        Navigator.pop(context);
        widget.onChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetUid = widget.memberData['userId'] as String? ?? '';
    final displayName = widget.memberData['displayName'] as String? ?? 'User';
    final email = widget.memberData['email'] as String? ?? '';
    final roleStr = widget.memberData['role'] as String? ?? 'member';
    final statusStr = widget.memberData['status'] as String? ?? 'active';
    final deptName = widget.memberData['departmentName'] as String? ?? 'None';

    final isTargetOwner = roleStr.toLowerCase() == 'owner';
    final isTargetAdmin = roleStr.toLowerCase() == 'admin';
    final isTargetMember = roleStr.toLowerCase() == 'member';
    final isTargetActive = statusStr.toLowerCase() == 'active';

    final isCallerOwner = widget.callerRole == OrganizationRole.owner;
    final isCallerAdmin = widget.callerRole == OrganizationRole.admin;

    final canManageRole = isCallerOwner && !isTargetOwner;
    final canManageStatus = (isCallerOwner && !isTargetOwner) || (isCallerAdmin && isTargetMember);
    final canRemove = (isCallerOwner && !isTargetOwner) || (isCallerAdmin && isTargetMember);

    final repo = ref.read(organizationRepositoryProvider);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryBlue,
            child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(email, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          _infoRow('Role', roleStr.toUpperCase()),
          _infoRow('Status', statusStr.toUpperCase()),
          _infoRow('Department', deptName),
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
      actions: [
        if (!_isLoading) ...[
          if (canManageRole && isTargetMember)
            TextButton(
              onPressed: () => _performAction(
                () => repo.updateMemberRole(organizationId: widget.organizationId, targetUid: targetUid, newRole: 'admin'),
                'Promoted to Admin successfully.',
              ),
              child: const Text('Promote to Admin'),
            ),
          if (canManageRole && isTargetAdmin)
            TextButton(
              onPressed: () => _performAction(
                () => repo.updateMemberRole(organizationId: widget.organizationId, targetUid: targetUid, newRole: 'member'),
                'Demoted to Member successfully.',
              ),
              child: const Text('Demote to Member'),
            ),
          if (canManageStatus && isTargetActive)
            TextButton(
              onPressed: () => _performAction(
                () => repo.updateMemberStatus(organizationId: widget.organizationId, targetUid: targetUid, newStatus: 'inactive'),
                'Deactivated member successfully.',
              ),
              child: const Text('Deactivate', style: TextStyle(color: Colors.orange)),
            ),
          if (canManageStatus && !isTargetActive)
            TextButton(
              onPressed: () => _performAction(
                () => repo.updateMemberStatus(organizationId: widget.organizationId, targetUid: targetUid, newStatus: 'active'),
                'Reactivated member successfully.',
              ),
              child: const Text('Reactivate', style: TextStyle(color: AppTheme.success)),
            ),
          if (canRemove)
            TextButton(
              onPressed: () => _performAction(
                () => repo.removeMember(organizationId: widget.organizationId, targetUid: targetUid),
                'Removed member permanently.',
              ),
              child: const Text('Remove', style: TextStyle(color: AppTheme.error)),
            ),
        ],
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy)),
          Expanded(child: Text(value, textAlign: TextAlign.end, softWrap: true, style: const TextStyle(color: AppTheme.textSecondary))),
        ],
      ),
    );
  }
}
