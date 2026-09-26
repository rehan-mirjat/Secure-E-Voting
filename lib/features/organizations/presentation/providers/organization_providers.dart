import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../services/auth_service.dart';
import '../../data/organization_repository.dart';
import '../../domain/active_organization_context.dart';
import '../../domain/organization.dart';
import '../../domain/organization_member.dart';

/// Streams the list of active organization memberships for the current user.
final userMembershipsProvider = StreamProvider<List<OrganizationMember>>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    return Stream.value([]);
  }
  return ref.watch(organizationRepositoryProvider).watchUserMemberships(user.uid);
});

/// Refreshes recipient invitations while the signed-in app is open.
final memberInvitationsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    yield [];
    return;
  }

  final repository = ref.watch(organizationRepositoryProvider);
  yield await repository.getMyInvitations();
  await for (final _ in Stream<int>.periodic(const Duration(seconds: 45))) {
    yield await repository.getMyInvitations();
  }
});

/// Streams the full list of [Organization] documents corresponding to active memberships.
/// Parallelizes organization document fetching for high-speed loading.
final userOrganizationsProvider = StreamProvider<List<Organization>>((ref) async* {
  final membershipsAsync = ref.watch(userMembershipsProvider);
  final repo = ref.watch(organizationRepositoryProvider);
  final memberships = membershipsAsync.valueOrNull ?? [];

  if (memberships.isEmpty) {
    yield [];
    return;
  }

  final orgIds = memberships.map((m) => m.organizationId).toSet().toList();

  // Parallelize fetches in 1 round trip instead of a sequential loop
  final results = await Future.wait(orgIds.map((id) => repo.getOrganization(id)));
  final orgs = results.whereType<Organization>().where((org) => org.isSelectable).toList();

  yield orgs;
});

/// Manages the user-specific selected organization ID string and local storage.
class ActiveOrgIdNotifier extends StateNotifier<String?> {
  ActiveOrgIdNotifier(this._ref) : super(null) {
    // Re-evaluate saved ID whenever auth state changes (e.g., login/logout)
    _ref.listen(authStateChangesProvider, (previous, next) {
      if (next.value != null) {
        _loadSavedOrgId();
      } else {
        state = null; // Clear on logout
        _ref.read(organizationRepositoryProvider).clearCache();
      }
    });
    _loadSavedOrgId();
  }

  final Ref _ref;

  Future<void> _loadSavedOrgId() async {
    final user = _ref.read(authStateChangesProvider).value;
    if (user == null) {
      state = null;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = 'securevote_active_org_id_${user.uid}';
    state = prefs.getString(key);
  }

  Future<void> selectOrganization(String orgId) async {
    final user = _ref.read(authStateChangesProvider).value;
    if (user == null) return;

    state = orgId;
    final prefs = await SharedPreferences.getInstance();
    final key = 'securevote_active_org_id_${user.uid}';
    await prefs.setString(key, orgId);
  }

  Future<void> clearSelection() async {
    final user = _ref.read(authStateChangesProvider).value;
    state = null;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('securevote_active_org_id_${user.uid}');
    }
  }
}

final activeOrgIdProvider = StateNotifierProvider<ActiveOrgIdNotifier, String?>((ref) {
  return ActiveOrgIdNotifier(ref);
});

enum ActiveOrgSelectionState {
  restored,
  autoSelected,
  needsSelection,
  noOrganizations,
}

class ActiveOrgState {
  final ActiveOrganizationContext? context;
  final ActiveOrgSelectionState selectionState;
  final List<OrganizationMember> availableMemberships;

  const ActiveOrgState({
    this.context,
    required this.selectionState,
    required this.availableMemberships,
  });
}

/// Asynchronously resolves the ActiveOrganizationContext based on user-specific persistence
/// and strict validation against current active memberships.
final activeOrganizationContextProvider = StreamProvider<ActiveOrgState>((ref) async* {
  final membershipsAsync = ref.watch(userMembershipsProvider);
  final selectedOrgId = ref.watch(activeOrgIdProvider);
  final repo = ref.watch(organizationRepositoryProvider);

  final memberships = membershipsAsync.valueOrNull ?? [];

  if (memberships.isEmpty) {
    yield const ActiveOrgState(
      context: null,
      selectionState: ActiveOrgSelectionState.noOrganizations,
      availableMemberships: [],
    );
    return;
  }

  // 1. Try to restore saved organization preference ONLY IF user holds an active membership
  if (selectedOrgId != null && selectedOrgId.isNotEmpty) {
    final matchingMember = memberships.where((m) => m.organizationId == selectedOrgId).firstOrNull;
    if (matchingMember != null) {
      final org = await repo.getOrganization(selectedOrgId);
      if (org != null && org.isSelectable) {
        yield ActiveOrgState(
          context: ActiveOrganizationContext(organization: org, member: matchingMember),
          selectionState: ActiveOrgSelectionState.restored,
          availableMemberships: memberships,
        );
        return;
      }
    }
  }

  // 2. Deterministic Fallback Rules
  if (memberships.length == 1) {
    // Single active membership -> Auto-select
    final singleMember = memberships.first;
    final org = await repo.getOrganization(singleMember.organizationId);
    if (org != null && org.isSelectable) {
      yield ActiveOrgState(
        context: ActiveOrganizationContext(organization: org, member: singleMember),
        selectionState: ActiveOrgSelectionState.autoSelected,
        availableMemberships: memberships,
      );
      return;
    }
  }

  // 3. Multiple memberships available but none validly selected -> Require selection
  yield ActiveOrgState(
    context: null,
    selectionState: ActiveOrgSelectionState.needsSelection,
    availableMemberships: memberships,
  );
});
