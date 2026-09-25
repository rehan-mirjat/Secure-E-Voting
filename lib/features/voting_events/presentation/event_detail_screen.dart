import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../services/auth_service.dart';
import '../../voting/data/participation_repository.dart';
import '../../voting/data/receipt_repository.dart';
import '../../voting/presentation/cast_vote_screen.dart';
import '../domain/voting_event.dart';

class EventDetailScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(singleVotingEventProvider(eventId));
    final currentUser = ref.watch(authServiceProvider).currentUser;
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
      ),
      body: eventAsync.when(
        loading: () => const LoadingView(message: 'Loading event details...'),
        error: (err, _) => ErrorView(
          message: 'Error loading voting event: $err',
          onRetry: () => ref.invalidate(singleVotingEventProvider(eventId)),
        ),
        data: (event) {
          if (event == null) {
            return const ErrorView(
              title: 'Event Not Found',
              message: 'The requested voting event does not exist or has been removed.',
            );
          }

          if (currentUser == null) {
            return const ErrorView(
              title: 'Authentication Required',
              message: 'Please sign in to view voting event details.',
            );
          }

          final participationAsync = ref.watch(
            participationStatusProvider((
              organizationId: event.organizationId,
              eventId: event.id,
              userId: currentUser.uid,
            )),
          );

          return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 24, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Status Badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusBadge.eventStatus(event.status.name),
                        StatusBadge.privacyMode(event.privacyMode.name),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryNavy,
                          ),
                    ),
                    if (event.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        event.description,
                        style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.5),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Metadata Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'EVENT SPECIFICATIONS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const Divider(height: 24),
                            _buildInfoRow('Voting Type', event.votingType.name.toUpperCase()),
                            const SizedBox(height: 12),
                            _buildInfoRow('Eligibility Scope', event.eligibilityType.name.toUpperCase()),
                            const SizedBox(height: 12),
                            _buildInfoRow('Voting Opens', dateFormat.format(event.startAt)),
                            const SizedBox(height: 12),
                            _buildInfoRow('Voting Closes', dateFormat.format(event.endAt)),
                          ],
                        ),
                      ),
                    ),
                    if (event.status == VotingEventStatus.closed || event.status == VotingEventStatus.archived) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/elections/${event.id}/results'),
                        icon: const Icon(Icons.query_stats_rounded),
                        label: const Text('View election results'),
                      ),
                    ],
                    const SizedBox(height: 28),

                    // Participation State
                    participationAsync.when(
                      loading: () => const LoadingView(message: 'Checking participation status...'),
                      error: (err, _) => ErrorView(message: 'Failed to verify participation status: $err'),
                      data: (hasVoted) {
                        if (hasVoted) {
                          return Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 28),
                                    SizedBox(width: 10),
                                    Text(
                                      'Already Voted',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.success,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Your participation has been securely recorded. Duplicate voting is prohibited.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final receipt = await ref.read(receiptRepositoryProvider).getReceiptForEvent(event.id, currentUser.uid);
                                    if (receipt != null && context.mounted) {
                                      context.push('/receipt', extra: {
                                        'receipt': receipt,
                                        'eventTitle': event.title,
                                      });
                                    } else if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Receipt not found.')),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.receipt_rounded, size: 18),
                                  label: const Text('View Your Confirmation Receipt'),
                                ),
                              ],
                            ),
                          );
                        } else {
                          final isActive = event.status == VotingEventStatus.active;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton.icon(
                                onPressed: isActive ? () => context.push('/elections/${event.id}/vote') : null,
                                icon: const Icon(Icons.how_to_vote_rounded, size: 18),
                                label: const Text('Proceed to Ballot'),
                              ),
                              if (!isActive)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    'This event is currently ${event.status.name.toUpperCase()} and not accepting votes.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: AppTheme.error, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            softWrap: true,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.secondaryNavy),
          ),
        ),
      ],
    );
  }
}
