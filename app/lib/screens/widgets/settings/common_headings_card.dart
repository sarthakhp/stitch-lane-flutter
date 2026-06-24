import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../backend/backend.dart';
import '../../../config/app_config.dart';
import '../../../domain/domain.dart';

/// Editable chip list for common garment headings (Blouse, Pant, …). Used as
/// an AI hint and as the chip row above the measurement form. Stored on
/// [AppSettings.commonGarmentHeadings]; defaults come from
/// [DefaultMeasurementFields.defaultHeadings] when the setting is null.
class CommonHeadingsCard extends StatefulWidget {
  const CommonHeadingsCard({super.key});

  @override
  State<CommonHeadingsCard> createState() => _CommonHeadingsCardState();
}

class _CommonHeadingsCardState extends State<CommonHeadingsCard> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<String> _currentHeadings(SettingsState state) {
    final stored = state.settings.commonGarmentHeadings;
    if (stored == null) return DefaultMeasurementFields.defaultHeadings;
    return stored;
  }

  Future<void> _save(List<String> headings) async {
    final settingsState = context.read<SettingsState>();
    final repo = context.read<SettingsRepository>();
    final next = settingsState.settings.copyWith(commonGarmentHeadings: headings);
    await SettingsService.updateSettings(settingsState, repo, next);
  }

  Future<void> _addHeading() async {
    final raw = _textController.text.trim();
    if (raw.isEmpty) return;
    final current = _currentHeadings(context.read<SettingsState>());
    if (current.any((h) => h.toLowerCase() == raw.toLowerCase())) {
      _textController.clear();
      return;
    }
    final next = [...current, raw];
    _textController.clear();
    await _save(next);
    if (mounted) _focusNode.requestFocus();
  }

  Future<void> _removeHeading(String heading) async {
    final current = _currentHeadings(context.read<SettingsState>());
    final next = current.where((h) => h != heading).toList();
    await _save(next);
  }

  Future<void> _restoreDefaults() async {
    final settingsState = context.read<SettingsState>();
    final repo = context.read<SettingsRepository>();
    final next = settingsState.settings
        .copyWith(commonGarmentHeadings: DefaultMeasurementFields.defaultHeadings);
    await SettingsService.updateSettings(settingsState, repo, next);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsState>(
      builder: (context, state, _) {
        final headings = _currentHeadings(state);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConfig.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Common Garment Names',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppConfig.spacing8),
                Text(
                  'Quick-insert chips for new measurements. Also helps the AI pick '
                  'consistent garment labels (e.g. Blouse vs Top).',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppConfig.spacing16),
                if (headings.isEmpty)
                  Text(
                    'No common garments configured yet.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  Wrap(
                    spacing: AppConfig.spacing8,
                    runSpacing: AppConfig.spacing4,
                    children: [
                      for (final h in headings)
                        InputChip(
                          label: Text(h),
                          onDeleted: () => _removeHeading(h),
                        ),
                    ],
                  ),
                const SizedBox(height: AppConfig.spacing12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Add garment name',
                          hintText: 'e.g. Lehenga',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addHeading(),
                      ),
                    ),
                    const SizedBox(width: AppConfig.spacing8),
                    FilledButton.tonal(
                      onPressed: _addHeading,
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: AppConfig.spacing8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _restoreDefaults,
                    child: const Text('Restore defaults'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
