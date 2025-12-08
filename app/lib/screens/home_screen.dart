import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stitch Lane'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppConstants.customersListRoute);
                },
                borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                child: Padding(
                  padding: const EdgeInsets.all(AppConfig.spacing24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people,
                        size: AppConfig.largeIconSize,
                        color: Theme
                            .of(context)
                            .colorScheme
                            .primary,
                      ),
                      const SizedBox(height: AppConfig.spacing16),
                      Text(
                        'Show Customers',
                        style: Theme
                            .of(context)
                            .textTheme
                            .titleLarge,
                      ),
                      const SizedBox(height: AppConfig.spacing8),
                      Text(
                        'Manage your customer list',
                        style: Theme
                            .of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          color: Theme
                              .of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConfig.spacing16),
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppConstants.allOrdersListRoute);
                },
                borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                child: Padding(
                  padding: const EdgeInsets.all(AppConfig.spacing24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.assignment,
                        size: AppConfig.largeIconSize,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: AppConfig.spacing16),
                      Text(
                        'Show Orders',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppConfig.spacing8),
                      Text(
                        'View all orders',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConfig.spacing16),
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppConstants.settingsRoute);
                },
                borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                child: Padding(
                  padding: const EdgeInsets.all(AppConfig.spacing24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.settings,
                        size: AppConfig.largeIconSize,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: AppConfig.spacing16),
                      Text(
                        'Settings',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppConfig.spacing8),
                      Text(
                        'Configure app preferences',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}