import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../organizations/domain/organization_enums.dart';
import '../../../organizations/presentation/providers/organization_providers.dart';
import '../../data/voting_event_repository.dart';
import '../providers/draft_event_provider.dart';

import 'basic_info_step.dart';
import 'schedule_step.dart';
import 'eligibility_step.dart';
import 'choices_step.dart';
import 'review_step.dart';

class EventBuilderScreen extends ConsumerStatefulWidget {
  final String? existingEventId;
  final int initialStep;
  const EventBuilderScreen(
      {super.key, this.existingEventId, this.initialStep = 0});

  @override
  ConsumerState<EventBuilderScreen> createState() => _EventBuilderScreenState();
}

class _EventBuilderScreenState extends ConsumerState<EventBuilderScreen> {
  int _currentStep = 0;
  String? _loadingEventId;

  @override
  Widget build(BuildContext context) {
    final activeContextState = ref.watch(activeOrganizationContextProvider);
    final orgContext = activeContextState.valueOrNull?.context;

    if (orgContext == null) {
      return const Scaffold(
          body: Center(child: Text('No active organization.')));
    }

    final orgId = orgContext.organization.id;
    final role = orgContext.member.role;

    if (widget.existingEventId != null &&
        ref.watch(draftEventProvider(orgId)).serverEventId !=
            widget.existingEventId) {
      if (_loadingEventId != widget.existingEventId) {
        _loadingEventId = widget.existingEventId;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _loadExistingEvent(orgId));
      }
      return const Scaffold(body: LoadingView(message: 'Loading event draft…'));
    }

    if (role != OrganizationRole.owner && role != OrganizationRole.admin) {
      return const Scaffold(
          body: Center(child: Text('Unauthorized: Admins only.')));
    }

    final draftState = ref.watch(draftEventProvider(orgId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text(
                'Are you sure you want to leave the builder? Unsaved progress will be lost.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  ref.read(draftEventProvider(orgId).notifier).reset();
                  Navigator.pop(ctx, true);
                },
                child: const Text('Leave',
                    style: TextStyle(color: AppTheme.error)),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(draftState.serverEventId != null
              ? 'Edit Event Draft'
              : 'Create Voting Event'),
        ),
        body: Stepper(
          type: ResponsiveLayout.isWide(context)
              ? StepperType.horizontal
              : StepperType.vertical,
          currentStep: _currentStep,
          onStepTapped: (step) {
            _handleStepTap(step, orgId, draftState.serverEventId);
          },
          controlsBuilder: (context, details) =>
              const SizedBox.shrink(), // Custom controls in each step
          steps: [
            Step(
              title: const Text('Basic Info'),
              content: BasicInfoStep(
                  orgId: orgId, onNext: () => setState(() => _currentStep = 1)),
              isActive: _currentStep >= 0,
            ),
            Step(
              title: const Text('Schedule'),
              content: ScheduleStep(
                  orgId: orgId,
                  onNext: () => setState(() => _currentStep = 2),
                  onBack: () => setState(() => _currentStep = 0)),
              isActive: _currentStep >= 1,
            ),
            Step(
              title: const Text('Eligibility'),
              content: EligibilityStep(
                  orgId: orgId,
                  onNext: () => setState(() => _currentStep = 3),
                  onBack: () => setState(() => _currentStep = 1)),
              isActive: _currentStep >= 2,
            ),
            Step(
              title: const Text('Choices'),
              content: draftState.serverEventId == null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const Text(
                              'Please complete the Eligibility step and tap "Create Draft & Continue" first.'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () async {
                              final success = await ref
                                  .read(draftEventProvider(orgId).notifier)
                                  .createServerDraft();
                              if (success && mounted) {
                                setState(() {});
                              }
                            },
                            child: const Text('Create Draft Now'),
                          ),
                        ],
                      ),
                    )
                  : ChoicesStep(
                      orgId: orgId,
                      onNext: () => setState(() => _currentStep = 4),
                      onBack: () => setState(() => _currentStep = 2)),
              isActive: _currentStep >= 3,
            ),
            Step(
              title: const Text('Review'),
              content: draftState.serverEventId == null
                  ? const Center(child: Text('Create Draft first.'))
                  : ReviewStep(
                      orgId: orgId,
                      onBack: () => setState(() => _currentStep = 3)),
              isActive: _currentStep >= 4,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleStepTap(
      int step, String organizationId, String? serverEventId) async {
    if (ref.read(draftEventProvider(organizationId)).isLoading) return;

    if (step <= _currentStep) {
      setState(() => _currentStep = step);
      return;
    }

    if (serverEventId == null) {
      // Basic Info and Schedule must be completed with their own Continue
      // buttons. From Eligibility, tapping Choices is also a valid Continue
      // action: EligibilityStep keeps its current selections in the draft
      // provider, then the server draft is created before opening Choices.
      if (_currentStep != 2 || step != 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Complete each step with its Continue button before moving ahead.'),
            backgroundColor: AppTheme.warning,
          ),
        );
        return;
      }

      final created = await ref
          .read(draftEventProvider(organizationId).notifier)
          .createServerDraft();
      if (!mounted || !created) return;
    }

    if (mounted) setState(() => _currentStep = step);
  }

  Future<void> _loadExistingEvent(String organizationId) async {
    if (!mounted || widget.existingEventId == null) return;
    try {
      final loadedEvent = await ref
          .read(votingEventRepositoryProvider)
          .watchVotingEvent(widget.existingEventId!)
          .first;
      if (!mounted) return;
      if (loadedEvent == null) throw StateError('Event not found.');
      final event = loadedEvent;
      if (event.organizationId != organizationId) {
        throw Exception('This event belongs to a different organization.');
      }
      ref
          .read(draftEventProvider(organizationId).notifier)
          .loadExistingDraft(event);
      setState(() => _currentStep = widget.initialStep.clamp(0, 4).toInt());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load this event: $error')));
        Navigator.of(context).maybePop();
      }
    }
  }
}
