import 'package:flutter/material.dart';
import '../../services/diagnostics_service.dart';
import '../theme/app_theme.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final DiagnosticsService _diagnosticsService = DiagnosticsService();
  List<DiagnosticsResult> _results = [];
  bool _isRunning = true;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() => _isRunning = true);
    final results = await _diagnosticsService.runAllDiagnostics();
    
    if (mounted) {
      setState(() {
        _results = results;
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPassed = !_isRunning && _results.every((r) => r.success);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Milestone 1: Diagnostics'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 64,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(height: 24),
                Text(
                  'System Infrastructure Check',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                if (_isRunning)
                  const Center(child: CircularProgressIndicator())
                else
                  ..._results.map((result) => _buildResultCard(result)),
                  
                const SizedBox(height: 48),
                
                if (!_isRunning)
                  ElevatedButton.icon(
                    onPressed: _runDiagnostics,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rerun Diagnostics'),
                  ),
                  
                const SizedBox(height: 24),
                if (allPassed)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: AppTheme.success),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Milestone 1 completed successfully! Emulator connection, Cloud Functions, and Security Rules are fully verified.',
                            style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(DiagnosticsResult result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              result.success ? Icons.check_circle : Icons.error,
              color: result.success ? AppTheme.success : AppTheme.error,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.message,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.details,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
