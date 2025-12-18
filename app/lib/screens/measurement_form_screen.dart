import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../backend/backend.dart';
import '../domain/domain.dart';
import '../config/app_config.dart';
import '../presentation/widgets/sticky_bottom_action_bar.dart';

class MeasurementFormScreen extends StatefulWidget {
  final Measurement? measurement;
  final Customer customer;

  const MeasurementFormScreen({
    super.key,
    this.measurement,
    required this.customer,
  });

  @override
  State<MeasurementFormScreen> createState() => _MeasurementFormScreenState();
}

class _MeasurementFormScreenState extends State<MeasurementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  bool _hasAttemptedSubmit = false;
  bool _hasUnsavedChanges = false;

  bool get _isEditing => widget.measurement != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _descriptionController.text = widget.measurement!.description;
    }
    _descriptionController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_onFieldChanged);
    _descriptionController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges || _isLoading) {
      return true;
    }

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Do you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  Future<void> _saveMeasurement() async {
    setState(() {
      _hasAttemptedSubmit = true;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final state = context.read<MeasurementState>();
    final repository = context.read<MeasurementRepository>();
    final now = DateTime.now();

    try {
      if (_isEditing) {
        final updatedMeasurement = widget.measurement!.copyWith(
          description: _descriptionController.text.trim(),
          modified: now,
        );
        await MeasurementService.updateMeasurement(state, repository, updatedMeasurement);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Measurement updated successfully')),
          );
        }
      } else {
        final newMeasurement = Measurement(
          id: const Uuid().v4(),
          customerId: widget.customer.id,
          description: _descriptionController.text.trim(),
          created: now,
          modified: now,
        );
        await MeasurementService.addMeasurement(state, repository, newMeasurement);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Measurement created successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save measurement: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges || _isLoading,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Measurement' : 'New Measurement'),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConfig.spacing16),
            child: Form(
              key: _formKey,
              autovalidateMode: _hasAttemptedSubmit
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppConfig.spacing16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: AppConfig.spacing8),
                          Text(
                            widget.customer.name,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConfig.spacing16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Measurement Description',
                      hintText: 'Enter measurement details...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 10,
                    validator: MeasurementValidators.validateDescription,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
            ),
          ),
        ),
        StickyBottomActionBar(
          onCancel: () => Navigator.pop(context),
          onSave: _saveMeasurement,
          saveLabel: _isEditing ? 'Update Measurement' : 'Create Measurement',
          isLoading: _isLoading,
        ),
      ],
    );
  }
}

