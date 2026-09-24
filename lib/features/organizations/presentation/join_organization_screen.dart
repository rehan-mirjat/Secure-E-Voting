import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../data/organization_repository.dart';
import 'providers/organization_providers.dart';

class JoinOrganizationScreen extends ConsumerStatefulWidget {
  const JoinOrganizationScreen({
    super.key,
    this.onJoined,
    this.onCancelTap,
  });

  final Function(String organizationId, String organizationName)? onJoined;
  final VoidCallback? onCancelTap;

  @override
  ConsumerState<JoinOrganizationScreen> createState() => _JoinOrganizationScreenState();
}

class _JoinOrganizationScreenState extends ConsumerState<JoinOrganizationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
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
      final result = await repo.joinOrganizationWithCode(_codeController.text);

      // Refresh Riverpod memberships and organizations from server
      ref.invalidate(userMembershipsProvider);
      ref.invalidate(userOrganizationsProvider);

      // Select newly joined organization context
      await ref.read(activeOrgIdProvider.notifier).selectOrganization(result.organizationId);

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully joined ${result.organizationName}!'),
            backgroundColor: AppTheme.success,
          ),
        );
        if (widget.onJoined != null) {
          widget.onJoined!(result.organizationId, result.organizationName);
        }
      }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Organization'),
        leading: widget.onCancelTap != null
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onCancelTap,
              )
            : null,
      ),
      body: Center(
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
                    Icons.qr_code_scanner_rounded,
                    size: 64,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Join an Organization',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryNavy,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the 12-character joining code provided by your organization administrator.',
                    style: TextStyle(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  TextFormField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Joining Code *',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                      hintText: 'e.g. JOIN-7K9P-X4M2',
                    ),
                    validator: (v) => Validators.required(v, 'Joining Code'),
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
                          const Icon(Icons.error_outline, color: AppTheme.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(_error!, style: const TextStyle(color: AppTheme.error)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Join Organization'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
