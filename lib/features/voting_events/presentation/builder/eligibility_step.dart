import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../departments/presentation/providers/department_providers.dart';
import '../../../organizations/presentation/membership_directory_screen.dart';
import '../../domain/voting_event.dart';
import '../providers/draft_event_provider.dart';

class EligibilityStep extends ConsumerStatefulWidget {
  final String orgId;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const EligibilityStep(
      {super.key,
      required this.orgId,
      required this.onNext,
      required this.onBack});

  @override
  ConsumerState<EligibilityStep> createState() => _EligibilityStepState();
}

class _EligibilityStepState extends ConsumerState<EligibilityStep> {
  late EligibilityType _type;
  List<String> _selectedDepts = [];
  List<String> _selectedUsers = [];

  @override
  void initState() {
    super.initState();
    final draft = ref.read(draftEventProvider(widget.orgId));
    _type = draft.eligibilityType;
    _selectedDepts = List.from(draft.selectedDepartmentIds);
    _selectedUsers = List.from(draft.selectedUserIds);
  }

  void _submit() async {
    _saveSelection();

    // Now, create the DRAFT on the server!
    final success = await ref
        .read(draftEventProvider(widget.orgId).notifier)
        .createServerDraft();
    if (success) {
      widget.onNext();
    }
  }

  void _saveSelection() {
    ref
        .read(draftEventProvider(widget.orgId).notifier)
        .updateEligibility(_type, _selectedDepts, _selectedUsers);
  }

  @override
  Widget build(BuildContext context) {
    final draftState = ref.watch(draftEventProvider(widget.orgId));
    final isDraft = draftState.status == VotingEventStatus.draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isDraft)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8)),
            child: const Text(
                'Event is no longer a DRAFT. Eligibility configuration is strictly immutable.',
                style: TextStyle(color: Colors.grey)),
          ),
        const SizedBox(height: 16),
        const Text('Voter Eligibility',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        DropdownButtonFormField<EligibilityType>(
          // ignore: deprecated_member_use
          value: _type,
          decoration: const InputDecoration(labelText: 'Who can vote?'),
          items: const [
            DropdownMenuItem(
                value: EligibilityType.allMembers,
                child: Text('All Active Members')),
            DropdownMenuItem(
                value: EligibilityType.selectedDepartments,
                child: Text('Selected Departments')),
            DropdownMenuItem(
                value: EligibilityType.selectedMembers,
                child: Text('Selected Members')),
          ],
          onChanged: isDraft
              ? (v) {
                  if (v != null) {
                    setState(() => _type = v);
                    _saveSelection();
                  }
                }
              : null,
        ),
        const SizedBox(height: 24),
        if (_type == EligibilityType.selectedDepartments)
          _buildDepartmentSelector(isDraft),
        if (_type == EligibilityType.selectedMembers)
          _buildMemberSelector(isDraft),
        if (draftState.isLoading)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator())),
        if (draftState.error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .error
                      .withValues(alpha: 0.35)),
            ),
            child: Text(
              draftState.error!,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer),
            ),
          ),
        ],
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
                onPressed: draftState.isLoading ? null : widget.onBack,
                child: const Text('Back')),
            ElevatedButton(
              onPressed: draftState.isLoading
                  ? null
                  : (isDraft ? _submit : widget.onNext),
              child: Text(draftState.serverEventId == null
                  ? 'Create Draft & Continue'
                  : 'Next: Choices'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDepartmentSelector(bool isDraft) {
    final deptsAsync = ref.watch(activeOrganizationDepartmentsProvider);
    return deptsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (depts) {
        if (depts.isEmpty) {
          return const Text('No departments found in this organization.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: depts.map((d) {
            return CheckboxListTile(
              title: Text(d.name),
              value: _selectedDepts.contains(d.id),
              onChanged: isDraft
                  ? (val) {
                      setState(() {
                        if (val == true) {
                          _selectedDepts.add(d.id);
                        } else {
                          _selectedDepts.remove(d.id);
                        }
                      });
                      _saveSelection();
                    }
                  : null,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildMemberSelector(bool isDraft) {
    // For V1 UI, using a simple multi-select from directory provider
    final membersAsync =
        ref.watch(organizationMembersDirectoryProvider(widget.orgId));
    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (members) {
        final activeMembers =
            members.where((m) => m['status'] == 'active').toList();
        if (activeMembers.isEmpty) {
          return const Text('No active members found.');
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: activeMembers.length,
            itemBuilder: (ctx, i) {
              final m = activeMembers[i];
              final uid = m['userId'] as String;
              final name = m['displayName'] as String;
              return CheckboxListTile(
                title: Text(name),
                subtitle: Text(m['email'] as String),
                value: _selectedUsers.contains(uid),
                onChanged: isDraft
                    ? (val) {
                        setState(() {
                          if (val == true) {
                            _selectedUsers.add(uid);
                          } else {
                            _selectedUsers.remove(uid);
                          }
                        });
                        _saveSelection();
                      }
                    : null,
              );
            },
          ),
        );
      },
    );
  }
}
