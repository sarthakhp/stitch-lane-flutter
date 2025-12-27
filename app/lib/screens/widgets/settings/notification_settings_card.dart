import 'package:flutter/material.dart';
import '../../../constants/app_constants.dart';

class NotificationSettingsCard extends StatelessWidget {
  const NotificationSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.notifications_outlined),
        title: const Text('Notification Settings'),
        subtitle: const Text('Configure reminders and alerts'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.pushNamed(
            context,
            AppConstants.notificationSettingsRoute,
          );
        },
      ),
    );
  }
}

