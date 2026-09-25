import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final _description = TextEditingController();
  final _website = TextEditingController();
  final _logoUrl = TextEditingController();
  String? _loadedOrgId;
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
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
            _description.text = org.description;
            _website.text = org.website ?? '';
            _logoUrl.text = org.logoUrl ?? '';
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
        'description': _description.text.trim(),
        'website': _website.text.trim(),
        'logoUrl': _logoUrl.text.trim(),
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
