import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../organizations/presentation/providers/organization_providers.dart';
import '../../data/department_repository.dart';
import '../../domain/department.dart';

/// Streams the list of departments for the current active organization context.
/// Returns an empty list if no organization is currently selected.
final activeOrganizationDepartmentsProvider = StreamProvider<List<Department>>((ref) {
  final activeContextState = ref.watch(activeOrganizationContextProvider);
  final orgId = activeContextState.valueOrNull?.context?.organization.id;

  if (orgId == null || orgId.isEmpty) {
    return Stream.value([]);
  }

  return ref.watch(departmentRepositoryProvider).watchDepartments(orgId);
});
