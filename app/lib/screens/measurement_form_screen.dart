import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../backend/backend.dart';
import '../domain/domain.dart';
import '../config/app_config.dart';
import '../presentation/presentation.dart';
import '../presentation/widgets/sticky_bottom_action_bar.dart';
import '../presentation/widgets/rich_description_input_field.dart';

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
  final _descriptionKey = GlobalKey<RichDescriptionInputFieldState>();
  bool _isLoading = false;
  bool _hasAttemptedSubmit = false;
  bool _hasUnsavedChanges = false;
  String _descriptionValue = '';

  bool get _isEditing => widget.measurement != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _descriptionValue = widget.measurement!.description;
    }
  }

  @override
  void dispose() {
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
          description: _descriptionValue.trim(),
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
        final measurementId = const Uuid().v4();

        final newMeasurement = Measurement(
          id: measurementId,
          customerId: widget.customer.id,
          description: _descriptionValue.trim(),
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
        appBar: CustomAppBar(
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
                  RichDescriptionInputField(
                    key: _descriptionKey,
                    initialValue: _descriptionValue,
                    labelText: 'Measurement Description',
                    hintText: 'Enter measurement details...',
                    onChanged: (value) {
                      _descriptionValue = value;
                      if (!_hasUnsavedChanges) {
                        setState(() {
                          _hasUnsavedChanges = true;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        StickyBottomActionBar(
          onCancel: () async {
            if (_hasUnsavedChanges) {
              final navigator = Navigator.of(context);
              final shouldPop = await _onWillPop();
              if (shouldPop) {
                navigator.pop();
              }
            } else {
              Navigator.pop(context);
            }
          },
          onSave: _saveMeasurement,
          saveLabel: _isEditing ? 'Update' : 'Create',
          isLoading: _isLoading,
        ),
      ],
    );
  }
}

