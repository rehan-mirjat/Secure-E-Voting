import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/auth_service.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key, this.onVerified, this.onSignOut});

  final VoidCallback? onVerified;
  final VoidCallback? onSignOut;

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  int _cooldownSeconds = 0;
  Timer? _timer;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown([int seconds = 30]) {
    setState(() => _cooldownSeconds = seconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_cooldownSeconds > 1) {
          setState(() => _cooldownSeconds--);
        } else {
          _timer?.cancel();
          setState(() => _cooldownSeconds = 0);
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _checkStatus() async {
    setState(() {
      _isChecking = true;
      _message = null;
      _error = null;
    });

    try {
      final isVerified = await ref.read(authServiceProvider).checkEmailVerified();
      if (mounted) {
        if (isVerified) {
          setState(() {
            _message = 'Email verified successfully!';
            _isChecking = false;
          });
          if (widget.onVerified != null) {
            widget.onVerified!();
          }
        } else {
          setState(() {
            _error = 'Email is not verified yet. Please check your inbox and click the verification link.';
            _isChecking = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error checking status: ${e.toString()}';
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _resendEmail() async {
    if (_cooldownSeconds > 0) return;

    setState(() {
      _isResending = true;
      _message = null;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).sendEmailVerification();
      if (mounted) {
        setState(() {
          _message = 'A new verification email has been sent. Please check your inbox.';
          _isResending = false;
        });
        _startCooldown(30);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to resend email: ${e.toString()}';
          _isResending = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
    if (widget.onSignOut != null) {
      widget.onSignOut!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = ref.watch(authServiceProvider).currentUser?.email ?? 'your email address';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 72,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verify Your Email Address',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryNavy,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'We have sent a verification link to:\n$userEmail',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please click the link in your email to unlock complete platform access.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                if (_message != null) ...[
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
                        Expanded(
                          child: Text(_message!, style: const TextStyle(color: AppTheme.success)),
                        ),
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
                        Expanded(
                          child: Text(_error!, style: const TextStyle(color: AppTheme.error)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                ElevatedButton.icon(
                  onPressed: _isChecking ? null : _checkStatus,
                  icon: _isChecking
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text("I've Verified My Email"),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: (_isResending || _cooldownSeconds > 0) ? null : _resendEmail,
                  icon: _isResending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(_cooldownSeconds > 0
                      ? 'Resend Email in ${_cooldownSeconds}s'
                      : 'Resend Verification Email'),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: _signOut,
                  child: const Text('Sign Out / Use Different Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
