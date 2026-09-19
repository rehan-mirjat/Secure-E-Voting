import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/organization_repository.dart';

final pendingInvitationsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, organizationId) async {
  return ref.watch(organizationRepositoryProvider).getPendingInvitations(organizationId);
});

class PendingInvitationsWidget extends ConsumerWidget {
  const PendingInvitationsWidget({
    super.key,
    required this.organizationId,
    required this.isOwner,
  });

  final String organizationId;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(pendingInvitationsProvider(organizationId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pending Invitations',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Invitations',
                  onPressed: () => ref.invalidate(pendingInvitationsProvider(organizationId)),
                ),
              ],
            ),
            const Divider(height: 20),

            invitationsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => Text(
                'Error fetching invitations: ${err.toString()}',
                style: const TextStyle(color: AppTheme.error),
              ),
              data: (invitations) {
                if (invitations.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No pending invitations found for this organization.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: invitations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = invitations[index];
                    final email = item['email'] as String? ?? '';
                    final role = item['role'] as String? ?? 'member';
                    final invitationId = item['invitationId'] as String? ?? '';

                    final isAdminRole = role.toLowerCase() == 'admin';
                    final canRevoke = isOwner || !isAdminRole;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.mark_email_unread_outlined, color: AppTheme.primaryBlue),
                      title: Text(email, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('Role: ${role.toUpperCase()}', style: const TextStyle(fontSize: 12)),
                      trailing: canRevoke
                          ? OutlinedButton(
                              onPressed: () async {
                                try {
                                  await ref.read(organizationRepositoryProvider).revokeInvitation(invitationId);
                                  ref.invalidate(pendingInvitationsProvider(organizationId));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Invitation revoked successfully.')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to revoke invitation: ${e.toString().replaceAll("Exception: ", "")}'),
                                        backgroundColor: AppTheme.error,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.error,
                                side: const BorderSide(color: AppTheme.error),
                              ),
                              child: const Text('Revoke'),
                            )
                          : const Tooltip(
                              message: 'Only Owner can revoke Admin-level invitations',
                              child: Icon(Icons.lock_outline, size: 18, color: AppTheme.textSecondary),
                            ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
