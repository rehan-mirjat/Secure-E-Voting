import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../services/auth_service.dart';
import '../data/user_repository.dart';
import '../domain/app_user.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.uid, this.onSignOut});

  final String uid;
  final VoidCallback? onSignOut;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;
  bool _initialized = false;
  String? _error;
  String? _successMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _populateControllers(AppUser user) {
    if (!_initialized && !_isEditing) {
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
      _initialized = true;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
      _successMessage = null;
    });

    try {
      await ref.read(userRepositoryProvider).updateProfile(
            uid: widget.uid,
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
          );

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
          _successMessage = 'Profile updated successfully!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to update profile: ${e.toString()}';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider(widget.uid));
    final isEmailVerified = ref.watch(authServiceProvider).isEmailVerified;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error loading profile: ${err.toString()}', style: const TextStyle(color: AppTheme.error)),
          ),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User profile not found.'));
          }

          _populateControllers(user);
          final dateFormat = DateFormat('MMMM d, yyyy');

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Avatar Header
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        child: Text(
                          user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.displayName.isNotEmpty ? user.displayName : user.email,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

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

                      // Personal Information Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Personal Information',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
                                  ),
                                  IconButton(
                                    icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined),
                                    onPressed: () {
                                      setState(() {
                                        _isEditing = !_isEditing;
                                        if (!_isEditing) {
                                          _firstNameController.text = user.firstName;
                                          _lastNameController.text = user.lastName;
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _firstNameController,
                                      enabled: _isEditing,
                                      decoration: const InputDecoration(labelText: 'First Name'),
                                      validator: (v) => Validators.required(v, 'First Name'),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _lastNameController,
                                      enabled: _isEditing,
                                      decoration: const InputDecoration(labelText: 'Last Name'),
                                      validator: (v) => Validators.required(v, 'Last Name'),
                                    ),
                                  ),
                                ],
                              ),
                              if (_isEditing) ...[
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: _isSaving ? null : _saveProfile,
                                  child: _isSaving
                                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text('Save Changes'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // System Security Metadata Card (Read-Only)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Account Security Status',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
                              ),
                              const Divider(height: 24),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.verified_outlined, color: AppTheme.primaryBlue),
                                title: const Text('Email Verification'),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isEmailVerified ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isEmailVerified ? 'Verified' : 'Unverified',
                                    style: TextStyle(
                                      color: isEmailVerified ? AppTheme.success : AppTheme.warning,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.shield_outlined, color: AppTheme.primaryBlue),
                                title: const Text('Account Status'),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    user.status.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppTheme.success,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.calendar_today_outlined, color: AppTheme.primaryBlue),
                                title: const Text('Member Since'),
                                subtitle: Text(dateFormat.format(user.createdAt)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          if (widget.onSignOut != null) {
                            widget.onSignOut!();
                          }
                          await ref.read(authServiceProvider).signOut();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
