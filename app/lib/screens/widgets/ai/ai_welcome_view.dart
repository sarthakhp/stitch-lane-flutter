import 'package:flutter/material.dart';
import '../../../config/app_config.dart';

class AiWelcomeView extends StatelessWidget {
  final void Function(String) onSuggestionTap;

  const AiWelcomeView({super.key, required this.onSuggestionTap});

  static const _suggestions = [
    'How many pending orders do I have?',
    'How much did I earn this month?',
    'Which customer has the most orders?',
    'Show orders due this week',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConfig.spacing24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 48,
              color: colorScheme.primary,
            ),
            const SizedBox(height: AppConfig.spacing16),
            // Single sparkle only \u2014 the themed blue icon above. (Dropped the
            // \u2728 emoji here; it rendered as a second, off-theme yellow star.)
            Text(
              'Hi! I\'m Genie',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConfig.spacing4),
            Text(
              'Ask me anything about your business',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConfig.spacing24),
            Wrap(
              spacing: AppConfig.spacing8,
              runSpacing: AppConfig.spacing8,
              alignment: WrapAlignment.center,
              children: _suggestions.map((s) {
                return ActionChip(
                  label: Text(s),
                  onPressed: () => onSuggestionTap(s),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
