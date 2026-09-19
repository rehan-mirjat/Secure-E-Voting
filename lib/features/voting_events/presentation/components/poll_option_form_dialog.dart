import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/poll_option_repository.dart';
import '../../domain/poll_option.dart';

class PollOptionFormDialog extends ConsumerStatefulWidget {
  final String orgId;
  final String eventId;
  final PollOption? existingOption;

  const PollOptionFormDialog({
    super.key,
    required this.orgId,
    required this.eventId,
    this.existingOption,
  });

  @override
  ConsumerState<PollOptionFormDialog> createState() => _PollOptionFormDialogState();
}

class _PollOptionFormDialogState extends ConsumerState<PollOptionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _labelCtrl;
  late TextEditingController _descCtrl;
  
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.existingOption?.label);
    _descCtrl = TextEditingController(text: widget.existingOption?.description);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(pollOptionRepositoryProvider);
      if (widget.existingOption == null) {
        // Find max sortOrder to append to the end.
        // For simplicity in this demo form, we'll pass 0 and let ReorderableListView sort it out,
        // or we could query the max sort order. We'll default to 0.
        await repo.createPollOption(
          organizationId: widget.orgId,
          votingEventId: widget.eventId,
          label: _labelCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          sortOrder: 0, 
        );
      } else {
        await repo.updatePollOption(
          optionId: widget.existingOption!.id,
          label: _labelCtrl.text.trim(),
          description: _descCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingOption == null ? 'Add Option' : 'Edit Option'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _labelCtrl,
                  decoration: const InputDecoration(labelText: 'Label *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Label is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Description (Optional)'),
                  maxLines: 3,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: AppTheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (!_isLoading)
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}
