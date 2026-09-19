import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/voting_event.dart';
import '../providers/draft_event_provider.dart';

class ScheduleStep extends ConsumerStatefulWidget {
  final String orgId;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const ScheduleStep({super.key, required this.orgId, required this.onNext, required this.onBack});

  @override
  ConsumerState<ScheduleStep> createState() => _ScheduleStepState();
}

class _ScheduleStepState extends ConsumerState<ScheduleStep> {
  DateTime? _startAt;
  DateTime? _endAt;
  String? _localError;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(draftEventProvider(widget.orgId));
    _startAt = draft.startAt;
    _endAt = draft.endAt;
  }

  Future<void> _pickDateTime(bool isStart) async {
    final initialDate = isStart ? (_startAt ?? DateTime.now()) : (_endAt ?? _startAt ?? DateTime.now().add(const Duration(minutes: 5)));
    
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    if (!mounted) return;
    
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return;

    final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (!mounted) return;

    setState(() {
      _localError = null;
      if (isStart) {
        _startAt = selected;
      } else {
        _endAt = selected;
      }
    });
  }

  void _validateAndProceed() {
    if (_startAt == null || _endAt == null) {
      setState(() => _localError = 'Start and End times are required.');
      return;
    }

    final now = DateTime.now();
    if (_startAt!.isBefore(now.subtract(const Duration(minutes: 1)))) {
      setState(() => _localError = 'Start time cannot be in the past.');
      return;
    }

    if (_endAt!.difference(_startAt!).inMinutes < 5) {
      setState(() => _localError = 'Voting window must be at least 5 minutes.');
      return;
    }

    ref.read(draftEventProvider(widget.orgId).notifier).updateSchedule(_startAt!, _endAt!);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('MMM d, yyyy - h:mm a');
    final isDraft = ref.watch(draftEventProvider(widget.orgId)).status == VotingEventStatus.draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isDraft)
           Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
             child: const Text('Event is no longer a DRAFT. Schedule is strictly immutable.', style: TextStyle(color: Colors.grey)),
           ),
        const SizedBox(height: 16),
        const Text('Voting Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('All times are evaluated securely against the server clock. Local selections are for convenience.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 24),
        
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
          title: const Text('Start Time'),
          subtitle: Text(_startAt != null ? format.format(_startAt!) : 'Not set', style: TextStyle(color: _startAt != null ? AppTheme.secondaryNavy : AppTheme.error)),
          trailing: const Icon(Icons.calendar_today),
          onTap: isDraft ? () => _pickDateTime(true) : null,
        ),
        const SizedBox(height: 16),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
          title: const Text('End Time'),
          subtitle: Text(_endAt != null ? format.format(_endAt!) : 'Not set', style: TextStyle(color: _endAt != null ? AppTheme.secondaryNavy : AppTheme.error)),
          trailing: const Icon(Icons.calendar_today),
          onTap: isDraft ? () => _pickDateTime(false) : null,
        ),
        
        if (_localError != null) ...[
          const SizedBox(height: 16),
          Text(_localError!, style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
        ],

        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(onPressed: widget.onBack, child: const Text('Back')),
            ElevatedButton(onPressed: isDraft ? _validateAndProceed : widget.onNext, child: const Text('Next: Eligibility')),
          ],
        ),
      ],
    );
  }
}
