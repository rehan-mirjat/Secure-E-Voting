import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../data/organization_repository.dart';
import 'providers/organization_providers.dart';

class CreateOrganizationScreen extends ConsumerStatefulWidget {
  const CreateOrganizationScreen({
    super.key,
    this.onOrganizationCreated,
    this.onCancelTap,
  });

  final Function(String organizationId)? onOrganizationCreated;
  final VoidCallback? onCancelTap;

  @override
  ConsumerState<CreateOrganizationScreen> createState() => _CreateOrganizationScreenState();
}

class _CreateOrganizationScreenState extends ConsumerState<CreateOrganizationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _websiteController = TextEditingController();

  Uint8List? _selectedLogoBytes;
  String _selectedType = 'academic';
  bool _isLoading = false;
  String? _error;

  final List<DropdownMenuItem<String>> _typeOptions = const [
    DropdownMenuItem(value: 'academic', child: Text('Academic Institution')),
    DropdownMenuItem(value: 'corporate', child: Text('Corporate Enterprise')),
    DropdownMenuItem(value: 'nonProfit', child: Text('Non-Profit Organization')),
    DropdownMenuItem(value: 'club', child: Text('Club / Student Society')),
    DropdownMenuItem(value: 'community', child: Text('Community Association')),
    DropdownMenuItem(value: 'other', child: Text('Other')),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  String? _validateWebsite(String? value) {
    return Validators.website(value);
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() => _selectedLogoBytes = bytes);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(organizationRepositoryProvider);
      final orgId = await repo.createOrganization(
        name: _nameController.text,
        type: _selectedType,
        description: _descriptionController.text,
        email: _emailController.text,
        country: _countryController.text,
        city: _cityController.text,
        website: _websiteController.text.trim().isNotEmpty ? _websiteController.text : null,
      );

      // Post-Creation Logo Upload Flow (Rule 4)
      if (_selectedLogoBytes != null) {
        try {
          await repo.uploadOrganizationLogo(
            organizationId: orgId,
            imageBytes: _selectedLogoBytes!,
          );
        } catch (logoErr) {
          // Organization creation remains successful even if logo fails
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Organization created, but logo upload failed: ${logoErr.toString().replaceAll('Exception: ', '')}'),
                backgroundColor: AppTheme.warning,
              ),
            );
          }
        }
      }

      // Refresh Riverpod memberships from server
      ref.invalidate(userMembershipsProvider);

      // Select newly created organization context
      await ref.read(activeOrgIdProvider.notifier).selectOrganization(orgId);

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Organization created successfully! Status is pending verification.'),
            backgroundColor: AppTheme.success,
          ),
        );
        if (widget.onOrganizationCreated != null) {
          widget.onOrganizationCreated!(orgId);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Organization'),
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
            constraints: const BoxConstraints(maxWidth: 550),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickLogo,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        backgroundImage: _selectedLogoBytes != null ? MemoryImage(_selectedLogoBytes!) : null,
                        child: _selectedLogoBytes == null
                            ? const Icon(Icons.add_a_photo_outlined, size: 36, color: AppTheme.primaryBlue)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Tap to select Organization Logo (Optional)', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 20),
                  const Text(
                    'Register an Organization',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryNavy,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create an isolated multi-tenant organization to host elections and polls.',
                    style: TextStyle(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Organization Name *',
                      prefixIcon: Icon(Icons.business_outlined),
                      hintText: 'e.g. Apex Academic Institute',
                    ),
                    validator: (v) {
                      final req = Validators.required(v, 'Organization Name');
                      if (req != null) return req;
                      if (v!.trim().length < 3) return 'Name must be at least 3 characters';
                      if (v.trim().length > 100) return 'Name cannot exceed 100 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Organization Type *',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: _typeOptions,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Brief summary of the organization...',
                    ),
                    validator: (v) {
                      if (v != null && v.trim().length > 500) {
                        return 'Description cannot exceed 500 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emailController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Official Contact Email *',
                      prefixIcon: Icon(Icons.email_outlined),
                      hintText: 'contact@organization.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _countryController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Country *',
                            prefixIcon: Icon(Icons.flag_outlined),
                          ),
                          validator: (v) => Validators.required(v, 'Country'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _cityController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'City *',
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                          validator: (v) => Validators.required(v, 'City'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _websiteController,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Website URL (Optional)',
                      prefixIcon: Icon(Icons.language_outlined),
                      hintText: 'https://organization.com',
                    ),
                    keyboardType: TextInputType.url,
                    validator: _validateWebsite,
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
                        : const Text('Submit Organization Registration'),
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
