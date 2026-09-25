import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../widgets/empty_view.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/status_badge.dart';
import '../../features/organizations/domain/organization_enums.dart';
import '../../features/organizations/presentation/providers/organization_providers.dart';
import '../../features/voting_events/data/voting_event_repository.dart';
import '../../features/voting_events/domain/voting_event.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeContextState = ref.watch(activeOrganizationContextProvider);

    return activeContextState.when(
      loading: () => const LoadingView(message: 'Restoring active context...'),
      error: (e, _) => ErrorView(
        message: 'Failed to restore active organization: $e',
        onRetry: () => ref.invalidate(activeOrganizationContextProvider),
      ),
      data: (orgState) {
        if (orgState.selectionState == ActiveOrgSelectionState.noOrganizations || orgState.context == null) {
          return const _SrsWelcomeOverviewScreen();
        }

        final orgContext = orgState.context!;
        final isAdmin = orgContext.member.role == OrganizationRole.owner || orgContext.member.role == OrganizationRole.admin;
        final eventsAsync = ref.watch(votingEventRepositoryProvider).watchOrganizationVotingEvents(orgContext.organization.id);

        return RefreshIndicator(
          color: AppTheme.primaryBlue,
          onRefresh: () async {
            ref.invalidate(activeOrganizationContextProvider);
            ref.invalidate(votingEventRepositoryProvider);
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Active Organization Context Banner Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.business_rounded, color: AppTheme.primaryBlue, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ACTIVE ORGANIZATION',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, letterSpacing: 0.8),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    orgContext.organization.name,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge.role(orgContext.member.role.value),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => context.go('/orgs/members'),
                              icon: const Icon(Icons.people_outline_rounded, size: 18),
                              label: const Text('Directory'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 42),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => context.go('/orgs/departments'),
                              icon: const Icon(Icons.domain_outlined, size: 18),
                              label: const Text('Departments'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 42),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                            if (isAdmin)
                              ElevatedButton.icon(
                                onPressed: () => context.go('/admin/events'),
                                icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                                label: const Text('Manage Events'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 42),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                const Text(
                  'ACTIVE & RECENT ELECTIONS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1.1),
                ),
                const SizedBox(height: 12),

                StreamBuilder<List<VotingEvent>>(
                  stream: eventsAsync,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LoadingView(message: 'Loading active elections...');
                    }

                    if (snapshot.hasError) {
                      return ErrorView(
                        message: 'Error loading elections: ${snapshot.error}',
                        onRetry: () => ref.invalidate(votingEventRepositoryProvider),
                      );
                    }

                    final allEvents = snapshot.data ?? [];
                    final memberEvents = allEvents.where((e) =>
                        e.status == VotingEventStatus.active || e.status == VotingEventStatus.closed
                    ).toList();

                    if (memberEvents.isEmpty) {
                      return EmptyView(
                        icon: Icons.how_to_vote_outlined,
                        title: 'No Active Elections',
                        message: 'There are currently no active or recent elections in this organization.',
                        actionLabel: isAdmin ? 'Create Voting Event' : null,
                        onAction: isAdmin ? () => context.go('/admin/events/new') : null,
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: memberEvents.length,
                      itemBuilder: (context, index) {
                        final event = memberEvents[index];
                        return _buildMemberEventCard(context, event);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMemberEventCard(BuildContext context, VotingEvent event) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final isActive = event.status == VotingEventStatus.active;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive ? AppTheme.primaryBlue.withValues(alpha: 0.5) : AppTheme.borderLight,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge.eventStatus(event.status.name),
              ],
            ),
            const SizedBox(height: 8),
            StatusBadge.privacyMode(event.privacyMode.name),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                event.description,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 15, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Ends: ${dateFormat.format(event.endAt)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/elections/${event.id}'),
                  icon: const Icon(Icons.info_outline_rounded, size: 16),
                  label: const Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                if (isActive)
                  ElevatedButton.icon(
                    onPressed: () => context.go('/elections/${event.id}/vote'),
                    icon: const Icon(Icons.how_to_vote_rounded, size: 16),
                    label: const Text('Cast Vote'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SrsWelcomeOverviewScreen extends StatelessWidget {
  const _SrsWelcomeOverviewScreen();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Hero Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: AppTheme.surfaceBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.how_to_vote_rounded, size: 48, color: AppTheme.primaryBlue),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Welcome to SecureVote',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondaryNavy,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Select an active organization context from the top bar to view active elections, manage members, or participate in secure voting.',
                        style: TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/orgs'),
                        icon: const Icon(Icons.business_outlined),
                        label: const Text('Browse Joined Organizations'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'PLATFORM CAPABILITIES & VERIFIABILITY',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1.1),
              ),
              const SizedBox(height: 16),

              // 3 SRS Capability Cards
              isDesktop
                  ? const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _CapabilityCard(
                            icon: Icons.receipt_long_outlined,
                            title: 'Cryptographic Receipts',
                            description: 'Every cast ballot generates an anonymous, tamper-evident SHA-256 receipt for independent verification.',
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _CapabilityCard(
                            icon: Icons.security_outlined,
                            title: 'Multi-Tenant Security',
                            description: 'Role-based access control and department isolation ensure voting eligibility is strictly enforced.',
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _CapabilityCard(
                            icon: Icons.timelapse_outlined,
                            title: 'Lifecycle Auditing',
                            description: 'Voting events transition automatically through Scheduled, Active, and Closed lifecycles with audit logs.',
                          ),
                        ),
                      ],
                    )
                  : const Column(
                      children: [
                        _CapabilityCard(
                          icon: Icons.receipt_long_outlined,
                          title: 'Cryptographic Receipts',
                          description: 'Every cast ballot generates an anonymous, tamper-evident SHA-256 receipt for independent verification.',
                        ),
                        SizedBox(height: 16),
                        _CapabilityCard(
                          icon: Icons.security_outlined,
                          title: 'Multi-Tenant Security',
                          description: 'Role-based access control and department isolation ensure voting eligibility is strictly enforced.',
                        ),
                        SizedBox(height: 16),
                        _CapabilityCard(
                          icon: Icons.timelapse_outlined,
                          title: 'Lifecycle Auditing',
                          description: 'Voting events transition automatically through Scheduled, Active, and Closed lifecycles with audit logs.',
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primaryBlue, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
