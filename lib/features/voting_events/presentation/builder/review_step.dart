import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/layout/responsive.dart';
import '../../data/voting_event_repository.dart';
import '../providers/draft_event_provider.dart';
import '../../data/candidate_repository.dart';
import '../../data/poll_option_repository.dart';
import '../../domain/voting_event.dart';

class ReviewStep extends ConsumerStatefulWidget {
  final String orgId;
  final VoidCallback onBack;

  const ReviewStep({super.key, required this.orgId, required this.onBack});

  @override
  ConsumerState<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends ConsumerState<ReviewStep> {
  bool _isPublishing = false;
  String? _error;

  Future<void> _publish() async {
    final draft = ref.read(draftEventProvider(widget.orgId));
    final eventId = draft.serverEventId;
    if (eventId == null) return;

    setState(() {
      _isPublishing = true;
      _error = null;
    });

    try {
      await ref.read(votingEventRepositoryProvider).publishVotingEvent(eventId);
      if (mounted) {
        ref.read(draftEventProvider(widget.orgId).notifier).reset();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Voting Event Published Successfully!',
                style: TextStyle(color: AppTheme.success))));
        // Navigate back to management dashboard (route to be defined)
        context.go('/org/${widget.orgId}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPublishing = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(draftEventProvider(widget.orgId));
    final eventId = draft.serverEventId;
    if (eventId == null) return const SizedBox.shrink();

    // Check completeness locally for UX warning
    final bool isCand = draft.votingType == VotingType.candidateElection;
    final bool isPoll = draft.votingType == VotingType.singleChoicePoll;

    Stream<int> countStream;
    if (isCand) {
      countStream = ref
          .watch(candidateRepositoryProvider)
          .watchEventCandidates(eventId)
          .map((v) => v.length);
    } else if (isPoll) {
      countStream = ref
          .watch(pollOptionRepositoryProvider)
          .watchEventPollOptions(eventId)
          .map((v) => v.length);
    } else {
      countStream = Stream.value(2); // Safe for YesNo
    }

    return StreamBuilder<int>(
        stream: countStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Text('Error loading choices: ${snapshot.error}');
          }

          final count = snapshot.data ?? 0;
          final isReady =
              count >= 2 || draft.votingType == VotingType.yesNoPoll;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Review & Publish',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _summaryRow('Title', draft.title),
              _summaryRow(
                  'Start At',
                  draft.startAt != null
                      ? DateFormat('MMM d, yyyy h:mm a').format(draft.startAt!)
                      : ''),
              _summaryRow(
                  'End At',
                  draft.endAt != null
                      ? DateFormat('MMM d, yyyy h:mm a').format(draft.endAt!)
                      : ''),
              _summaryRow('Choices', '$count items configured'),
              if (!isReady) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                      'Warning: A minimum of 2 choices must be configured before publishing.',
                      style: TextStyle(color: Colors.orange)),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('Publish Error: $_error',
                      style: const TextStyle(color: AppTheme.error)),
                ),
              ],
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                      onPressed: _isPublishing ? null : widget.onBack,
                      child: const Text('Back')),
                  ElevatedButton(
                    onPressed: _isPublishing || !isReady ? null : _publish,
                    child: _isPublishing
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Publish Event'),
                  ),
                ],
              ),
            ],
          );
        });
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ResponsiveLayout.isCompact(context) ? 76 : 100,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryNavy)),
          ),
          Expanded(child: Text(value, softWrap: true)),
        ],
      ),
    );
  }
}
