import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../organizations/domain/organization_enums.dart';
import '../../../organizations/presentation/providers/organization_providers.dart';
import '../providers/draft_event_provider.dart';

import 'basic_info_step.dart';
import 'schedule_step.dart';
import 'eligibility_step.dart';
import 'choices_step.dart';
import 'review_step.dart';

class EventBuilderScreen extends ConsumerStatefulWidget {
  final String? existingEventId;
  const EventBuilderScreen({super.key, this.existingEventId});

  @override
  ConsumerState<EventBuilderScreen> createState() => _EventBuilderScreenState();
}

class _EventBuilderScreenState extends ConsumerState<EventBuilderScreen> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    final activeContextState = ref.watch(activeOrganizationContextProvider);
    final orgContext = activeContextState.valueOrNull?.context;

    if (orgContext == null) {
      return const Scaffold(body: Center(child: Text('No active organization.')));
    }

    final orgId = orgContext.organization.id;
    final role = orgContext.member.role;

    if (role != OrganizationRole.owner && role != OrganizationRole.admin) {
      return const Scaffold(body: Center(child: Text('Unauthorized: Admins only.')));
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
            content: const Text('Are you sure you want to leave the builder? Unsaved progress will be lost.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  ref.read(draftEventProvider(orgId).notifier).reset();
                  Navigator.pop(ctx, true);
                },
                child: const Text('Leave', style: TextStyle(color: AppTheme.error)),
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
          title: Text(draftState.serverEventId != null ? 'Edit Event Draft' : 'Create Voting Event'),
        ),
        body: Stepper(
          type: MediaQuery.of(context).size.width > 600 ? StepperType.horizontal : StepperType.vertical,
          currentStep: _currentStep,
          onStepTapped: (step) {
            // Prevent skipping ahead if local state isn't saved to server yet
            if (step > 2 && draftState.serverEventId == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete earlier steps to create the draft first.')));
              return;
            }
            setState(() => _currentStep = step);
          },
          controlsBuilder: (context, details) => const SizedBox.shrink(), // Custom controls in each step
          steps: [
            Step(
              title: const Text('Basic Info'),
              content: BasicInfoStep(orgId: orgId, onNext: () => setState(() => _currentStep = 1)),
              isActive: _currentStep >= 0,
            ),
            Step(
              title: const Text('Schedule'),
              content: ScheduleStep(orgId: orgId, onNext: () => setState(() => _currentStep = 2), onBack: () => setState(() => _currentStep = 0)),
              isActive: _currentStep >= 1,
            ),
            Step(
              title: const Text('Eligibility'),
              content: EligibilityStep(orgId: orgId, onNext: () => setState(() => _currentStep = 3), onBack: () => setState(() => _currentStep = 1)),
              isActive: _currentStep >= 2,
            ),
            Step(
              title: const Text('Choices'),
              content: draftState.serverEventId == null
                  ? const Center(child: Text('Create Draft first.'))
                  : ChoicesStep(orgId: orgId, onNext: () => setState(() => _currentStep = 4), onBack: () => setState(() => _currentStep = 2)),
              isActive: _currentStep >= 3,
            ),
            Step(
              title: const Text('Review'),
              content: draftState.serverEventId == null
                  ? const Center(child: Text('Create Draft first.'))
                  : ReviewStep(orgId: orgId, onBack: () => setState(() => _currentStep = 3)),
              isActive: _currentStep >= 4,
            ),
          ],
        ),
      ),
    );
  }
}
