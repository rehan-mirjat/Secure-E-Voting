import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/organization_repository.dart';
import 'providers/organization_providers.dart';

class InvitationInboxScreen extends ConsumerStatefulWidget {
  const InvitationInboxScreen({super.key});

  @override
  ConsumerState<InvitationInboxScreen> createState() =>
      _InvitationInboxScreenState();
}

class _InvitationInboxScreenState extends ConsumerState<InvitationInboxScreen> {
  String? _respondingTo;

  Future<void> _respond(
    BuildContext context,
    Map<String, dynamic> invitation,
    bool accept,
  ) async {
    final invitationId = invitation['invitationId'] as String? ?? '';
    if (invitationId.isEmpty || _respondingTo != null) return;
    setState(() => _respondingTo = invitationId);

    if (!accept) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Decline this invitation?'),
          content: Text(
            'You will not join ${invitation['organizationName'] ?? 'this organization'}. The administrator can invite you again later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep invitation'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Decline'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        if (mounted) setState(() => _respondingTo = null);
        return;
      }
    }

    try {
      final result = await ref
          .read(organizationRepositoryProvider)
          .respondToInvitation(invitationId: invitationId, accept: accept);
      if (accept) {
        ref.invalidate(userMembershipsProvider);
        ref.invalidate(userOrganizationsProvider);
        ref.invalidate(activeOrganizationContextProvider);
        await ref
            .read(activeOrgIdProvider.notifier)
            .selectOrganization(result.organizationId);
      }
      ref.invalidate(memberInvitationsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept
              ? 'You joined ${result.organizationName}.'
              : 'Invitation declined.'),
          backgroundColor: accept ? AppTheme.success : null,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _respondingTo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final invitations = ref.watch(memberInvitationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Refresh invitations',
            onPressed: () => ref.invalidate(memberInvitationsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: invitations.when(
        loading: () => const LoadingView(message: 'Checking your invitations…'),
        error: (error, _) => ErrorView(
          title: 'Could not load notifications',
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(memberInvitationsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_rounded,
                        size: 56, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('You’re all caught up',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text(
                      'Organization invitations will appear here. You can accept or decline each one.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final invitation = items[index];
              final organizationName =
                  invitation['organizationName'] as String? ?? 'Organization';
              final roleValue = invitation['role'] as String? ?? 'member';
              final role = roleValue.isEmpty
                  ? 'Member'
                  : '${roleValue[0].toUpperCase()}${roleValue.substring(1)}';
              final isWorking = _respondingTo == invitation['invitationId'];
              final expiresAt = DateTime.tryParse(
                invitation['expiresAt'] as String? ?? '',
              );

              return Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.business_outlined,
                                color: AppTheme.primaryBlue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You’re invited to join',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  organizationName,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Role: $role',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (expiresAt != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Expires ${MaterialLocalizations.of(context).formatMediumDate(expiresAt.toLocal())}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _respondingTo == null
                                ? () => _respond(context, invitation, false)
                                : null,
                            icon: isWorking
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.close_rounded),
                            label: const Text('Decline'),
                          ),
                          FilledButton.icon(
                            onPressed: _respondingTo == null
                                ? () => _respond(context, invitation, true)
                                : null,
                            icon: isWorking
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_rounded),
                            label: const Text('Accept'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
