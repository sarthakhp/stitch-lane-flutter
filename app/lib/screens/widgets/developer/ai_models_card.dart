import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../backend/backend.dart';
import '../../../config/app_config.dart';
import '../../../domain/domain.dart';

/// Developer-only model pickers: chat LLM, formatting LLM, STT model and TTS
/// speaker. Persists choices straight to [SettingsState] via [SettingsService].
class AiModelsCard extends StatelessWidget {
  const AiModelsCard({super.key});

  static const _chatModels = [
    'gemini-3.1-flash-lite',
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];

  static const _formattingModels = [
    'gemini-2.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];

  static const _sttModels = [
    'sarvam:saaras:v3',
    'gemini:gemini-2.5-flash-lite',
    'gemini:gemini-3.1-flash-lite',
    'gemini:gemini-2.5-flash',
    'gemini:gemini-2.0-flash',
  ];

  static const _ttsSpeakers = [
    'shubh', 'aditya', 'ritu', 'priya', 'neha', 'rahul', 'pooja',
    'rohan', 'simran', 'kavya', 'amit', 'dev', 'ishita', 'shreya',
    'ratan', 'varun', 'manan', 'sumit', 'roopa', 'kabir', 'aayan',
    'ashutosh', 'advait', 'anand', 'tanya', 'tarun', 'sunny', 'mani',
    'gokul', 'vijay', 'shruti', 'suhani', 'mohit', 'kavitha', 'rehan',
    'soham', 'rupali',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<SettingsState>(
      builder: (context, settingsState, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConfig.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.smart_toy, color: theme.colorScheme.primary),
                    const SizedBox(width: AppConfig.spacing8),
                    Text('AI Models', style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: AppConfig.spacing16),
                _buildDropdown(
                  context,
                  label: 'AI Agent LLM',
                  value: settingsState.settings.aiChatModel,
                  items: _chatModels,
                  onChanged: (value) => _updateSetting(
                    context,
                    settingsState.settings.copyWith(aiChatModel: value),
                  ),
                ),
                const SizedBox(height: AppConfig.spacing12),
                _buildDropdown(
                  context,
                  label: 'Formatting LLM',
                  value: settingsState.settings.aiFormattingModel,
                  items: _formattingModels,
                  onChanged: (value) => _updateSetting(
                    context,
                    settingsState.settings.copyWith(aiFormattingModel: value),
                  ),
                ),
                const SizedBox(height: AppConfig.spacing12),
                _buildDropdown(
                  context,
                  label: 'Voice Transcription',
                  value: settingsState.settings.sttModel,
                  items: _sttModels,
                  onChanged: (value) => _updateSetting(
                    context,
                    settingsState.settings.copyWith(sttModel: value),
                  ),
                ),
                const SizedBox(height: AppConfig.spacing12),
                _buildDropdown(
                  context,
                  label: 'TTS Speaker',
                  value: settingsState.settings.ttsSpeaker,
                  items: _ttsSpeakers,
                  onChanged: (value) => _updateSetting(
                    context,
                    settingsState.settings.copyWith(ttsSpeaker: value),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropdown(
    BuildContext context, {
    required String label,
    required String value,
    required List<String> items,
    required void Function(String) onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppConfig.spacing4),
        DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : null,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppConfig.spacing12,
              vertical: AppConfig.spacing8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          items: items
              .map((m) => DropdownMenuItem(value: m, child: Text(m, style: theme.textTheme.bodySmall)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }

  Future<void> _updateSetting(BuildContext context, AppSettings newSettings) async {
    final settingsState = context.read<SettingsState>();
    final settingsRepository = context.read<SettingsRepository>();
    await SettingsService.updateSettings(settingsState, settingsRepository, newSettings);
  }
}
