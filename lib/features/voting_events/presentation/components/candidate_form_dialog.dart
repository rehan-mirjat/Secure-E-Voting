import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/candidate_repository.dart';
import '../../domain/candidate.dart';

class CandidateFormDialog extends ConsumerStatefulWidget {
  final String orgId;
  final String eventId;
  final Candidate? existingCandidate;

  const CandidateFormDialog({
    super.key,
    required this.orgId,
    required this.eventId,
    this.existingCandidate,
  });

  @override
  ConsumerState<CandidateFormDialog> createState() => _CandidateFormDialogState();
}

class _CandidateFormDialogState extends ConsumerState<CandidateFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _partyCtrl;
  late TextEditingController _bioCtrl;
  
  Uint8List? _selectedImageBytes;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existingCandidate?.name);
    _partyCtrl = TextEditingController(text: widget.existingCandidate?.party);
    _bioCtrl = TextEditingController(text: widget.existingCandidate?.bio);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _partyCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // FR-CAN-03: Client processes image (downscales to max 1024px width, JPEG quality 85%)
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(candidateRepositoryProvider);
      if (widget.existingCandidate == null) {
        await repo.createCandidateWithPhoto(
          organizationId: widget.orgId,
          votingEventId: widget.eventId,
          name: _nameCtrl.text.trim(),
          party: _partyCtrl.text.trim(),
          bio: _bioCtrl.text.trim(),
          photoBytes: _selectedImageBytes,
        );
      } else {
        await repo.updateCandidate(
          candidateId: widget.existingCandidate!.id,
          name: _nameCtrl.text.trim(),
          party: _partyCtrl.text.trim(),
          bio: _bioCtrl.text.trim(),
          newPhotoBytes: _selectedImageBytes,
          expectedPhotoPath: _selectedImageBytes != null 
              ? widget.existingCandidate!.photoPath ?? 'organizations/${widget.orgId}/events/${widget.eventId}/candidates/${widget.existingCandidate!.id}/photo.jpg'
              : null,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingCandidate == null ? 'Add Candidate' : 'Edit Candidate'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: _selectedImageBytes != null
                        ? MemoryImage(_selectedImageBytes!)
                        : (widget.existingCandidate?.photoUrl != null
                            ? NetworkImage(widget.existingCandidate!.photoUrl!) as ImageProvider
                            : null),
                    child: _selectedImageBytes == null && widget.existingCandidate?.photoUrl == null
                        ? const Icon(Icons.camera_alt, size: 40)
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Tap to select photo', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  validator: (v) => v == null || v.trim().length < 3 ? 'Name must be at least 3 chars' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _partyCtrl,
                  decoration: const InputDecoration(labelText: 'Party / Affiliation (Optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bioCtrl,
                  decoration: const InputDecoration(labelText: 'Biography (Optional)'),
                  maxLines: 3,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: AppTheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (!_isLoading)
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}
