import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../voting_events/data/candidate_repository.dart';
import '../../voting_events/data/poll_option_repository.dart';
import '../../voting_events/data/voting_event_repository.dart';
import '../../voting_events/domain/candidate.dart';
import '../../voting_events/domain/poll_option.dart';
import '../../voting_events/domain/voting_event.dart';
import '../data/voting_repository.dart';
import 'vote_receipt_screen.dart';

final eventCandidatesProvider = StreamProvider.family<List<Candidate>, String>((ref, eventId) {
  return ref.watch(candidateRepositoryProvider).watchEventCandidates(eventId);
});

final eventPollOptionsProvider = StreamProvider.family<List<PollOption>, String>((ref, eventId) {
  return ref.watch(pollOptionRepositoryProvider).watchEventPollOptions(eventId);
});

final singleVotingEventProvider = StreamProvider.family<VotingEvent?, String>((ref, eventId) {
  return ref.watch(votingEventRepositoryProvider).watchVotingEvent(eventId);
});

class CastVoteScreen extends ConsumerStatefulWidget {
  const CastVoteScreen({
    super.key,
    required this.eventId,
  });

  final String eventId;

  @override
  ConsumerState<CastVoteScreen> createState() => _CastVoteScreenState();
}

class _CastVoteScreenState extends ConsumerState<CastVoteScreen> {
  String? _selectedCandidateId;
  String? _selectedPollOptionId;
  String? _selectedChoiceName;

  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submitBallot(VotingEvent event) async {
    if (_selectedCandidateId == null && _selectedPollOptionId == null) {
      setState(() => _errorMessage = 'Please select an option before casting your ballot.');
      return;
    }

    // Show Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.how_to_vote, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text('Confirm Ballot Submission'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to submit your ballot? This action cannot be undone and your vote is permanent.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Text('Selection: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Expanded(
                    child: Text(
                      _selectedChoiceName ?? 'Selected Choice',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            child: const Text('Confirm & Cast Ballot'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final receipt = await ref.read(votingRepositoryProvider).castVote(
            organizationId: event.organizationId,
            eventId: event.id,
            candidateId: _selectedCandidateId,
            pollOptionId: _selectedPollOptionId,
          );

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (ctx) => VoteReceiptScreen(
              receipt: receipt,
              eventTitle: event.title,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(singleVotingEventProvider(widget.eventId));
    final user = ref.watch(authServiceProvider).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cast Your Ballot'),
      ),
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error loading voting event: $err', style: const TextStyle(color: AppTheme.error)),
          ),
        ),
        data: (event) {
          if (event == null) {
            return const Center(child: Text('Voting event not found.'));
          }

          if (user == null) {
            return const Center(child: Text('You must be signed in to vote.'));
          }

          // Check if user has already voted
          final participationAsync = ref.watch(userParticipationProvider(
            UserParticipationParams(
              organizationId: event.organizationId,
              eventId: event.id,
              userId: user.uid,
            ),
          ));

          return participationAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => _buildBallotView(context, event),
            data: (hasVoted) {
              if (hasVoted) {
                return _buildAlreadyVotedView(context, event, user.uid);
              }
              return _buildBallotView(context, event);
            },
          );
        },
      ),
    );
  }

  Widget _buildAlreadyVotedView(BuildContext context, VotingEvent event, String userId) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 72, color: AppTheme.success),
              const SizedBox(height: 20),
              Text(
                'You Have Already Voted',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryNavy,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your ballot for "${event.title}" has already been cast and accepted into the anonymous tally.',
                style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  final receipt = await ref.read(votingRepositoryProvider).getUserReceipt(
                        organizationId: event.organizationId,
                        eventId: event.id,
                        userId: userId,
                      );
                  if (context.mounted && receipt != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => VoteReceiptScreen(
                          receipt: receipt,
                          eventTitle: event.title,
                        ),
                      ),
                    );
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Receipt not found.')),
                    );
                  }
                },
                icon: const Icon(Icons.receipt_long),
                label: const Text('View Your Confirmation Receipt'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Return to Home Feed'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBallotView(BuildContext context, VotingEvent event) {
    final now = DateTime.now();
    final isWindowOpen = event.status == VotingEventStatus.active &&
        now.isAfter(event.startAt) &&
        now.isBefore(event.endAt);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Event Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'OFFICIAL BALLOT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.success,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.timer_outlined, size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            _getTimeRemaining(event.endAt),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        event.title,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
                      ),
                      if (event.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          event.description,
                          style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.error)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const Text(
                'MAKE YOUR SELECTION',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1.1),
              ),
              const SizedBox(height: 12),

              // Dynamic Options rendering based on event type
              if (event.votingType == VotingType.candidateElection)
                _buildCandidateOptions(event)
              else if (event.votingType == VotingType.yesNoPoll)
                _buildYesNoOptions(event)
              else
                _buildPollOptions(event),

              const SizedBox(height: 32),

              // Submit Button
              ElevatedButton.icon(
                onPressed: (!isWindowOpen || _isSubmitting)
                    ? null
                    : () => _submitBallot(event),
                icon: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_isSubmitting ? 'Submitting Ballot...' : 'Submit Official Ballot'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCandidateOptions(VotingEvent event) {
    final candidatesAsync = ref.watch(eventCandidatesProvider(event.id));

    return candidatesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error loading candidates: $err', style: const TextStyle(color: AppTheme.error)),
      data: (candidates) {
        if (candidates.isEmpty) {
          return const Center(child: Text('No candidates available.'));
        }

        return Column(
          children: candidates.map((cand) {
            final isSelected = _selectedCandidateId == cand.id;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.borderLight,
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCandidateId = cand.id;
                    _selectedPollOptionId = null;
                    _selectedChoiceName = cand.name;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        backgroundImage: cand.photoUrl != null && cand.photoUrl!.isNotEmpty
                            ? NetworkImage(cand.photoUrl!)
                            : null,
                        child: cand.photoUrl == null || cand.photoUrl!.isEmpty
                            ? Text(cand.name.isNotEmpty ? cand.name[0].toUpperCase() : 'C',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue))
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cand.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy)),
                            if (cand.party.isNotEmpty)
                              Text(cand.party, style: const TextStyle(fontSize: 13, color: AppTheme.primaryBlue, fontWeight: FontWeight.w500)),
                            if (cand.bio.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(cand.bio, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPollOptions(VotingEvent event) {
    final optionsAsync = ref.watch(eventPollOptionsProvider(event.id));

    return optionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error loading options: $err', style: const TextStyle(color: AppTheme.error)),
      data: (options) {
        if (options.isEmpty) {
          return const Center(child: Text('No poll options available.'));
        }

        return Column(
          children: options.map((opt) {
            final isSelected = _selectedPollOptionId == opt.id;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.borderLight,
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedPollOptionId = opt.id;
                    _selectedCandidateId = null;
                    _selectedChoiceName = opt.label;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(opt.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy)),
                            if (opt.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(opt.description, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildYesNoOptions(VotingEvent event) {
    final yesOptionId = '${event.id}_YES';
    final noOptionId = '${event.id}_NO';

    return Column(
      children: [
        _buildChoiceCard(
          id: yesOptionId,
          title: 'YES',
          subtitle: 'In favor of this proposal',
          icon: Icons.check_circle_outline,
          color: AppTheme.success,
        ),
        const SizedBox(height: 12),
        _buildChoiceCard(
          id: noOptionId,
          title: 'NO',
          subtitle: 'Opposed to this proposal',
          icon: Icons.cancel_outlined,
          color: AppTheme.error,
        ),
      ],
    );
  }

  Widget _buildChoiceCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedPollOptionId == id;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? color : AppTheme.borderLight,
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPollOptionId = id;
            _selectedCandidateId = null;
            _selectedChoiceName = title;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeRemaining(DateTime endAt) {
    final diff = endAt.difference(DateTime.now());
    if (diff.isNegative) return 'Voting closed';
    if (diff.inDays > 0) return '${diff.inDays}d left';
    if (diff.inHours > 0) return '${diff.inHours}h left';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m left';
    return 'Closing soon';
  }
}
