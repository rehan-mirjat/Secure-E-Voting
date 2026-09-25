import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../organizations/domain/organization_enums.dart';
import '../../../organizations/presentation/providers/organization_providers.dart';
import '../../domain/voting_event.dart';
import '../../data/voting_event_repository.dart';
import '../providers/event_lifecycle_provider.dart';
import 'event_card.dart';

class AdminEventDashboardScreen extends ConsumerWidget {
  const AdminEventDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeContextState = ref.watch(activeOrganizationContextProvider);
    final orgContext = activeContextState.valueOrNull?.context;

    if (orgContext == null) {
      return const Scaffold(
        body: ErrorView(
          title: 'No Active Organization',
          message: 'Please select an organization context to access the event management dashboard.',
        ),
      );
    }

    final orgId = orgContext.organization.id;
    final role = orgContext.member.role;

    if (!orgContext.organization.isVerified) {
      return const Scaffold(
        body: ErrorView(
          title: 'Verification pending',
          message: 'Voting event management becomes available after the organization is verified.',
        ),
      );
    }

    if (role != OrganizationRole.owner && role != OrganizationRole.admin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
         context.go('/home'); 
      });
      return const Scaffold(body: LoadingView(message: 'Verifying administrative access...'));
    }

    final eventsAsync = ref.watch(votingEventRepositoryProvider).watchOrganizationVotingEvents(orgId);
    final lifecycleState = ref.watch(eventLifecycleProvider);

    ref.listen<EventLifecycleState>(eventLifecycleProvider, (prev, next) {
       if (next.error != null && (prev?.error != next.error)) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!), backgroundColor: AppTheme.error));
       }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Management'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('admin_event_dashboard_fab'),
        onPressed: () => context.go('/admin/events/new'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Event'),
      ),
      body: Stack(
        children: [
          StreamBuilder<List<VotingEvent>>(
            stream: eventsAsync,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingView(message: 'Loading organization events...');
              }

              if (snapshot.hasError) {
                return ErrorView(
                  message: 'Error loading events: ${snapshot.error}',
                  onRetry: () => ref.invalidate(votingEventRepositoryProvider),
                );
              }

              final events = snapshot.data ?? [];

              if (events.isEmpty) {
                return EmptyView(
                  icon: Icons.how_to_vote_outlined,
                  title: 'No voting events found.',
                  message: 'Get started by creating a new voting event for your organization members.',
                  actionLabel: 'Create Voting Event',
                  onAction: () => context.go('/admin/events/new'),
                );
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return EventCard(event: event);
                    },
                  ),
                ),
              );
            },
          ),
          if (lifecycleState.isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: const LoadingView(message: 'Processing lifecycle update...'),
            ),
        ],
      ),
    );
  }
}
