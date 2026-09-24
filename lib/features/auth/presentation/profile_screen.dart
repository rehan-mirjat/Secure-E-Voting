import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../services/auth_service.dart';
import '../../../services/firebase_service.dart';
import '../data/user_repository.dart';
import '../domain/app_user.dart';
import 'widgets/change_password_section.dart';

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
  bool _isUploadingPhoto = false;
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

  Future<void> _pickAndUploadImage() async {
    setState(() {
      _isUploadingPhoto = true;
      _error = null;
    });

    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        await ref.read(userRepositoryProvider).uploadProfilePhoto(
              uid: widget.uid,
              imageBytes: bytes,
            );
        ref.invalidate(userProfileProvider(widget.uid));
        if (mounted) {
          setState(() {
            _successMessage = 'Profile photo updated!';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to upload image: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
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

  void _confirmDeleteAccount(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.error),
            SizedBox(width: 8),
            Text('Delete Account?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete your account?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'This action cannot be undone. Your user profile will be permanently deleted and you will lose access to all associated organizations.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(authServiceProvider).deleteAccount();
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Your account has been deleted.'), backgroundColor: AppTheme.success),
          );
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Failed to delete account: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider(widget.uid));
    final authService = ref.watch(authServiceProvider);
    final currentUser = authService.currentUser;
    final isEmailVerified = authService.isEmailVerified;

    final hasPasswordProvider = currentUser?.providerData.any((p) => p.providerId == 'password') ?? false;
    final hasGoogleProvider = currentUser?.providerData.any((p) => p.providerId == 'google.com') ?? false;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Profile Settings'),
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

          final leftColumn = _buildLeftColumn(
            context,
            user,
            isEmailVerified,
            hasPasswordProvider,
            hasGoogleProvider,
            dateFormat,
          );

          final rightColumn = _buildRightColumn(context);

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: leftColumn),
                          const SizedBox(width: 24),
                          Expanded(flex: 1, child: rightColumn),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          leftColumn,
                          const SizedBox(height: 24),
                          rightColumn,
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeftColumn(
    BuildContext context,
    AppUser user,
    bool isEmailVerified,
    bool hasPasswordProvider,
    bool hasGoogleProvider,
    DateFormat dateFormat,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // PROFILE HEADER
        Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    ClipOval(
                      child: Container(
                        width: 96,
                        height: 96,
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        child: _isUploadingPhoto
                            ? const Center(child: CircularProgressIndicator())
                            : (user.photoUrl != null && user.photoUrl!.isNotEmpty
                                ? Image.network(
                                    FirebaseService.sanitizeStorageUrl(user.photoUrl!),
                                    width: 96,
                                    height: 96,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Text(
                                          user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
                                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                        ),
                                      );
                                    },
                                  )
                                : Center(
                                    child: Text(
                                      user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
                                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                    ),
                                  )),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Tooltip(
                        message: 'Change profile photo',
                        child: InkWell(
                          onTap: _isUploadingPhoto ? null : _pickAndUploadImage,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName.isNotEmpty ? user.displayName : user.email,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondaryNavy,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (isEmailVerified) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('VERIFIED', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: user.status == 'active' ? AppTheme.primaryBlue.withValues(alpha: 0.1) : AppTheme.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(user.status.toUpperCase(), style: TextStyle(color: user.status == 'active' ? AppTheme.primaryBlue : AppTheme.warning, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Member since ${dateFormat.format(user.createdAt)}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        if (_successMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppTheme.success),
                const SizedBox(width: 12),
                Expanded(child: Text(_successMessage!, style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
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
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personal Information',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Manage your basic profile information.',
                              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (!_isEditing)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit Profile'),
                          onPressed: () => setState(() => _isEditing = true),
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('FIRST NAME', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.secondaryNavy, letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            _isEditing
                                ? TextFormField(
                                    controller: _firstNameController,
                                    decoration: const InputDecoration(hintText: 'First Name'),
                                    validator: (v) => Validators.required(v, 'First Name'),
                                  )
                                : Text(user.firstName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('LAST NAME', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.secondaryNavy, letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            _isEditing
                                ? TextFormField(
                                    controller: _lastNameController,
                                    decoration: const InputDecoration(hintText: 'Last Name'),
                                    validator: (v) => Validators.required(v, 'Last Name'),
                                  )
                                : Text(user.lastName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('EMAIL ADDRESS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.secondaryNavy, letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      Text(user.email, style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                    ],
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = false;
                              _firstNameController.text = user.firstName;
                              _lastNameController.text = user.lastName;
                            });
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          child: _isSaving
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Save Changes'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Security Section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Security',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
                ),
                const SizedBox(height: 32),
                
                const Text('AUTHENTICATION METHOD', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.secondaryNavy, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Text(
                  hasGoogleProvider && hasPasswordProvider
                      ? 'Email/Password + Google'
                      : hasGoogleProvider
                          ? 'Google Sign-In'
                          : 'Email & Password',
                  style: const TextStyle(fontSize: 16),
                ),
                
                const SizedBox(height: 24),
                
                // Password Management
                const Text('PASSWORD', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.secondaryNavy, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                if (hasPasswordProvider)
                  const ChangePasswordSection()
                else
                  const Text('Managed securely through Google Sign-In.', style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Card(
          color: AppTheme.surfaceBlue,
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppTheme.primaryBlue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Account Security',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Your SecureVote account controls access to your organizations and voting administration features.',
                  style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.secondaryNavy),
                ),
                SizedBox(height: 12),
                Text(
                  'Voting choices and cryptographic ballot receipts are NOT displayed or editable from your profile to maintain absolute secrecy.',
                  style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.secondaryNavy),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Danger Zone
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Danger Zone',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.error),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sign out from this SecureVote account on the current device.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                  ),
                  onPressed: () async {
                    if (widget.onSignOut != null) {
                      widget.onSignOut!();
                    }
                    await ref.read(authServiceProvider).signOut();
                  },
                ),
                const Divider(height: 32),
                const Text(
                  'Permanently delete your user account and profile data.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever, size: 18),
                  label: const Text('Delete Account'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _confirmDeleteAccount(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
