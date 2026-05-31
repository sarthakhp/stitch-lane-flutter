import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../responsive/breakpoints.dart';

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
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());

    final verticalPad = context.responsive<double>(
      compact: AppConfig.spacing24,
      medium: AppConfig.spacing24,
      expanded: AppConfig.spacing16,
    );
    final greetingStyle = context.responsive<TextStyle?>(
      compact: textTheme.headlineSmall,
      medium: textTheme.headlineMedium,
    )?.copyWith(
      color: colorScheme.onPrimary,
      fontWeight: FontWeight.bold,
    );
    final iconSize = context.responsive<double>(compact: 40, medium: 52);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppConfig.spacing24,
        vertical: verticalPad,
      ),
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
                Text(_greeting, style: greetingStyle),
                const SizedBox(height: AppConfig.spacing8),
                Text(
                  today,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.waving_hand,
            size: iconSize,
            color: colorScheme.onPrimary.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }
}
