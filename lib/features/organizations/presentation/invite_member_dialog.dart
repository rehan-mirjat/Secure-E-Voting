import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../data/organization_repository.dart';

class InviteMemberDialog extends ConsumerStatefulWidget {
  const InviteMemberDialog({
    super.key,
    required this.organizationId,
    required this.organizationName,
    required this.isOwner,
  });

  final String organizationId;
  final String organizationName;
  final bool isOwner;

  @override
  ConsumerState<InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends ConsumerState<InviteMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  late String _selectedRole;
  bool _isLoading = false;
  String? _error;
  String? _generatedRawToken;

  @override
  void initState() {
    super.initState();
    _selectedRole = 'member';
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(organizationRepositoryProvider);
      final result = await repo.inviteMember(
        organizationId: widget.organizationId,
        email: _emailController.text,
        role: widget.isOwner ? _selectedRole : 'member',
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _generatedRawToken = result.rawToken;
        });
      }
    } catch (e) {
      if (mounted) {
        var errorMsg = e.toString().replaceAll('Exception: ', '');
        if (errorMsg.contains('already an active member') || errorMsg.contains('already a member')) {
          errorMsg = 'This user is already a member of this organization.';
        } else if (errorMsg.contains('active invitation') || errorMsg.contains('already exists')) {
          errorMsg = 'An invitation has already been sent to this email address.';
        }

        setState(() {
          _error = errorMsg;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_generatedRawToken != null) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppTheme.success, size: 24),
            SizedBox(width: 10),
            Text('Invitation Issued', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'An invitation token was generated for ${_emailController.text.trim()}:',
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlue,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: SelectableText(
                _generatedRawToken!,
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Share this token with the recipient so they can accept it under "Accept Invitation".',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy Token'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _generatedRawToken!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invitation token copied to clipboard!'), backgroundColor: AppTheme.success),
              );
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Done'),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Invite a new member',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Issue an invitation token to join this organization.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Text('EMAIL ADDRESS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.secondaryNavy, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Recipient Email Address *',
                    hintText: 'voter@organization.com',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                const SizedBox(height: 20),

                const Text('ORGANIZATION', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.secondaryNavy, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: widget.organizationName,
                  readOnly: true,
                  enabled: false,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.business_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 20),

                const Text('ROLE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.secondaryNavy, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                if (widget.isOwner)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRole,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.admin_panel_settings_outlined, size: 20),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'member', child: Text('Member')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRole = val);
                    },
                  )
                else
                  TextFormField(
                    initialValue: 'Member',
                    readOnly: true,
                    enabled: false,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                      suffixIcon: Tooltip(
                        message: 'Admins can invite Member role only',
                        child: Icon(Icons.lock_outline, size: 18, color: AppTheme.textSecondary),
                      ),
                    ),
                  ),

                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _submit,
          icon: _isLoading
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.send_outlined, size: 18),
          label: Text(_isLoading ? 'Sending...' : 'Send Invitation'),
        ),
      ],
    );
  }
}
