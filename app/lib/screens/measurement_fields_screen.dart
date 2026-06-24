import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../backend/backend.dart';
import '../config/app_config.dart';
import '../domain/domain.dart';
import '../presentation/presentation.dart';

/// Manage the global, flat list of measurement field labels + aliases.
/// Reorder, rename, delete, add. "Restore defaults" wipes and re-seeds the
/// built-in set.
class MeasurementFieldsScreen extends StatefulWidget {
  const MeasurementFieldsScreen({super.key});

  @override
  State<MeasurementFieldsScreen> createState() => _MeasurementFieldsScreenState();
}

class _MeasurementFieldsScreenState extends State<MeasurementFieldsScreen> {
  static const _uuid = Uuid();

  Future<void> _persist(List<MeasurementField> fields) async {
    await MeasurementFieldsService.saveAll(
      context.read<MeasurementFieldsState>(),
      context.read<MeasurementFieldRepository>(),
      fields,
    );
  }

  Future<void> _reorder(int oldIdx, int newIdx) async {
    final list = [...context.read<MeasurementFieldsState>().fields];
    if (newIdx > oldIdx) newIdx -= 1;
    final moved = list.removeAt(oldIdx);
    list.insert(newIdx, moved);
    await _persist(list);
  }

  Future<void> _delete(MeasurementField field) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete field?'),
        content: Text(
          'Remove "${field.label}" from the predefined fields list? Existing '
          'measurements will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final list = [...context.read<MeasurementFieldsState>().fields]
      ..removeWhere((f) => f.id == field.id);
    await _persist(list);
  }

  Future<void> _addOrEdit({MeasurementField? existing}) async {
    final isNew = existing == null;
    final result = await showDialog<MeasurementField>(
      context: context,
      builder: (ctx) => _FieldEditDialog(field: existing),
    );
    if (result == null || !mounted) return;
    final list = [...context.read<MeasurementFieldsState>().fields];
    if (isNew) {
      list.add(result.copyWith(id: _uuid.v4(), sortOrder: list.length));
    } else {
      final idx = list.indexWhere((f) => f.id == existing.id);
      if (idx >= 0) list[idx] = result;
    }
    await _persist(list);
  }

  Future<void> _restoreDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore defaults?'),
        content: const Text(
          'This will replace the current field list with the built-in defaults. '
          'Any custom fields you added will be removed. Existing measurements '
          'are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await MeasurementFieldsService.restoreDefaults(
      context.read<MeasurementFieldsState>(),
      context.read<MeasurementFieldRepository>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: const Text('Measurement Fields'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Restore defaults',
            onPressed: _restoreDefaults,
          ),
        ],
      ),
      body: Consumer<MeasurementFieldsState>(
        builder: (context, state, _) {
          if (state.isLoading && state.fields.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.fields.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppConfig.spacing16),
                child: Text(
                  'No fields yet. Tap + to add one, or restore defaults from '
                  'the top-right.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppConfig.spacing8),
            itemCount: state.fields.length,
            onReorder: _reorder,
            itemBuilder: (context, i) {
              final f = state.fields[i];
              return ListTile(
                key: ValueKey(f.id),
                leading: ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_handle),
                ),
                title: Text(f.label),
                subtitle: f.aliases.isEmpty
                    ? null
                    : Text('also: ${f.aliases.join(", ")}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _addOrEdit(existing: f),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(f),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _FieldEditDialog extends StatefulWidget {
  final MeasurementField? field;

  const _FieldEditDialog({this.field});

  @override
  State<_FieldEditDialog> createState() => _FieldEditDialogState();
}

class _FieldEditDialogState extends State<_FieldEditDialog> {
  late final TextEditingController _label;
  late List<String> _aliases;
  final _aliasInput = TextEditingController();

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.field?.label ?? '');
    _aliases = [...?widget.field?.aliases];
  }

  @override
  void dispose() {
    _label.dispose();
    _aliasInput.dispose();
    super.dispose();
  }

  void _addAlias() {
    final raw = _aliasInput.text.trim();
    if (raw.isEmpty) return;
    if (_aliases.any((a) => a.toLowerCase() == raw.toLowerCase())) {
      _aliasInput.clear();
      return;
    }
    setState(() {
      _aliases = [..._aliases, raw];
      _aliasInput.clear();
    });
  }

  void _removeAlias(String alias) {
    setState(() => _aliases = _aliases.where((a) => a != alias).toList());
  }

  void _save() {
    final label = _label.text.trim();
    if (label.isEmpty) return;
    final result = (widget.field ?? MeasurementField(id: '', label: '', sortOrder: 0))
        .copyWith(label: label, aliases: _aliases);
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.field == null ? 'Add field' : 'Edit field'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _label,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'e.g. Full Bust',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppConfig.spacing16),
            const Text('Aliases', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppConfig.spacing4),
            const Text(
              'Other spellings the AI should match to this field '
              '(e.g. "મોરી", "Cuff").',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: AppConfig.spacing8),
            if (_aliases.isNotEmpty)
              Wrap(
                spacing: AppConfig.spacing8,
                runSpacing: AppConfig.spacing4,
                children: [
                  for (final a in _aliases)
                    InputChip(
                      label: Text(a),
                      onDeleted: () => _removeAlias(a),
                    ),
                ],
              ),
            const SizedBox(height: AppConfig.spacing8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _aliasInput,
                    decoration: const InputDecoration(
                      hintText: 'Add alias',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addAlias(),
                  ),
                ),
                const SizedBox(width: AppConfig.spacing8),
                FilledButton.tonal(
                  onPressed: _addAlias,
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
