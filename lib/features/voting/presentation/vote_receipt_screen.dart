import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/vote_receipt.dart';

class VoteReceiptScreen extends ConsumerWidget {
  const VoteReceiptScreen({
    super.key,
    required this.receipt,
    this.eventTitle,
  });

  final VoteReceipt receipt;
  final String? eventTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vote Confirmation Receipt'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Success Banner Icon
                const Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.success,
                    child: Icon(Icons.check, size: 48, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Ballot Successfully Cast!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryNavy,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                if (eventTitle != null && eventTitle!.isNotEmpty) ...[
                  Text(
                    eventTitle!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],

                // Non-coerciveness Secrecy Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: AppTheme.primaryBlue, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your vote is completely anonymous. This digital receipt confirms ballot acceptance without revealing or encoding your selection.',
                          style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.secondaryNavy),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Receipt Data Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.borderLight),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RECEIPT DETAILS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const Divider(height: 24),

                        // Receipt ID
                        _buildDetailTile(
                          context,
                          label: 'Receipt ID',
                          value: receipt.receiptId,
                          copyable: true,
                        ),
                        const SizedBox(height: 16),

                        // Verification Hash
                        _buildDetailTile(
                          context,
                          label: 'Verification Hash (SHA-256)',
                          value: receipt.receiptHash,
                          copyable: true,
                          isCode: true,
                        ),
                        const SizedBox(height: 16),

                        // Timestamp
                        _buildDetailTile(
                          context,
                          label: 'Submission Timestamp',
                          value: dateFormat.format(receipt.votedAt.toLocal()),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Return to Home Action
                ElevatedButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.home),
                  label: const Text('Return to Home Feed'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTile(
    BuildContext context, {
    required String label,
    required String value,
    bool copyable = false,
    bool isCode = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                value,
                style: TextStyle(
                  fontSize: isCode ? 12 : 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: isCode ? 'monospace' : null,
                  color: AppTheme.secondaryNavy,
                ),
              ),
            ),
            if (copyable) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy, size: 18, color: AppTheme.primaryBlue),
                tooltip: 'Copy $label',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label copied to clipboard!')),
                  );
                },
              ),
            ],
          ],
        ),
      ],
    );
  }
}
