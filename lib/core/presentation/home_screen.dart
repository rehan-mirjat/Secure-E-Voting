import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../../features/organizations/presentation/providers/organization_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeContextState = ref.watch(activeOrganizationContextProvider);

    return activeContextState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.error))),
      data: (orgState) {
        if (orgState.selectionState == ActiveOrgSelectionState.noOrganizations) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.how_to_vote, size: 80, color: AppTheme.primaryBlue),
                const SizedBox(height: 24),
                const Text('Welcome to SecureVote!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('You do not belong to any organizations yet.', style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to orgs tab via GoRouter (handled by shell outside, but we can instruct user)
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please navigate to the Organizations tab to get started.')));
                  },
                  child: const Text('Get Started'),
                )
              ],
            ),
          );
        }

        final orgContext = orgState.context;
        if (orgContext == null) {
          return const Center(child: Text('Please select an active organization from the top menu.'));
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome, ${orgContext.member.role.value}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
              ),
              const SizedBox(height: 8),
              Text('Active Organization: ${orgContext.organization.name}', style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 32),
              
              // M5 Stub placeholder
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.how_to_vote_outlined, size: 64, color: AppTheme.textSecondary),
                        SizedBox(height: 16),
                        Text('Election Feed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                        SizedBox(height: 8),
                        Text('Election browsing and voting will arrive in Milestone 5.', style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
