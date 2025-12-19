import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../backend/backend.dart';
import '../domain/domain.dart';
import '../config/app_config.dart';
import '../utils/app_logger.dart';
import '../presentation/widgets/sticky_bottom_action_bar.dart';
import '../presentation/widgets/voice_recorder_button.dart';
import '../presentation/widgets/audio_player_widget.dart';
import '../presentation/widgets/transcription_progress_dialog.dart';
import '../presentation/widgets/transcription_action_dialog.dart';

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
  String? _audioFilePath;
  Completer<void>? _transcriptionCompleter;

  bool get _isEditing => widget.measurement != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _descriptionController.text = widget.measurement!.description;
      _audioFilePath = widget.measurement!.audioFilePath;
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

  String _getAudioPlayerKey() {
    if (_audioFilePath == null) return '';
    final file = File(_audioFilePath!);
    if (!file.existsSync()) return _audioFilePath!;
    return '${_audioFilePath}_${file.lastModifiedSync().millisecondsSinceEpoch}';
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_onFieldChanged);
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleRecordingComplete(String? filePath) async {
    if (filePath == null) return;

    setState(() {
      _audioFilePath = filePath;
      _hasUnsavedChanges = true;
    });

    await _transcribeAudio(filePath);
  }

  Future<void> _transcribeAudio(String audioFilePath) async {
    _transcriptionCompleter = Completer<void>();

    try {
      if (!mounted) return;

      TranscriptionProgressDialog.show(
        context,
        onCancel: () {
          _transcriptionCompleter?.complete();
          Navigator.of(context).pop();
        },
      );

      String? transcription;
      try {
        transcription = await GeminiService.transcribeAudio(audioFilePath);
      } catch (e) {
        if (!_transcriptionCompleter!.isCompleted) {
          _transcriptionCompleter!.complete();
        }
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      if (!_transcriptionCompleter!.isCompleted) {
        _transcriptionCompleter!.complete();
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      if (transcription == null || transcription.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No transcription available'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final hasExistingDescription = _descriptionController.text.trim().isNotEmpty;

      final action = await TranscriptionActionDialog.show(
        context,
        transcribedText: transcription,
        hasExistingDescription: hasExistingDescription,
      );

      if (action == null || action == TranscriptionAction.cancel) {
        return;
      }

      if (action == TranscriptionAction.replace) {
        _descriptionController.text = transcription;
      } else if (action == TranscriptionAction.append) {
        final currentText = _descriptionController.text.trim();
        _descriptionController.text = currentText.isEmpty
            ? transcription
            : '$currentText\n\n$transcription';
      }

      if (mounted) {
        setState(() {
          _hasUnsavedChanges = true;
        });
      }
    } finally {
      _transcriptionCompleter = null;
      if (mounted) {
        setState(() {});
      }
    }
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

    if (shouldPop == true) {
      await _cleanupUnsavedAudio();
    }

    return shouldPop ?? false;
  }

  Future<void> _cleanupUnsavedAudio() async {
    if (!_isEditing && _audioFilePath != null) {
      try {
        final tempPath = await AudioRecordingService.getTemporaryAudioFilePath();
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        AppLogger.warning('Failed to cleanup unsaved audio file: $e');
      }
    }
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
          audioFilePath: _audioFilePath,
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
        String? finalAudioPath = _audioFilePath;

        if (_audioFilePath != null) {
          final renamedPath = await AudioRecordingService.renameTemporaryAudio(measurementId);
          if (renamedPath != null) {
            finalAudioPath = renamedPath;
          }
        }

        final newMeasurement = Measurement(
          id: measurementId,
          customerId: widget.customer.id,
          description: _descriptionController.text.trim(),
          created: now,
          modified: now,
          audioFilePath: finalAudioPath,
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
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _descriptionController,
                    builder: (context, value, child) {
                      return TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Measurement Description',
                          hintText: 'Enter measurement details...',
                          border: const OutlineInputBorder(),
                          suffixIcon: value.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _descriptionController.clear();
                                    if (!_hasUnsavedChanges) {
                                      setState(() {
                                        _hasUnsavedChanges = true;
                                      });
                                    }
                                  },
                                  tooltip: 'Clear description',
                                )
                              : null,
                        ),
                        minLines: 3,
                        maxLines: null,
                        validator: MeasurementValidators.validateDescription,
                        textCapitalization: TextCapitalization.sentences,
                      );
                    },
                  ),
                  const SizedBox(height: AppConfig.spacing16),
                  if (_audioFilePath != null && File(_audioFilePath!).existsSync())
                    Column(
                      children: [
                        AudioPlayerWidget(
                          key: ValueKey(_getAudioPlayerKey()),
                          audioFilePath: _audioFilePath!,
                        ),
                        const SizedBox(height: AppConfig.spacing8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final shouldDelete = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Audio?'),
                                content: const Text(
                                  'Are you sure you want to delete this audio recording?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (shouldDelete == true && mounted) {
                              if (_isEditing) {
                                await AudioRecordingService.deleteRecording(widget.measurement!.id);
                              } else {
                                final tempPath = await AudioRecordingService.getTemporaryAudioFilePath();
                                final tempFile = File(tempPath);
                                if (await tempFile.exists()) {
                                  await tempFile.delete();
                                }
                              }
                              setState(() {
                                _audioFilePath = null;
                                _hasUnsavedChanges = true;
                              });
                            }
                          },
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete Audio'),
                        ),
                        const SizedBox(height: AppConfig.spacing16),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        StickyBottomActionBar(
          topWidget: VoiceRecorderButton(
            measurementId: _isEditing ? widget.measurement!.id : null,
            hasExistingRecording: _audioFilePath != null,
            onRecordingComplete: _handleRecordingComplete,
          ),
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
          saveLabel: _isEditing ? 'Update Measurement' : 'Create Measurement',
          isLoading: _isLoading,
        ),
      ],
    );
  }
}

