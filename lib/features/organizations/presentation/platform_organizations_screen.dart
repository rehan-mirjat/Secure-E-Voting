import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../services/auth_service.dart';
import '../../../services/firebase_service.dart';

class PlatformOrganizationsScreen extends ConsumerStatefulWidget {
  const PlatformOrganizationsScreen({super.key});

  @override
  ConsumerState<PlatformOrganizationsScreen> createState() => _PlatformOrganizationsScreenState();
}

class _PlatformOrganizationsScreenState extends ConsumerState<PlatformOrganizationsScreen> {
  List<Map<String, dynamic>> _organizations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await FirebaseService().functions.httpsCallable('listOrganizationsForPlatformAdmin').call();
      final data = Map<String, dynamic>.from(response.data as Map);
      final rows = (data['organizations'] as List<dynamic>? ?? const []);
      if (!mounted) return;
      setState(() {
        _organizations = rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
        _loading = false;
      });
    } on FirebaseFunctionsException catch (error) {
      if (mounted) setState(() { _error = error.message ?? 'Could not load organizations.'; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load organizations.'; _loading = false; });
    }
  }

  Future<void> _review(Map<String, dynamic> organization, String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action[0]}${action.substring(1).toLowerCase()} organization?'),
        content: Text('${organization['name']} will move to the corresponding status.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseService().functions.httpsCallable('reviewOrganization').call({
        'organizationId': organization['id'],
        'action': action,
      });
      await _load();
    } on FirebaseFunctionsException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message ?? 'Could not update organization.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(platformAdminProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Platform organizations'), actions: [IconButton(onPressed: _loading ? null : _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded))]),
      body: admin.when(
        loading: () => const LoadingView(message: 'Checking platform access…'),
        error: (_, __) => const ErrorView(title: 'Access unavailable', message: 'Could not verify platform administrator access.'),
        data: (isAdmin) => !isAdmin
            ? const ErrorView(title: 'Platform access required', message: 'This area is available only to Platform Super Admins.')
            : _loading
                ? const LoadingView(message: 'Loading organizations…')
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : _organizations.isEmpty
                        ? const Center(child: Text('No organizations have been registered yet.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _organizations.length,
                            itemBuilder: (context, index) => _organizationCard(_organizations[index]),
                          ),
      ),
    );
  }

  Widget _organizationCard(Map<String, dynamic> organization) {
    final status = organization['status'] as String? ?? 'pending';
    final name = organization['name'] as String? ?? 'Organization';
    final address = [organization['city'], organization['country']].whereType<String>().where((part) => part.isNotEmpty).join(', ');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(name, style: Theme.of(context).textTheme.titleMedium)), Chip(label: Text(status.toUpperCase()))]),
          if ((organization['email'] as String? ?? '').isNotEmpty) Text(organization['email'] as String),
          if (address.isNotEmpty) Text(address, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (status == 'pending') ...[
              FilledButton.tonal(onPressed: () => _review(organization, 'VERIFY'), child: const Text('Verify')),
              OutlinedButton(onPressed: () => _review(organization, 'REJECT'), child: const Text('Reject')),
            ],
            if (status == 'verified' || status == 'active')
              OutlinedButton(onPressed: () => _review(organization, 'SUSPEND'), child: const Text('Suspend')),
            if (status == 'suspended')
              FilledButton.tonal(onPressed: () => _review(organization, 'REACTIVATE'), child: const Text('Reactivate')),
          ]),
        ]),
      ),
    );
  }
}
