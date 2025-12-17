import 'package:flutter/material.dart';
import '../../config/app_config.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.content_cut,
          size: 80,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppConfig.spacing24),
        Text(
          'Stitch Lane',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: AppConfig.spacing16),
        Text(
          'Manage your tailoring business',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

