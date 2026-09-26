import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../services/firebase_service.dart';
import '../data/organization_repository.dart';
import '../domain/organization_enums.dart';
import 'providers/organization_providers.dart';

class OrganizationSettingsScreen extends ConsumerStatefulWidget {
  const OrganizationSettingsScreen({super.key});

  @override
  ConsumerState<OrganizationSettingsScreen> createState() => _OrganizationSettingsScreenState();
}

class _OrganizationSettingsScreenState extends ConsumerState<OrganizationSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _website = TextEditingController();
  final _logoUrl = TextEditingController();
  String? _loadedOrgId;
  bool _saving = false;
  bool _uploadingLogo = false;

  @override
  void dispose() {
    _description.dispose();
    _name.dispose();
    _website.dispose();
    _logoUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeOrganizationContextProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Organization branding')),
      body: state.when(
        loading: () => const LoadingView(message: 'Loading organization…'),
        error: (error, _) => ErrorView(message: 'Could not load the active organization: $error'),
        data: (active) {
          final orgContext = active.context;
          if (orgContext == null) {
            return const ErrorView(title: 'Choose an organization', message: 'Select an organization before changing its branding.');
          }
          final org = orgContext.organization;
          if (orgContext.member.role != OrganizationRole.owner) {
            return const ErrorView(title: 'Owner access required', message: 'Only the organization Owner can update its branding.');
          }
          if (_loadedOrgId != org.id) {
            _loadedOrgId = org.id;
            _name.text = org.name;
            _description.text = org.description;
            _website.text = org.website ?? '';
            _logoUrl.text = org.logoUrl ?? '';
            _primaryColor = org.brandColors['primary'] ?? '#2563EB';
            _secondaryColor = org.brandColors['secondary'] ?? '#0F172A';
            _accentColor = org.brandColors['accent'] ?? '#10B981';
          }

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Form(
                  key: _formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(org.name, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    const Text('Update how your organization appears to members. Organization access and verification details cannot be changed here.'),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _name,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Organization name'),
                      validator: (value) {
                        final name = value?.trim() ?? '';
                        return name.length < 3 ? 'Use at least 3 characters.' : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      maxLength: 500,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _website,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(labelText: 'Website', hintText: 'https://example.org'),
                      validator: (value) => _validOptionalHttps(value) ? null : 'Enter a valid HTTPS URL.',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _logoUrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(labelText: 'Logo image URL', hintText: 'https://example.org/logo.png'),
                      validator: (value) => _validOptionalHttps(value) ? null : 'Enter a valid HTTPS URL.',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _uploadingLogo || _saving
                          ? null
                          : () => _pickAndUploadLogo(org.id),
                      icon: _uploadingLogo
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_rounded),
                      label: Text(_uploadingLogo ? 'Uploading logo…' : 'Upload JPEG logo'),
                    ),
                    const SizedBox(height: 20),
                    Text('Brand colors', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: ValueKey('${org.id}-primary-color'),
                      initialValue: org.brandColors['primary'] ?? '#2563EB',
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Primary color', hintText: '#2563EB'),
                      validator: _validHexColor,
                      onChanged: (value) => _primaryColor = value,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: ValueKey('${org.id}-secondary-color'),
                      initialValue: org.brandColors['secondary'] ?? '#0F172A',
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Secondary color', hintText: '#0F172A'),
                      validator: _validHexColor,
                      onChanged: (value) => _secondaryColor = value,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: ValueKey('${org.id}-accent-color'),
                      initialValue: org.brandColors['accent'] ?? '#10B981',
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Accent color', hintText: '#10B981'),
                      validator: _validHexColor,
                      onChanged: (value) => _accentColor = value,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _save(org.id),
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving…' : 'Save branding'),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String? _primaryColor;
  String? _secondaryColor;
  String? _accentColor;

  String? _validHexColor(String? value) {
    final color = (value ?? '').trim();
    return RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color)
        ? null
        : 'Enter a six-digit color such as #2563EB.';
  }

  Future<void> _pickAndUploadLogo(String organizationId) async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (bytes.length < 3 || bytes[0] != 0xFF || bytes[1] != 0xD8 || bytes[2] != 0xFF) {
        throw Exception('Choose a JPEG image for the organization logo.');
      }
      setState(() => _uploadingLogo = true);
      final url = await ref.read(organizationRepositoryProvider).uploadOrganizationLogo(
            organizationId: organizationId,
            imageBytes: bytes,
          );
      if (!mounted) return;
      setState(() => _logoUrl.text = url);
      ref.read(organizationRepositoryProvider).clearCache();
      ref.invalidate(activeOrganizationContextProvider);
      ref.invalidate(userOrganizationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organization logo uploaded.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  bool _validOptionalHttps(String? input) {
    final value = (input ?? '').trim();
    if (value.isEmpty) return true;
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.contains('.') && !uri.host.startsWith('.');
  }

  Future<void> _save(String organizationId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await FirebaseService().functions.httpsCallable('updateOrganization').call({
        'organizationId': organizationId,
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'website': _website.text.trim(),
        'logoUrl': _logoUrl.text.trim(),
        'brandColors': {
          'primary': (_primaryColor ?? '#2563EB').trim(),
          'secondary': (_secondaryColor ?? '#0F172A').trim(),
          'accent': (_accentColor ?? '#10B981').trim(),
        },
      });
      ref.read(organizationRepositoryProvider).clearCache();
      ref.invalidate(activeOrganizationContextProvider);
      ref.invalidate(userOrganizationsProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Organization branding saved.')));
    } on FirebaseFunctionsException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message ?? 'Could not save branding.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save branding.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
