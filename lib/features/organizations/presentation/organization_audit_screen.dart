import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../services/firebase_service.dart';
import 'providers/organization_providers.dart';

class OrganizationAuditScreen extends ConsumerWidget {
  const OrganizationAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeOrganizationContextProvider);
    final orgContext = state.valueOrNull?.context;
    if (state.isLoading) return const Scaffold(body: LoadingView(message: 'Loading audit history…'));
    if (orgContext == null || !orgContext.member.isAdmin) {
      return const Scaffold(body: ErrorView(title: 'Administrator access required', message: 'Only this organization’s Owner and Admins can view its audit history.'));
    }

    final stream = FirebaseService().firestore
        .collection('auditLogs')
        .where('organizationId', isEqualTo: orgContext.organization.id)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
    return Scaffold(
      appBar: AppBar(title: const Text('Organization activity')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView(message: 'Loading audit history…');
          if (snapshot.hasError) return ErrorView(message: 'Could not load organization activity: ${snapshot.error}');
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) return const Center(child: Text('No administrative activity has been recorded yet.'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final stamp = data['timestamp'];
              final date = stamp is Timestamp ? DateFormat('MMM d, yyyy • h:mm a').format(stamp.toDate().toLocal()) : 'Time unavailable';
              final action = (data['action'] as String? ?? 'ADMIN_ACTION').replaceAll('_', ' ').toLowerCase();
              final actor = data['actorUid'] as String? ?? 'System';
              final resource = data['resourceType'] as String? ?? 'record';
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.history_rounded)),
                  title: Text(action, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('$date\n$resource • ${actor == 'System' ? actor : 'Account ${actor.substring(0, actor.length > 8 ? 8 : actor.length)}'}'),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
