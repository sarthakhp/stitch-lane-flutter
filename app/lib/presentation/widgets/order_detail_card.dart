import 'package:flutter/material.dart';
import '../../config/app_config.dart';

class OrderDetailCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? child;

  const OrderDetailCard({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.child,
  }) : assert(value != null || child != null, 'Either value or child must be provided');

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppConfig.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppConfig.spacing8),
                  if (child != null)
                    child!
                  else
                    Text(
                      value!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

