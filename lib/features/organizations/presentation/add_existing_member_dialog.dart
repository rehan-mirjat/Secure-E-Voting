import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/organization_repository.dart';

class AddExistingMemberDialog extends ConsumerStatefulWidget {
  const AddExistingMemberDialog({
    super.key,
    required this.organizationId,
  });

  final String organizationId;

  @override
  ConsumerState<AddExistingMemberDialog> createState() =>
      _AddExistingMemberDialogState();
}

class _AddExistingMemberDialogState
    extends ConsumerState<AddExistingMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref.read(organizationRepositoryProvider).addMember(
            organizationId: widget.organizationId,
            email: _emailController.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: const Text('Add an existing member'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add a verified SecureVote account directly to this organization.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Member email address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty ||
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(email)) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add_alt_1_rounded),
          label: Text(_isSubmitting ? 'Adding…' : 'Add member'),
        ),
      ],
    );
  }
}
