import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/organization_repository.dart';

final pendingInvitationsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, organizationId) async {
  return ref
      .watch(organizationRepositoryProvider)
      .getPendingInvitations(organizationId);
});

class PendingInvitationsWidget extends ConsumerWidget {
  const PendingInvitationsWidget({
    super.key,
    required this.organizationId,
    required this.isOwner,
  });

  final String organizationId;
  final bool isOwner;

  String _formatExpiry(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    try {
      final expires = DateTime.parse(isoDate);
      final diff = expires.difference(DateTime.now());
      if (diff.inDays >= 1) {
        return 'Expires in ${diff.inDays} ${diff.inDays == 1 ? "day" : "days"}';
      } else if (diff.inHours >= 1) {
        return 'Expires in ${diff.inHours} ${diff.inHours == 1 ? "hour" : "hours"}';
      } else if (diff.inMinutes >= 1) {
        return 'Expires in ${diff.inMinutes} ${diff.inMinutes == 1 ? "minute" : "minutes"}';
      } else {
        return 'Expiring soon';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync =
        ref.watch(pendingInvitationsProvider(organizationId));
    final compact = MediaQuery.sizeOf(context).width < 500;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderLight),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pending Invitations',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryNavy),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh Invitations',
                  onPressed: () => ref
                      .invalidate(pendingInvitationsProvider(organizationId)),
                ),
              ],
            ),
            const Divider(height: 20),
            invitationsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Could not load pending invitations.',
                      style: TextStyle(color: AppTheme.error),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => ref.invalidate(
                          pendingInvitationsProvider(organizationId)),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
              data: (invitations) {
                if (invitations.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No pending invitations found for this organization.',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
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
                    final expiresAtIso = item['expiresAt'] as String?;
                    final expiryText = _formatExpiry(expiresAtIso);

                    final isAdminRole = role.toLowerCase() == 'admin';
                    final canRevoke = isOwner || !isAdminRole;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: const Icon(Icons.mark_email_unread_outlined,
                          color: AppTheme.primaryBlue, size: 22),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.secondaryNavy),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: role.toLowerCase() == 'admin'
                                  ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: role.toLowerCase() == 'admin'
                                      ? AppTheme.primaryBlue
                                      : AppTheme.secondaryNavy),
                            ),
                          ),
                        ],
                      ),
                      subtitle: expiryText.isNotEmpty
                          ? Text(expiryText,
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondary))
                          : null,
                      trailing: canRevoke
                          ? OutlinedButton(
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(organizationRepositoryProvider)
                                      .revokeInvitation(invitationId);
                                  ref.invalidate(pendingInvitationsProvider(
                                      organizationId));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Invitation revoked successfully.'),
                                          backgroundColor: AppTheme.success),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Failed to revoke invitation: ${e.toString().replaceAll("Exception: ", "")}'),
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
                              message:
                                  'Only Owner can revoke Admin-level invitations',
                              child: Icon(Icons.lock_outline,
                                  size: 18, color: AppTheme.textSecondary),
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
