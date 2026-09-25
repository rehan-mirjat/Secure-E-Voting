import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../services/firebase_service.dart';
import '../../organizations/domain/organization_enums.dart';
import '../../organizations/presentation/providers/organization_providers.dart';

class EventResultsScreen extends ConsumerStatefulWidget {
  const EventResultsScreen({super.key, required this.eventId});
  final String eventId;

  @override
  ConsumerState<EventResultsScreen> createState() => _EventResultsScreenState();
}

class _EventResultsScreenState extends ConsumerState<EventResultsScreen> {
  bool _busy = false;

  Future<void> _run(String functionName) async {
    setState(() => _busy = true);
    try {
      await FirebaseService().functions.httpsCallable(functionName).call({'eventId': widget.eventId});
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message ?? 'Action failed.')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update results.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(activeOrganizationContextProvider).valueOrNull?.context?.member;
    final canManage = membership?.role == OrganizationRole.owner || membership?.role == OrganizationRole.admin;
    final results = FirebaseService().firestore.collection('eventResults').doc(widget.eventId);

    return Scaffold(
      appBar: AppBar(title: const Text('Election results')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: results.snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          if (snapshot.hasError && !canManage) {
            return const ErrorView(title: 'Results are not available', message: 'Results will appear here after they are published.');
          }
          if (snapshot.connectionState == ConnectionState.waiting && data == null && !canManage) {
            return const LoadingView(message: 'Loading published results…');
          }
          if (data == null) {
            return _empty(canManage, 'Results have not been calculated yet.');
          }

          final isPublished = data['published'] == true;
          final rawRows = (data['tallies'] as List<dynamic>?) ??
              (data['choices'] as List<dynamic>?) ?? const [];
          final rows = rawRows.whereType<Map>().map((row) {
            final value = Map<String, dynamic>.from(row);
            return <String, dynamic>{
              'name': value['name'] ?? value['label'] ?? 'Choice',
              'votes': value['votes'] ?? value['voteCount'] ?? 0,
              'percent': value['percent'] ?? 0,
            };
          }).toList();
          final total = (data['totalVotes'] as num?)?.toInt() ?? 0;
          final eligible = ((data['eligibleCount'] ?? data['eligibleVoterCount']) as num?)?.toInt() ?? 0;
          final turnout = (data['turnoutPercent'] as num?)?.toDouble() ?? 0;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(spacing: 28, runSpacing: 16, children: [
                    _metric('Ballots counted', '$total'),
                    _metric('Eligible voters', '$eligible'),
                    _metric('Turnout', '${turnout.toStringAsFixed(1)}%'),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              if (!isPublished)
                const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('These results are visible to organization administrators only until published.'))),
              for (final row in rows) _resultRow(row),
              if (rows.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No ballots were recorded for this event.'))),
              if (canManage) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _run('calculateResults'),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_busy ? 'Working…' : 'Recalculate results'),
                ),
                if (!isPublished) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run('publishResults'),
                    icon: const Icon(Icons.publish_rounded),
                    label: const Text('Publish results to members'),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _empty(bool canManage, String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.query_stats_rounded, size: 52),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              if (canManage) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _run('calculateResults'),
                  icon: const Icon(Icons.calculate_outlined),
                  label: Text(_busy ? 'Calculating…' : 'Calculate results'),
                ),
              ],
            ]),
          ),
        ),
      );

  Widget _metric(String label, String value) => SizedBox(
        width: 150,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );

  Widget _resultRow(Map<String, dynamic> row) {
    final name = row['name'] as String? ?? 'Choice';
    final votes = (row['votes'] as num?)?.toInt() ?? 0;
    final percent = ((row['percent'] as num?)?.toDouble() ?? 0).clamp(0, 100);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))), Text('$votes • ${percent.toStringAsFixed(1)}%')]),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: percent / 100, minHeight: 8, borderRadius: BorderRadius.circular(8)),
        ]),
      ),
    );
  }
}
