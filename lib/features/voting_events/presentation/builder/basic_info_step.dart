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

  @override
  void initState() {
    super.initState();
    final draft = ref.read(draftEventProvider(widget.orgId));
    _titleCtrl = TextEditingController(text: draft.title);
    _descCtrl = TextEditingController(text: draft.description);
    _type = draft.votingType;
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(child: Text('V1 Defaults: Privacy is locked to ANONYMOUS. Voters may select exactly 1 choice.', style: TextStyle(fontSize: 12))),
              ],
            ),
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
