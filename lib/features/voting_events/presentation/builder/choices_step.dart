import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/voting_event.dart';
import '../providers/draft_event_provider.dart';
import '../components/candidate_list.dart';
import '../components/poll_option_list.dart';

class ChoicesStep extends ConsumerWidget {
  final String orgId;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const ChoicesStep({super.key, required this.orgId, required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftState = ref.watch(draftEventProvider(orgId));
    final eventId = draftState.serverEventId;

    if (eventId == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          draftState.votingType == VotingType.candidateElection
              ? 'Candidate Roster'
              : draftState.votingType == VotingType.yesNoPoll
                  ? 'Yes/No Options'
                  : 'Poll Options',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        if (draftState.votingType == VotingType.candidateElection)
          CandidateList(orgId: orgId, eventId: eventId, isDraft: draftState.status == VotingEventStatus.draft)
        else if (draftState.votingType == VotingType.singleChoicePoll)
          PollOptionList(orgId: orgId, eventId: eventId, isDraft: draftState.status == VotingEventStatus.draft)
        else
          _buildYesNoList(),

        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(onPressed: onBack, child: const Text('Back')),
            ElevatedButton(onPressed: onNext, child: const Text('Next: Review')),
          ],
        ),
      ],
    );
  }

  Widget _buildYesNoList() {
    return const Column(
      children: [
        ListTile(
          leading: Icon(Icons.check_circle, color: Colors.green),
          title: Text('Yes'),
          subtitle: Text('System-generated option'),
        ),
        ListTile(
          leading: Icon(Icons.cancel, color: Colors.red),
          title: Text('No'),
          subtitle: Text('System-generated option'),
        ),
      ],
    );
  }
}
