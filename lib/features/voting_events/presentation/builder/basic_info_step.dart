import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/voting_event.dart';
import '../providers/draft_event_provider.dart';

class BasicInfoStep extends ConsumerStatefulWidget {
  final String orgId;
  final VoidCallback onNext;

  const BasicInfoStep({super.key, required this.orgId, required this.onNext});

  @override
  ConsumerState<BasicInfoStep> createState() => _BasicInfoStepState();
}

class _BasicInfoStepState extends ConsumerState<BasicInfoStep> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  VotingType _type = VotingType.candidateElection;
  PrivacyMode _privacyMode = PrivacyMode.anonymous;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(draftEventProvider(widget.orgId));
    _titleCtrl = TextEditingController(text: draft.title);
    _descCtrl = TextEditingController(text: draft.description);
    _type = draft.votingType;
    _privacyMode = draft.privacyMode;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDraft = ref.watch(draftEventProvider(widget.orgId)).status == VotingEventStatus.draft;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isDraft)
             Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
               child: const Text('Event is no longer a DRAFT. Basic info is strictly immutable.', style: TextStyle(color: Colors.grey)),
             ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleCtrl,
            enabled: isDraft,
            decoration: const InputDecoration(labelText: 'Event Title', hintText: 'e.g. Faculty Senate Election 2026'),
            validator: (v) {
              if (v == null || v.trim().length < 3 || v.trim().length > 100) {
                return 'Title must be 3-100 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descCtrl,
            enabled: isDraft,
            decoration: const InputDecoration(labelText: 'Description', hintText: 'Explain the purpose of this event...'),
            maxLines: 4,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Description is required.';
              }
              if (v.trim().length > 1000) {
                return 'Description cannot exceed 1000 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          const Text('Voting Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _buildRadio(VotingType.candidateElection, 'Candidate Election', 'Voters select one candidate from a roster.', isDraft),
          _buildRadio(VotingType.singleChoicePoll, 'Single-Choice Poll', 'Voters select one option from a list.', isDraft),
          _buildRadio(VotingType.yesNoPoll, 'Yes/No Poll', 'Voters approve or reject a proposal.', isDraft),
          
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          DropdownButtonFormField<PrivacyMode>(
            initialValue: _privacyMode,
            decoration: const InputDecoration(labelText: 'Ballot privacy'),
            items: const [
              DropdownMenuItem(value: PrivacyMode.anonymous, child: Text('Anonymous')),
              DropdownMenuItem(value: PrivacyMode.identifiable, child: Text('Identifiable')),
            ],
            onChanged: isDraft ? (value) {
              if (value != null) setState(() => _privacyMode = value);
            } : null,
          ),
          const SizedBox(height: 8),
          Text(
            _privacyMode == PrivacyMode.anonymous
                ? 'Voter identity is stored separately from the ballot.'
                : 'Each ballot is associated with the voter’s account. Voters will see this notice before confirming.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    ref.read(draftEventProvider(widget.orgId).notifier).updateBasicInfo(
                      _titleCtrl.text.trim(),
                      _descCtrl.text.trim(),
                      _type,
                      _privacyMode,
                    );
                    widget.onNext();
                  }
                },
                child: const Text('Next: Schedule'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadio(VotingType val, String title, String subtitle, bool isDraft) {
    // ignore: deprecated_member_use
    return RadioListTile<VotingType>(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: val,
      // ignore: deprecated_member_use
      groupValue: _type,
      // ignore: deprecated_member_use
      onChanged: isDraft ? (v) {
        if (v != null) setState(() => _type = v);
      } : null,
    );
  }
}
