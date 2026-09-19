import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/poll_option_repository.dart';
import '../../domain/poll_option.dart';
import 'poll_option_form_dialog.dart';

class PollOptionList extends ConsumerWidget {
  final String orgId;
  final String eventId;
  final bool isDraft;

  const PollOptionList({super.key, required this.orgId, required this.eventId, required this.isDraft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optsAsync = ref.watch(pollOptionRepositoryProvider).watchEventPollOptions(eventId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isDraft)
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => PollOptionFormDialog(orgId: orgId, eventId: eventId),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Option'),
          ),
        const SizedBox(height: 16),
        StreamBuilder<List<PollOption>>(
          stream: optsAsync,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.error));
            }
            final options = snapshot.data ?? [];
            if (options.isEmpty) return const Text('No options added yet.');
            return ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              onReorderItem: isDraft ? (oldIndex, newIndex) async {
                 final item = options.removeAt(oldIndex);
                 options.insert(newIndex, item);
                 
                 // Update sort order in backend for affected items
                 final repo = ref.read(pollOptionRepositoryProvider);
                 for (int i = 0; i < options.length; i++) {
                    if (options[i].sortOrder != i) {
                       await repo.updatePollOption(optionId: options[i].id, sortOrder: i);
                    }
                 }
              } : (o,n) {},
              itemBuilder: (ctx, i) {
                final opt = options[i];
                return ListTile(
                  key: ValueKey(opt.id),
                  leading: const Icon(Icons.drag_handle),
                  title: Text(opt.label),
                  subtitle: opt.description.isNotEmpty ? Text(opt.description) : null,
                  trailing: isDraft ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) => PollOptionFormDialog(orgId: orgId, eventId: eventId, existingOption: opt),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: AppTheme.error),
                        onPressed: () async {
                           final confirm = await showDialog<bool>(
                             context: context,
                             builder: (c) => AlertDialog(
                               title: const Text('Delete Option?'),
                               content: Text('Are you sure you want to delete ${opt.label}?'),
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
                                 await ref.read(pollOptionRepositoryProvider).deletePollOption(opt.id);
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
