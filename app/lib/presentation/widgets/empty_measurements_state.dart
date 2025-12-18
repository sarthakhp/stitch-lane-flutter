import 'package:flutter/material.dart';
import '../../config/app_config.dart';

class EmptyMeasurementsState extends StatelessWidget {
  const EmptyMeasurementsState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.straighten_outlined,
            size: AppConfig.largeIconSize * 2,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppConfig.spacing24),
          Text(
            'No measurements yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppConfig.spacing8),
          Text(
            'Tap the + button to add your first measurement',
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

