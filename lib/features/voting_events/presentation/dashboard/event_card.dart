import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/voting_event.dart';
import '../providers/event_lifecycle_provider.dart';

class EventCard extends ConsumerWidget {
  final VotingEvent event;

  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = DateFormat('MMM d, yyyy - h:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusBadge(event.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getTypeLabel(event.votingType),
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.secondaryNavy),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text('${format.format(event.startAt)} to', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 24),
                Text(format.format(event.endAt), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
            const Divider(height: 32),
            _buildActionButtons(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(VotingEventStatus status) {
    Color color;
    String label;

    switch (status) {
      case VotingEventStatus.draft:
        color = Colors.grey;
        label = 'DRAFT';
        break;
      case VotingEventStatus.scheduled:
        color = Colors.blue;
        label = 'SCHEDULED';
        break;
      case VotingEventStatus.active:
        color = AppTheme.success;
        label = 'ACTIVE';
        break;
      case VotingEventStatus.closed:
        color = AppTheme.error;
        label = 'CLOSED';
        break;
      case VotingEventStatus.cancelled:
        color = AppTheme.error;
        label = 'CANCELLED';
        break;
      case VotingEventStatus.archived:
        color = Colors.brown;
        label = 'ARCHIVED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  String _getTypeLabel(VotingType type) {
    switch (type) {
      case VotingType.candidateElection: return 'Candidate Election';
      case VotingType.singleChoicePoll: return 'Single-Choice Poll';
      case VotingType.yesNoPoll: return 'Yes/No Poll';
    }
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    switch (event.status) {
      case VotingEventStatus.draft:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => _confirmDelete(context, ref),
              icon: const Icon(Icons.delete, color: AppTheme.error, size: 18),
              label: const Text('Delete', style: TextStyle(color: AppTheme.error)),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () => context.go('/admin/events/${event.id}/choices'),
              child: const Text('Manage Choices'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => context.go('/admin/events/${event.id}/edit'),
              child: const Text('Edit Config'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => context.go('/admin/events/${event.id}/review'),
              child: const Text('Publish'),
            ),
          ],
        );
      case VotingEventStatus.scheduled:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => _confirmCancel(context, ref),
              icon: const Icon(Icons.cancel, color: AppTheme.error, size: 18),
              label: const Text('Cancel Event', style: TextStyle(color: AppTheme.error)),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Details view coming in Milestone 6.')));
              },
              child: const Text('View Details'),
            ),
          ],
        );
      case VotingEventStatus.active:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => _confirmClose(context, ref),
              icon: const Icon(Icons.stop_circle, color: AppTheme.error, size: 18),
              label: const Text('Close Early', style: TextStyle(color: AppTheme.error)),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monitor Turnout coming in Milestone 6.')));
              },
              child: const Text('Monitor Turnout'),
            ),
          ],
        );
      case VotingEventStatus.closed:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('View Results coming in Milestone 6.')));
              },
              child: const Text('View Results'),
            ),
          ],
        );
      case VotingEventStatus.cancelled:
      case VotingEventStatus.archived:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Details view coming in Milestone 6.')));
              },
              child: const Text('View Details'),
            ),
          ],
        );
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Draft Event?'),
        content: Text('Are you sure you want to permanently delete "${event.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      )
    );
    if (confirm == true) {
      ref.read(eventLifecycleProvider.notifier).deleteEvent(event.id);
    }
  }

  void _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Scheduled Event?'),
        content: Text('Are you sure you want to cancel "${event.title}"? It will not become active.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Scheduled')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Event', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      )
    );
    if (confirm == true) {
      ref.read(eventLifecycleProvider.notifier).cancelEvent(event.id);
    }
  }

  void _confirmClose(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Event Early?'),
        content: Text('Are you sure you want to close "${event.title}"? No further votes will be accepted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close Early', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      )
    );
    if (confirm == true) {
      ref.read(eventLifecycleProvider.notifier).closeEventEarly(event.id);
    }
  }
}
