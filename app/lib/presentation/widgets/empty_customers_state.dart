import 'package:flutter/material.dart';
import '../../config/app_config.dart';

class EmptyCustomersState extends StatelessWidget {
  const EmptyCustomersState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: AppConfig.largeIconSize * 2,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppConfig.spacing24),
          Text(
            'No customers yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppConfig.spacing8),
          Text(
            'Tap the + button to add your first customer',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

