import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/organization_repository.dart';
import '../domain/organization_enums.dart';
import 'providers/organization_providers.dart';

final organizationJoiningCodesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, orgId) {
  return ref.watch(organizationRepositoryProvider).getJoiningCodes(orgId);
});

class JoiningCodesScreen extends ConsumerStatefulWidget {
  const JoiningCodesScreen({super.key});

  @override
  ConsumerState<JoiningCodesScreen> createState() => _JoiningCodesScreenState();
}

class _JoiningCodesScreenState extends ConsumerState<JoiningCodesScreen> {
  int _expiryHours = 168;
  final _maxUsesController = TextEditingController(text: '0');
  bool _creating = false;
  final _dateFormat = DateFormat.yMMMd().add_jm();

  @override
  void dispose() {
    _maxUsesController.dispose();
    super.dispose();
  }

  Future<void> _create(String orgId) async {
    final maxUses = int.tryParse(_maxUsesController.text.trim());
    if (maxUses == null || maxUses < 0 || maxUses > 100000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a maximum use count from 0 to 100,000.')),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final result = await ref.read(organizationRepositoryProvider).createJoiningCode(
            organizationId: orgId,
            expiresInHours: _expiryHours,
            maxUses: maxUses,
          );
      ref.invalidate(organizationJoiningCodesProvider(orgId));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.key_rounded, color: AppTheme.primaryBlue),
          title: const Text('Save this joining code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('This code is shown once. Share it only with people you want to join this organization.'),
              const SizedBox(height: 16),
              SelectableText(
                result.rawCode,
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: result.rawCode));
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Joining code copied.')),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy code'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _revoke(String orgId, Map<String, dynamic> code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke this code?'),
        content: Text('Anyone who has this code will no longer be able to use it. (${code['displayId'] ?? 'Joining code'})'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Revoke code')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(organizationRepositoryProvider).revokeJoiningCode(code['codeId'] as String);
      ref.invalidate(organizationJoiningCodesProvider(orgId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joining code revoked.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contextState = ref.watch(activeOrganizationContextProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Joining codes'),
        actions: [
          IconButton(
            tooltip: 'Refresh joining codes',
            onPressed: () {
              final orgId = contextState.valueOrNull?.context?.organization.id;
              if (orgId != null) ref.invalidate(organizationJoiningCodesProvider(orgId));
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: contextState.when(
        loading: () => const LoadingView(message: 'Loading organization…'),
        error: (error, _) => ErrorView(
          message: 'Could not load organization access: $error',
          onRetry: () => ref.invalidate(activeOrganizationContextProvider),
        ),
        data: (active) {
          final orgContext = active.context;
          if (orgContext == null) {
            return const EmptyView(
              icon: Icons.business_outlined,
              title: 'Select an organization',
              message: 'Choose an organization before managing joining codes.',
            );
          }
          final role = orgContext.member.role;
          if (role != OrganizationRole.owner && role != OrganizationRole.admin) {
            return const ErrorView(
              title: 'Administrator access required',
              message: 'Only this organization’s Owner and Admins can manage joining codes.',
            );
          }

          final orgId = orgContext.organization.id;
          final codes = ref.watch(organizationJoiningCodesProvider(orgId));
          final compact = MediaQuery.sizeOf(context).width < 600;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: EdgeInsets.all(compact ? 16 : 28),
                children: [
                  Text(orgContext.organization.name,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  const Text('Create and revoke codes that let people request membership.'),
                  const SizedBox(height: 20),
                  _buildCreateCard(compact, orgId),
                  const SizedBox(height: 20),
                  Text('Existing codes', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  codes.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => ErrorView(
                      message: 'Could not load joining codes: $error',
                      onRetry: () => ref.invalidate(organizationJoiningCodesProvider(orgId)),
                    ),
                    data: (items) => items.isEmpty
                        ? const Card(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('There are no joining codes for this organization.'),
                            ),
                          )
                        : Column(
                            children: items.map((item) => _codeCard(orgId, item)).toList(),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreateCard(bool compact, String orgId) => Card(
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Create a joining code', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              const Text('A code is shown once. It is stored as a secure hash and cannot be retrieved later.'),
              const SizedBox(height: 16),
              if (compact)
                Column(
                  children: [
                    _expiryPicker(),
                    const SizedBox(height: 12),
                    _maxUsesField(),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: _expiryPicker()),
                    const SizedBox(width: 14),
                    Expanded(child: _maxUsesField()),
                  ],
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _creating ? null : () => _create(orgId),
                icon: _creating
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_link_rounded),
                label: Text(_creating ? 'Creating…' : 'Create code'),
              ),
            ],
          ),
        ),
      );

  Widget _expiryPicker() => DropdownButtonFormField<int>(
        value: _expiryHours,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Expires after'),
        items: const [
          DropdownMenuItem(value: 24, child: Text('24 hours')),
          DropdownMenuItem(value: 72, child: Text('3 days')),
          DropdownMenuItem(value: 168, child: Text('7 days')),
          DropdownMenuItem(value: 720, child: Text('30 days')),
          DropdownMenuItem(value: 8760, child: Text('1 year')),
        ],
        onChanged: (value) => setState(() => _expiryHours = value ?? 168),
      );

  Widget _maxUsesField() => TextFormField(
        controller: _maxUsesController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Maximum uses',
          helperText: 'Use 0 for unlimited.',
        ),
      );

  Widget _codeCard(String orgId, Map<String, dynamic> code) {
    final status = code['status'] as String? ?? 'unknown';
    final uses = (code['currentUses'] as num?)?.toInt() ?? 0;
    final maxUses = (code['maxUses'] as num?)?.toInt() ?? 0;
    final expiry = DateTime.tryParse(code['expiresAt'] as String? ?? '');
    final expiryLabel = expiry == null ? 'Expiry unavailable' : 'Expires ${_dateFormat.format(expiry.toLocal())}';
    final active = status == 'active';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.key_outlined)),
        title: Text('Code • ${code['displayId'] ?? '••••••••'}'),
        subtitle: Text('$status • $uses${maxUses == 0 ? '' : ' of $maxUses'} uses\n$expiryLabel'),
        isThreeLine: true,
        trailing: active
            ? TextButton(
                onPressed: () => _revoke(orgId, code),
                child: const Text('Revoke'),
              )
            : null,
      ),
    );
  }
}
