import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../presentation/presentation.dart';
import 'widgets/settings/debug_logs_card.dart';
import 'widgets/developer/ai_models_card.dart';
import 'widgets/developer/ai_usage_nav_card.dart';
import 'widgets/developer/audio_backups_card.dart';
import 'widgets/developer/drive_sync_status_section.dart';
import 'widgets/developer/image_integrity_section.dart';
import 'widgets/developer/local_snapshots_card.dart';
import 'widgets/developer/streaming_stt_test_card.dart';

/// Developer tools, composed from focused per-section cards under
/// `widgets/developer/`. Keep this file a thin composition shell — add new
/// tools as their own card widget rather than growing this screen.
class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: Text('Developer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Surfaced first because this is the data-loss safety net —
                // most important card for anyone debugging or recovering
                // from a bad state.
                LocalSnapshotsCard(),
                SizedBox(height: AppConfig.spacing24),
                DebugLogsCard(),
                SizedBox(height: AppConfig.spacing24),
                AiUsageNavCard(),
                SizedBox(height: AppConfig.spacing24),
                AiModelsCard(),
                SizedBox(height: AppConfig.spacing24),
                StreamingSttTestCard(),
                SizedBox(height: AppConfig.spacing24),
                AudioBackupsCard(),
                SizedBox(height: AppConfig.spacing24),
                ImageIntegritySection(),
                SizedBox(height: AppConfig.spacing24),
                DriveSyncStatusSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
