import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../services/auth_service.dart';
import 'widgets/auth_split_layout.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.onBackToLoginTap});

  final VoidCallback? onBackToLoginTap;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSuccess = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).register(
            email: _emailController.text,
            password: _passwordController.text,
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
          );
          
      // Immediately sign out to prevent auto-login bypass of verification/profile fetching
      await ref.read(authServiceProvider).signOut();

      if (mounted) {
        setState(() {
          _isSuccess = true;
          _isLoading = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = mapFirebaseAuthError(e);
          _isLoading = false;
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

  Future<void> _googleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final cred = await authService.signInWithGoogle();

      if (mounted) {
        setState(() => _isLoading = false);
        if (cred != null && widget.onBackToLoginTap != null) {
          widget.onBackToLoginTap!();
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
    if (_isSuccess) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: AppTheme.success, size: 64),
                const SizedBox(height: 24),
                Text(
                  'Registration Successful',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your SecureVote identity has been securely generated. You may now sign in using your credentials.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    if (widget.onBackToLoginTap != null) {
                      widget.onBackToLoginTap!();
                    } else {
                      setState(() {
                        _isSuccess = false;
                        _firstNameController.clear();
                        _lastNameController.clear();
                        _emailController.clear();
                        _passwordController.clear();
                        _confirmPasswordController.clear();
                      });
                    }
                  },
                  child: const Text('Return to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AuthSplitLayout(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.borderLight),
              ),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            size: 28,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Join SecureVote',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondaryNavy,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create your platform identity to vote securely.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('FIRST NAME', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.secondaryNavy, letterSpacing: 0.5)),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _firstNameController,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [AutofillHints.givenName],
                                        decoration: const InputDecoration(hintText: 'First', prefixIcon: Icon(Icons.person_outline, size: 20)),
                                        validator: (v) => Validators.required(v, 'First Name'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('LAST NAME', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.secondaryNavy, letterSpacing: 0.5)),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _lastNameController,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [AutofillHints.familyName],
                                        decoration: const InputDecoration(hintText: 'Last', prefixIcon: Icon(Icons.person_outline, size: 20)),
                                        validator: (v) => Validators.required(v, 'Last Name'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Text('EMAIL ADDRESS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.secondaryNavy, letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(hintText: 'user@email.com', prefixIcon: Icon(Icons.email_outlined, size: 20)),
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email,
                            ),
                            const SizedBox(height: 20),
                            const Text('PASSWORD', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.secondaryNavy, letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: Validators.password,
                            ),
                            const SizedBox(height: 20),
                            const Text('CONFIRM PASSWORD', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.secondaryNavy, letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, size: 20),
                                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                              ),
                              validator: (v) => Validators.confirmPassword(v, _passwordController.text),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 24),
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
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submit,
                        icon: _isLoading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.shield_outlined, size: 18),
                        label: Text(_isLoading ? 'Creating Identity...' : 'Create Identity Securely'),
                      ),
                      const SizedBox(height: 24),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('OR', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _googleSignIn,
                        icon: Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                          height: 18,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata_rounded, size: 24),
                        ),
                        label: const Text('Continue with Google', style: TextStyle(color: AppTheme.secondaryNavy)),
                      ),
                      const SizedBox(height: 32),
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              "Already have an account? ",
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: widget.onBackToLoginTap,
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  color: AppTheme.primaryBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
