import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/voting_event_repository.dart';
import '../../domain/voting_event.dart';

class DraftEventState {
  final String title;
  final String description;
  final VotingType votingType;
  final DateTime? startAt;
  final DateTime? endAt;
  final EligibilityType eligibilityType;
  final List<String> selectedDepartmentIds;
  final List<String> selectedUserIds;
  final String? serverEventId;
  final VotingEventStatus status;
  final bool isLoading;
  final String? error;

  DraftEventState({
    this.title = '',
    this.description = '',
    this.votingType = VotingType.candidateElection,
    this.startAt,
    this.endAt,
    this.eligibilityType = EligibilityType.allMembers,
    this.selectedDepartmentIds = const [],
    this.selectedUserIds = const [],
    this.serverEventId,
    this.status = VotingEventStatus.draft,
    this.isLoading = false,
    this.error,
  });

  DraftEventState copyWith({
    String? title,
    String? description,
    VotingType? votingType,
    DateTime? startAt,
    DateTime? endAt,
    EligibilityType? eligibilityType,
    List<String>? selectedDepartmentIds,
    List<String>? selectedUserIds,
    String? serverEventId,
    VotingEventStatus? status,
    bool? isLoading,
    String? error,
  }) {
    return DraftEventState(
      title: title ?? this.title,
      description: description ?? this.description,
      votingType: votingType ?? this.votingType,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      eligibilityType: eligibilityType ?? this.eligibilityType,
      selectedDepartmentIds: selectedDepartmentIds ?? this.selectedDepartmentIds,
      selectedUserIds: selectedUserIds ?? this.selectedUserIds,
      serverEventId: serverEventId ?? this.serverEventId,
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DraftEventNotifier extends StateNotifier<DraftEventState> {
  DraftEventNotifier(this._repository, this.organizationId) : super(DraftEventState());

  final VotingEventRepository _repository;
  final String organizationId;

  void updateBasicInfo(String title, String desc, VotingType type) {
    state = state.copyWith(title: title, description: desc, votingType: type);
  }

  void updateSchedule(DateTime start, DateTime end) {
    state = state.copyWith(startAt: start, endAt: end);
  }

  void updateEligibility(EligibilityType type, List<String> depts, List<String> users) {
    state = state.copyWith(eligibilityType: type, selectedDepartmentIds: depts, selectedUserIds: users);
  }

  void loadExistingDraft(VotingEvent event) {
    state = DraftEventState(
      title: event.title,
      description: event.description,
      votingType: event.votingType,
      startAt: event.startAt,
      endAt: event.endAt,
      eligibilityType: event.eligibilityType,
      selectedDepartmentIds: event.eligibilityDepartmentIds,
      selectedUserIds: event.eligibilityUserIds,
      serverEventId: event.id,
      status: event.status,
    );
  }

  Future<bool> createServerDraft() async {
    if (state.startAt == null || state.endAt == null) {
      state = state.copyWith(error: "Schedule is incomplete.");
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final String vTypeStr = state.votingType == VotingType.candidateElection
          ? 'CANDIDATE_ELECTION'
          : state.votingType == VotingType.singleChoicePoll
              ? 'SINGLE_CHOICE_POLL'
              : 'YES_NO_POLL';

      final String eTypeStr = state.eligibilityType == EligibilityType.allMembers
          ? 'ALL_MEMBERS'
          : state.eligibilityType == EligibilityType.selectedDepartments
              ? 'SELECTED_DEPARTMENTS'
              : 'SELECTED_MEMBERS';

      final eventId = await _repository.createVotingEvent(
        organizationId: organizationId,
        title: state.title,
        description: state.description,
        votingType: vTypeStr,
        eligibilityType: eTypeStr,
        // MUST BE EXPLICIT ARRAYS! Cloud functions require arrays for SELECTED states, 
        // even if empty, but previously we sent null if empty.
        eligibilityDepartmentIds: eTypeStr == 'SELECTED_DEPARTMENTS' ? state.selectedDepartmentIds : null,
        eligibilityUserIds: eTypeStr == 'SELECTED_MEMBERS' ? state.selectedUserIds : null,
        startAt: state.startAt!,
        endAt: state.endAt!,
      );

      state = state.copyWith(serverEventId: eventId, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString().replaceAll('Exception: ', ''), isLoading: false);
      return false;
    }
  }

  void reset() {
    state = DraftEventState();
  }
}

final draftEventProvider = StateNotifierProvider.family<DraftEventNotifier, DraftEventState, String>((ref, orgId) {
  return DraftEventNotifier(ref.watch(votingEventRepositoryProvider), orgId);
});
