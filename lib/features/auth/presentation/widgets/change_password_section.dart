import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../services/auth_service.dart';

class ChangePasswordSection extends ConsumerStatefulWidget {
  const ChangePasswordSection({super.key});

  @override
  ConsumerState<ChangePasswordSection> createState() => _ChangePasswordSectionState();
}

class _ChangePasswordSectionState extends ConsumerState<ChangePasswordSection> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.changePassword(
        currentPassword: _currentPasswordController.text, // NO trimming
        newPassword: _newPasswordController.text,         // NO trimming
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _successMessage = 'Password updated successfully!';
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Change Password',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
              ),
              const Divider(height: 24),

              if (_successMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppTheme.success),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_successMessage!, style: const TextStyle(color: AppTheme.success))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_error != null) ...[
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
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CURRENT PASSWORD', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.secondaryNavy, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: _obscureCurrent,
                    decoration: InputDecoration(
                      hintText: '•••••••••••••',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                    ),
                    validator: Validators.password,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('NEW PASSWORD', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.secondaryNavy, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      hintText: '•••••••••••••',
                      prefixIcon: const Icon(Icons.lock_reset, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    validator: Validators.password,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CONFIRM NEW PASSWORD', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.secondaryNavy, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      hintText: '•••••••••••••',
                      prefixIcon: const Icon(Icons.lock_reset, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) => Validators.confirmPassword(v, _newPasswordController.text),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Update Password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
