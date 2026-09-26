import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../data/organization_repository.dart';
import 'providers/organization_providers.dart';

class AcceptInvitationScreen extends ConsumerStatefulWidget {
  const AcceptInvitationScreen({super.key});

  @override
  ConsumerState<AcceptInvitationScreen> createState() =>
      _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState
    extends ConsumerState<AcceptInvitationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(organizationRepositoryProvider)
          .acceptInvitation(_tokenController.text.trim());
      ref.invalidate(userMembershipsProvider);
      ref.invalidate(userOrganizationsProvider);
      ref.invalidate(activeOrganizationContextProvider);
      await ref
          .read(activeOrgIdProvider.notifier)
          .selectOrganization(result.organizationId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You joined ${result.organizationName}.'),
          backgroundColor: AppTheme.success,
        ),
      );
      context.go('/orgs');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accept Invitation')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 56,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'You’re invited',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in with the email address the invitation was sent to, then enter the token from your organization administrator.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _tokenController,
                      keyboardType: TextInputType.visiblePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-fA-F0-9]'),
                        ),
                        LengthLimitingTextInputFormatter(32),
                      ],
                      decoration: const InputDecoration(
                        labelText: '32-character invitation token',
                        hintText: 'Paste your invitation token',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                      validator: (value) => RegExp(r'^[a-fA-F0-9]{32}$')
                              .hasMatch(value?.trim() ?? '')
                          ? null
                          : 'Enter the complete 32-character token.',
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.08),
                          border: Border.all(
                            color: AppTheme.error.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppTheme.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _accept,
                      icon: _submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.how_to_reg_outlined),
                      label: Text(
                          _submitting ? 'Accepting…' : 'Accept invitation'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Invitation tokens can be used once and expire. Keep yours private.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
