import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../services/firebase_service.dart';

class EventMonitoringScreen extends StatefulWidget {
  const EventMonitoringScreen({super.key, required this.eventId});
  final String eventId;

  @override
  State<EventMonitoringScreen> createState() => _EventMonitoringScreenState();
}

class _EventMonitoringScreenState extends State<EventMonitoringScreen> {
  Map<String, dynamic>? _summary;
  Object? _error;
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final response = await FirebaseService().functions
          .httpsCallable('getEventMonitoring')
          .call({'eventId': widget.eventId});
      if (!mounted) return;
      setState(() {
        _summary = Map<String, dynamic>.from(response.data as Map);
        _error = null;
        _loading = false;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message ?? 'Could not load turnout.';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final eligible = (summary?['eligibleCount'] as num?)?.toInt() ?? 0;
    final participation = (summary?['participationCount'] as num?)?.toInt() ?? 0;
    final turnout = ((summary?['turnoutPercent'] as num?)?.toDouble() ?? 0).clamp(0, 100);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live turnout'),
        actions: [IconButton(onPressed: _loading ? null : _refresh, tooltip: 'Refresh now', icon: const Icon(Icons.refresh_rounded))],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: _loading && summary == null
                ? const Center(child: CircularProgressIndicator())
                : _error != null && summary == null
                    ? Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.lock_outline_rounded, size: 44),
                        const SizedBox(height: 12),
                        Text('Turnout could not be loaded: $_error', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Try again')),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text('Participation overview', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('This summary contains no voter identities or ballot selections. It refreshes automatically every 15 seconds.'),
                        const SizedBox(height: 24),
                        Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('$participation of $eligible', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          const Text('eligible members have participated'),
                          const SizedBox(height: 18),
                          LinearProgressIndicator(value: eligible == 0 ? 0.0 : (participation / eligible).clamp(0, 1).toDouble(), minHeight: 12, borderRadius: BorderRadius.circular(10)),
                          const SizedBox(height: 12),
                          Text('${turnout.toStringAsFixed(1)}% turnout', style: Theme.of(context).textTheme.titleMedium),
                        ]))),
                        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text('Refresh issue: $_error', style: TextStyle(color: Theme.of(context).colorScheme.error))),
                      ]),
          ),
        ),
      ),
    );
  }
}
