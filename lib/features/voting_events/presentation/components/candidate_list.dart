import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/candidate_repository.dart';
import '../../domain/candidate.dart';
import 'candidate_form_dialog.dart';

class CandidateList extends ConsumerWidget {
  final String orgId;
  final String eventId;
  final bool isDraft;

  const CandidateList({super.key, required this.orgId, required this.eventId, required this.isDraft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candsAsync = ref.watch(candidateRepositoryProvider).watchEventCandidates(eventId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isDraft)
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => CandidateFormDialog(orgId: orgId, eventId: eventId),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Candidate'),
          ),
        const SizedBox(height: 16),
        StreamBuilder<List<Candidate>>(
          stream: candsAsync,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.error));
            }
            final candidates = snapshot.data ?? [];
            if (candidates.isEmpty) return const Text('No candidates added yet.');
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: candidates.length,
              itemBuilder: (ctx, i) {
                final cand = candidates[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: cand.photoUrl != null ? NetworkImage(cand.photoUrl!) : null,
                    child: cand.photoUrl == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(cand.name),
                  subtitle: Text(cand.party.isNotEmpty ? cand.party : 'No affiliation'),
                  trailing: isDraft ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) => CandidateFormDialog(orgId: orgId, eventId: eventId, existingCandidate: cand),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: AppTheme.error),
                        onPressed: () async {
                           final confirm = await showDialog<bool>(
                             context: context,
                             builder: (c) => AlertDialog(
                               title: const Text('Delete Candidate?'),
                               content: Text('Are you sure you want to delete ${cand.name}?'),
                               actions: [
                                 TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                 TextButton(
                                   onPressed: () => Navigator.pop(c, true),
                                   child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
                                 ),
                               ],
                             )
                           );
                           if (confirm == true) {
                              try {
                                 await ref.read(candidateRepositoryProvider).deleteCandidate(cand.id);
                              } catch(e) {
                                 if(context.mounted) {
                                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ',''))));
                                 }
                              }
                           }
                        },
                      ),
                    ],
                  ) : null,
                );
              },
            );
          },
        ),
      ],
    );
  }
}
