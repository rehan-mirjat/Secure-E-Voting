import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.error))),
      data: (orgState) {
        if (orgState.selectionState == ActiveOrgSelectionState.noOrganizations || orgState.context == null) {
          return const _SrsWelcomeOverviewScreen();
        }

        final orgContext = orgState.context!;
        final isAdmin = orgContext.member.role == OrganizationRole.owner || orgContext.member.role == OrganizationRole.admin;
        final eventsAsync = ref.watch(votingEventRepositoryProvider).watchOrganizationVotingEvents(orgContext.organization.id);

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(activeOrganizationContextProvider);
            ref.invalidate(votingEventRepositoryProvider);
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Active Organization Context Banner Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
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
                                    'ACTIVE ORGANIZATION CONTEXT',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, letterSpacing: 0.8),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    orgContext.organization.name,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                orgContext.member.role.value.toUpperCase(),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => context.go('/orgs/members'),
                              icon: const Icon(Icons.people_outline, size: 18),
                              label: const Text('Member Directory'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => context.go('/orgs/departments'),
                              icon: const Icon(Icons.domain_outlined, size: 18),
                              label: const Text('Departments'),
                            ),
                            if (isAdmin)
                              ElevatedButton.icon(
                                onPressed: () => context.go('/admin/events'),
                                icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                                label: const Text('Manage Voting Events'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                const Text(
                  'ACTIVE & RECENT ELECTIONS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1.1),
                ),
                const SizedBox(height: 12),

                StreamBuilder<List<VotingEvent>>(
                  stream: eventsAsync,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('Error loading events: ${snapshot.error}', style: const TextStyle(color: AppTheme.error)),
                      );
                    }

                    final allEvents = snapshot.data ?? [];
                    final memberEvents = allEvents.where((e) =>
                        e.status == VotingEventStatus.active || e.status == VotingEventStatus.closed
                    ).toList();

                    if (memberEvents.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: AppTheme.surfaceBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.how_to_vote_outlined, size: 48, color: AppTheme.primaryBlue),
                              ),
                              const SizedBox(height: 20),
                              const Text('No Active Elections Open', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy)),
                              const SizedBox(height: 8),
                              const Text('There are currently no active or recent elections open for voting in this organization.', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary), textAlign: TextAlign.center),
                              if (isAdmin) ...[
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () => context.go('/admin/events/new'),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create New Voting Event'),
                                ),
                              ],
                            ],
                          ),
                        ),
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
          color: isActive ? AppTheme.primaryBlue : AppTheme.borderLight,
          width: isActive ? 2.0 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.success.withValues(alpha: 0.1) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'CLOSED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActive ? AppTheme.success : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                event.description,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Ends: ${dateFormat.format(event.endAt)}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isActive)
                  ElevatedButton.icon(
                    onPressed: () => context.go('/elections/${event.id}/vote'),
                    icon: const Icon(Icons.how_to_vote, size: 18),
                    label: const Text('Cast Ballot'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => context.go('/elections/${event.id}/vote'),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('View Receipt'),
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
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Hero Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: AppTheme.surfaceBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.how_to_vote_rounded, size: 56, color: AppTheme.primaryBlue),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Welcome to SecureVote',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondaryNavy,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Select an active organization context from the top bar to view active elections, manage members, or participate in secure voting.',
                        style: TextStyle(fontSize: 16, color: AppTheme.textSecondary, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
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
                        SizedBox(width: 20),
                        Expanded(
                          child: _CapabilityCard(
                            icon: Icons.security_outlined,
                            title: 'Multi-Tenant Security',
                            description: 'Role-based access control and department isolation ensure voting eligibility is strictly enforced.',
                          ),
                        ),
                        SizedBox(width: 20),
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primaryBlue, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
            ),
            const SizedBox(height: 8),
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
