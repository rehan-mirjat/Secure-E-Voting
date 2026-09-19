import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
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
      return const Scaffold(body: Center(child: Text('No active organization.')));
    }

    final orgId = orgContext.organization.id;
    final role = orgContext.member.role;

    // 14.1 & 14.2: Guard access to active Owners/Admins
    if (role != OrganizationRole.owner && role != OrganizationRole.admin) {
      // Typically this is handled in router redirection, but as an extra guard:
      WidgetsBinding.instance.addPostFrameCallback((_) {
         // Fallback redirect if they somehow landed here
         context.go('/org/$orgId'); 
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final eventsAsync = ref.watch(votingEventRepositoryProvider).watchOrganizationVotingEvents(orgId);
    final lifecycleState = ref.watch(eventLifecycleProvider);

    // Watch for lifecycle errors/success and display snackbars
    ref.listen<EventLifecycleState>(eventLifecycleProvider, (prev, next) {
       if (next.error != null && (prev?.error != next.error)) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!), backgroundColor: AppTheme.error));
       }
       if (next.successMessage != null && (prev?.successMessage != next.successMessage)) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.successMessage!), backgroundColor: AppTheme.success));
       }
    });

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Event Management'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Create Voting Event',
                onPressed: () => context.go('/admin/events/new'),
              )
            ],
          ),
          body: StreamBuilder<List<VotingEvent>>(
            stream: eventsAsync,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                 return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                 return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.error)));
              }
              
              final events = snapshot.data ?? [];

              if (events.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_note, size: 64, color: AppTheme.textSecondary),
                      const SizedBox(height: 16),
                      const Text('No voting events found.', style: TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context.go('/admin/events/new'),
                        child: const Text('Create your first Voting Event'),
                      )
                    ],
                  )
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                itemBuilder: (ctx, i) {
                  return EventCard(event: events[i]);
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
             onPressed: () => context.go('/admin/events/new'),
             child: const Icon(Icons.add),
          ),
        ),
        if (lifecycleState.isLoading)
           Container(
             color: Colors.black45,
             child: const Center(child: CircularProgressIndicator()),
           )
      ],
    );
  }
}
