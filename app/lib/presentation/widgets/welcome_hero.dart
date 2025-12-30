import 'package:flutter/material.dart';
import '../../config/app_config.dart';

class WelcomeHero extends StatelessWidget {
  final String? userName;

  const WelcomeHero({
    super.key,
    this.userName,
  });

  String get _firstName {
    if (userName == null || userName!.isEmpty) return '';
    return userName!.split(' ').first;
  }

  String get _greeting {
    if (_firstName.isEmpty) return 'Welcome back!';
    return 'Welcome back, $_firstName!';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppConfig.spacing24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppConfig.spacing8),
                Text(
                  "Here's your business overview",
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.waving_hand,
            size: 40,
            color: colorScheme.onPrimary.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }
}

