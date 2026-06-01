import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../responsive/breakpoints.dart';

/// Compact one-line greeting strip for the top of the home screen. Keeps the
/// personal touch (name confirms the right account is signed in) and today's
/// date, without the bulky gradient banner it replaced.
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
    final hour = DateTime.now().hour;
    final part = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return _firstName.isEmpty ? part : '$part, $_firstName';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final today = DateFormat('EEE, d MMM').format(DateTime.now());

    final greetingStyle = context.responsive<TextStyle?>(
      compact: textTheme.titleMedium,
      medium: textTheme.titleLarge,
    )?.copyWith(fontWeight: FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacing4,
        vertical: AppConfig.spacing4,
      ),
      child: Row(
        children: [
          Icon(Icons.waving_hand, size: 20, color: colorScheme.primary),
          const SizedBox(width: AppConfig.spacing8),
          Expanded(
            child: Text(
              _greeting,
              style: greetingStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppConfig.spacing8),
          Text(
            today,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
