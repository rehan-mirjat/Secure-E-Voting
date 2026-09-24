import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../services/auth_service.dart';
import 'email_verification_screen.dart';
import 'widgets/auth_split_layout.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.onRegisterTap,
    this.onForgotPasswordTap,
    this.onAuthenticated,
  });

  final VoidCallback? onRegisterTap;
  final VoidCallback? onForgotPasswordTap;
  final VoidCallback? onAuthenticated;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;
  bool _requiresEmailVerification = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _requiresEmailVerification = false;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (mounted) {
        // Enforce Email Verification Gate
        if (!authService.isEmailVerified) {
          setState(() {
            _requiresEmailVerification = true;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
          if (widget.onAuthenticated != null) {
            widget.onAuthenticated!();
          }
        }
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
        if (cred != null && widget.onAuthenticated != null) {
          widget.onAuthenticated!();
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
    if (_requiresEmailVerification) {
      return EmailVerificationScreen(
        onVerified: () {
          setState(() => _requiresEmailVerification = false);
          if (widget.onAuthenticated != null) {
            widget.onAuthenticated!();
          }
        },
        onSignOut: () {
          setState(() {
            _requiresEmailVerification = false;
            _passwordController.clear();
          });
        },
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
                        'Welcome Back',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondaryNavy,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Access your account and start voting',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('EMAIL ADDRESS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.secondaryNavy, letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                hintText: 'user@email.com',
                                prefixIcon: Icon(Icons.email_outlined, size: 20),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              validator: Validators.email,
                            ),
                            const SizedBox(height: 20),
                            const Text('PASSWORD', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.secondaryNavy, letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              autofillHints: const [AutofillHints.password],
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: widget.onForgotPasswordTap,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                          ),
                          child: const Text('Forgot Password?', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
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
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submit,
                        icon: _isLoading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.shield_outlined, size: 18),
                        label: Text(_isLoading ? 'Signing In...' : 'Sign In Securely'),
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
                              "New User? ",
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: widget.onRegisterTap,
                              child: const Text(
                                'Create Account',
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
