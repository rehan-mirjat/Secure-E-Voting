import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../data/department_repository.dart';
import '../domain/department.dart';

class CreateEditDepartmentDialog extends ConsumerStatefulWidget {
  const CreateEditDepartmentDialog({
    super.key,
    required this.organizationId,
    this.departmentToEdit,
  });

  final String organizationId;
  final Department? departmentToEdit;

  @override
  ConsumerState<CreateEditDepartmentDialog> createState() => _CreateEditDepartmentDialogState();
}

class _CreateEditDepartmentDialogState extends ConsumerState<CreateEditDepartmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.departmentToEdit?.name ?? '');
    _descController = TextEditingController(text: widget.departmentToEdit?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(departmentRepositoryProvider);
      
      if (widget.departmentToEdit == null) {
        await repo.createDepartment(
          organizationId: widget.organizationId,
          name: _nameController.text,
          description: _descController.text,
        );
      } else {
        await repo.updateDepartment(
          departmentId: widget.departmentToEdit!.id,
          name: _nameController.text,
          description: _descController.text,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.departmentToEdit == null ? 'Department created successfully.' : 'Department updated successfully.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
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
    final isEditing = widget.departmentToEdit != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Department' : 'Create Department'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Department Name *',
                    hintText: 'e.g. Computer Science',
                  ),
                  validator: (v) {
                    final req = Validators.required(v, 'Department Name');
                    if (req != null) return req;
                    if (v!.trim().length < 2) return 'Name must be at least 2 characters';
                    if (v.trim().length > 50) return 'Name cannot exceed 50 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Brief summary of the department...',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}
