import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/voting_event_repository.dart';

class EventLifecycleState {
  final bool isLoading;
  final String? error;
  final String? successMessage;

  EventLifecycleState({this.isLoading = false, this.error, this.successMessage});
}

class EventLifecycleNotifier extends StateNotifier<EventLifecycleState> {
  final VotingEventRepository _repository;

  EventLifecycleNotifier(this._repository) : super(EventLifecycleState());

  Future<bool> publishEvent(String eventId) async {
    state = EventLifecycleState(isLoading: true);
    try {
      await _repository.publishVotingEvent(eventId);
      state = EventLifecycleState(successMessage: 'Voting event published successfully.');
      return true;
    } catch (e) {
      state = EventLifecycleState(error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> deleteEvent(String eventId) async {
    state = EventLifecycleState(isLoading: true);
    try {
      await _repository.deleteVotingEvent(eventId);
      state = EventLifecycleState(successMessage: 'Voting event deleted successfully.');
      return true;
    } catch (e) {
      state = EventLifecycleState(error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> cancelEvent(String eventId) async {
    state = EventLifecycleState(isLoading: true);
    try {
      await _repository.cancelVotingEvent(eventId);
      state = EventLifecycleState(successMessage: 'Voting event cancelled successfully.');
      return true;
    } catch (e) {
      state = EventLifecycleState(error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> closeEventEarly(String eventId) async {
    state = EventLifecycleState(isLoading: true);
    try {
      await _repository.closeVotingEvent(eventId);
      state = EventLifecycleState(successMessage: 'Voting event closed early.');
      return true;
    } catch (e) {
      state = EventLifecycleState(error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  void clearState() {
    state = EventLifecycleState();
  }
}

final eventLifecycleProvider = StateNotifierProvider<EventLifecycleNotifier, EventLifecycleState>((ref) {
  return EventLifecycleNotifier(ref.watch(votingEventRepositoryProvider));
});
