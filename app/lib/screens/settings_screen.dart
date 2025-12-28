import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../domain/domain.dart';
import '../presentation/presentation.dart';
import 'widgets/settings/due_date_warning_card.dart';
import 'widgets/settings/notification_settings_card.dart';
import 'widgets/settings/backup_restore_card.dart';
import 'widgets/settings/auto_backup_settings_card.dart';
import 'widgets/settings/account_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBackupInfo();
    });
  }

  Future<void> _loadBackupInfo() async {
    final backupState = context.read<BackupState>();
    try {
      final backupInfo = await DriveService.getBackupInfo();
      backupState.setBackupInfo(backupInfo);
    } catch (e) {
      backupState.setBackupInfo(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: CustomAppBar(
        title: Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DueDateWarningCard(),
            SizedBox(height: AppConfig.spacing24),
            NotificationSettingsCard(),
            SizedBox(height: AppConfig.spacing24),
            BackupRestoreCard(),
            SizedBox(height: AppConfig.spacing24),
            AutoBackupSettingsCard(),
            SizedBox(height: AppConfig.spacing24),
            AccountCard(),
          ],
        ),
      ),
    );
  }
}

