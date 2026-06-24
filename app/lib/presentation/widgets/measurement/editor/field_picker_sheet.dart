import 'package:flutter/material.dart';

import '../../../../backend/backend.dart';
import '../../../../config/app_config.dart';

/// Result of [FieldPickerSheet]: the chosen (or custom-typed) field label.
class FieldPickResult {
  final String label;
  const FieldPickResult(this.label);
}

/// Bottom sheet to add a measurement to a garment: search the global field
/// list (alias-aware) or type a custom label. Returns a [FieldPickResult] via
/// [Navigator.pop], or null if dismissed.
class FieldPickerSheet extends StatefulWidget {
  final List<MeasurementField> available;

  const FieldPickerSheet({super.key, required this.available});

  @override
  State<FieldPickerSheet> createState() => _FieldPickerSheetState();
}

class _FieldPickerSheetState extends State<FieldPickerSheet> {
  String _query = '';

  List<MeasurementField> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.available;
    return widget.available.where((f) {
      if (f.label.toLowerCase().contains(q)) return true;
      return f.aliases.any((a) => a.toLowerCase().contains(q));
    }).toList();
  }

  bool get _queryIsKnownLabel => widget.available
      .any((f) => f.label.toLowerCase() == _query.trim().toLowerCase());

  void _pick(String label) => Navigator.pop(context, FieldPickResult(label));

  void _onSubmitted(String raw) {
    final filtered = _filtered;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    if (filtered.isNotEmpty &&
        filtered.first.label.toLowerCase() == trimmed.toLowerCase()) {
      _pick(filtered.first.label);
    } else {
      _pick(trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConfig.spacing16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add measurement',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppConfig.spacing12),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search or type a custom label',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
                onSubmitted: _onSubmitted,
              ),
              const SizedBox(height: AppConfig.spacing8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final f = filtered[i];
                    return ListTile(
                      dense: true,
                      title: Text(f.label),
                      subtitle: f.aliases.isEmpty
                          ? null
                          : Text('also: ${f.aliases.join(", ")}'),
                      onTap: () => _pick(f.label),
                    );
                  },
                ),
              ),
              if (_query.trim().isNotEmpty && !_queryIsKnownLabel) ...[
                const Divider(),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.add),
                  title: Text('Use "${_query.trim()}" as custom label'),
                  onTap: () => _pick(_query.trim()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
