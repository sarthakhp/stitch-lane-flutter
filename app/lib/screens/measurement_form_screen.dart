import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/backend.dart';
import '../domain/domain.dart';
import '../domain/services/measurement_structurer.dart';
import '../domain/services/measurement_extractor.dart';
import '../domain/services/measurement_save_service.dart';
import '../config/app_config.dart';
import '../presentation/presentation.dart';
import '../presentation/widgets/sticky_bottom_action_bar.dart';
import '../presentation/widgets/measurement/structured_measurement_editor.dart';
import '../presentation/widgets/measurement/form/customer_summary_card.dart';
import '../presentation/widgets/measurement/form/legacy_import_banner.dart';
import '../presentation/widgets/measurement/form/dictate_button.dart';
import '../presentation/widgets/audio/recordings_card.dart';

/// Structured-only measurement editor.
///
/// Dictation is turned into structure by the AI ([MeasurementExtractor]);
/// manual entry uses the field rows; free remarks live in each section's
/// Notes. The markdown `description` is *derived* from the structure on save
/// ([MeasurementSaveService]) — it's no longer hand-authored.
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
  bool _isLoading = false; // saving
  bool _isExtracting = false; // turning a dictation into structure
  bool _hasUnsavedChanges = false;

  /// Single source of truth: sections + per-field values + notes.
  StructuredMeasurement _structured = StructuredMeasurement.empty();

  /// Shown once when an old (markdown-only) measurement was imported to Notes.
  bool _legacyImported = false;

  List<MeasurementField> _fieldsSnapshot = const [];

  // Linked recordings; each dictation appends (multiple kept). The "new" list
  // is the subset captured this session that needs a sidecar at save.
  List<String> _audioFilePaths = [];
  final List<String> _newAudioFilePaths = [];

  bool get _isEditing => widget.measurement != null;
  bool get _isBusy => _isLoading || _isExtracting;

  @override
  void initState() {
    super.initState();
    _fieldsSnapshot = context.read<MeasurementFieldsState>().fields;

    if (_isEditing) {
      _audioFilePaths = [...widget.measurement!.audioFilePaths];
      final stored = widget.measurement!.structuredData;
      if (stored != null) {
        _structured = StructuredMeasurement.fromJson(stored);
      } else {
        // Legacy (markdown-only): keep its text verbatim in a Notes section —
        // no lossy parsing. The user can re-key into fields.
        _structured =
            MeasurementStructurer.fromLegacyText(widget.measurement!.description);
        _legacyImported = !_structured.isEmpty;
      }
    }
  }

  List<String> get _headings =>
      context.read<SettingsState>().settings.commonGarmentHeadings ??
      DefaultMeasurementFields.defaultHeadings;

  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedChanges || _isBusy) return true;
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
            'You have unsaved changes. Do you want to discard them?'),
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

  void _markDirty() {
    if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
  }

  void _onStructuredChanged(StructuredMeasurement next) {
    setState(() => _structured = next);
    _markDirty();
  }

  /// Append a freshly-captured recording (de-duped); tracked as new-this-session
  /// so save writes its sidecar.
  void _addAudio(String? path) {
    if (path == null || path.trim().isEmpty) return;
    if (_audioFilePaths.contains(path)) return;
    setState(() => _audioFilePaths.add(path));
    _newAudioFilePaths.add(path);
    _markDirty();
  }

  /// Capture a raw transcript, turn it into structured sections via the AI,
  /// and merge into the form. If the AI can't structure it, the raw transcript
  /// is kept in a Notes section so words are never lost. Audio is saved either
  /// way.
  Future<void> _runVoice() async {
    final result = await StreamingVoiceBottomSheet.show(context);
    if (result == null || result.text.trim().isEmpty || !mounted) return;

    _addAudio(result.audioWavPath);

    setState(() => _isExtracting = true);
    StructuredMeasurement? extracted;
    var failed = false;
    try {
      extracted = await MeasurementExtractor.extract(
        result.text,
        fields: _fieldsSnapshot,
        headings: _headings,
        modelName: context.read<SettingsState>().settings.aiFormattingModel,
      );
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() => _isExtracting = false);

    final incoming = extracted ?? _rawTranscriptFallback(result.text);
    setState(() => _structured =
        MeasurementStructurer.mergeSections(_structured, incoming));
    _markDirty();

    if ((failed || extracted == null) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Couldn't auto-organize that — added your dictation to Notes."),
        ),
      );
    }
  }

  /// Preserve a dictation we couldn't structure as a single notes section.
  StructuredMeasurement _rawTranscriptFallback(String transcript) =>
      StructuredMeasurement(sections: [
        MeasurementSection(heading: '', values: const {}, notes: transcript.trim()),
      ]);

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await MeasurementSaveService.save(
        state: context.read<MeasurementState>(),
        repository: context.read<MeasurementRepository>(),
        customer: widget.customer,
        existing: widget.measurement,
        structured: _structured,
        audioFilePaths: _audioFilePaths,
        newAudioFilePaths: _newAudioFilePaths,
        now: DateTime.now(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Measurement updated successfully'
                : 'Measurement created successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save measurement: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the field snapshot fresh (newly-added fields/aliases take effect).
    _fieldsSnapshot = context.watch<MeasurementFieldsState>().fields;

    return PopScope(
      canPop: !_hasUnsavedChanges || _isBusy,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.pop(context);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomerSummaryCard(name: widget.customer.name),
                const SizedBox(height: AppConfig.spacing16),
                if (_legacyImported) ...[
                  const LegacyImportBanner(),
                  const SizedBox(height: AppConfig.spacing12),
                ],
                StructuredMeasurementEditor(
                  value: _structured,
                  enabled: !_isBusy,
                  onChanged: _onStructuredChanged,
                ),
                const SizedBox(height: AppConfig.spacing12),
                DictateButton(
                  enabled: !_isBusy,
                  busy: _isExtracting,
                  onTap: _runVoice,
                ),
                // Hear what was dictated — this session's and earlier recordings.
                if (_audioFilePaths.isNotEmpty) ...[
                  const SizedBox(height: AppConfig.spacing16),
                  RecordingsCard(filePaths: _audioFilePaths),
                ],
              ],
            ),
          ),
        ),
        StickyBottomActionBar(
          onCancel: () async {
            if (_hasUnsavedChanges) {
              final navigator = Navigator.of(context);
              if (await _confirmDiscard()) navigator.pop();
            } else {
              Navigator.pop(context);
            }
          },
          onSave: _save,
          saveLabel: _isEditing ? 'Update' : 'Create',
          isLoading: _isLoading,
        ),
      ],
    );
  }
}
