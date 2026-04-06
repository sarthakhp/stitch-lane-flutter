import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../presentation/presentation.dart';
import 'widgets/settings/due_date_warning_card.dart';
import 'widgets/settings/notification_settings_card.dart';
import 'widgets/settings/account_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DueDateWarningCard(),
                SizedBox(height: AppConfig.spacing24),
                NotificationSettingsCard(),
                SizedBox(height: AppConfig.spacing24),
                AccountCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
