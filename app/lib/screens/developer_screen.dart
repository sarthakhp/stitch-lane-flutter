import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../backend/backend.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../domain/domain.dart';
import '../presentation/presentation.dart';
import '../presentation/widgets/streaming_stt_test_dialog.dart';
import 'widgets/settings/debug_logs_card.dart';

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Surfaced first because this is the data-loss safety net —
                // most important card for anyone debugging or recovering
                // from a bad state.
                const _LocalSnapshotsCard(),
                const SizedBox(height: AppConfig.spacing24),
                const DebugLogsCard(),
                const SizedBox(height: AppConfig.spacing24),
                const _AiUsageNavCard(),
                const SizedBox(height: AppConfig.spacing24),
                _AiModelsCard(),
                const SizedBox(height: AppConfig.spacing24),
                _StreamingSttTestCard(),
                const SizedBox(height: AppConfig.spacing24),
                const _AudioBackupsCard(),
                const SizedBox(height: AppConfig.spacing24),
                const _ImageIntegritySection(),
                const SizedBox(height: AppConfig.spacing24),
                const _DriveSyncStatusSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// Entry-point card on the Developer screen that opens the full AI Usage &
/// Cost dashboard. Kept on this screen (rather than in Settings) because the
/// numbers are meaningful mostly to whoever is maintaining the app.
class _AiUsageNavCard extends StatelessWidget {
  const _AiUsageNavCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.pushNamed(context, AppConstants.aiUsageRoute),
        child: Padding(
          padding: const EdgeInsets.all(AppConfig.spacing16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.insights_outlined,
                    color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: AppConfig.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'AI Usage & Cost',
                      style: tt.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tokens, audio seconds, and estimated cost by feature.',
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiModelsCard extends StatelessWidget {
  static const _chatModels = [
    'gemini-3.1-flash-lite',
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];

  static const _formattingModels = [
    'gemini-2.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];

  static const _sttModels = [
    'sarvam:saaras:v3',
    'gemini:gemini-2.5-flash-lite',
    'gemini:gemini-3.1-flash-lite',
    'gemini:gemini-2.5-flash',
    'gemini:gemini-2.0-flash',
  ];

  static const _ttsSpeakers = [
    'shubh', 'aditya', 'ritu', 'priya', 'neha', 'rahul', 'pooja',
    'rohan', 'simran', 'kavya', 'amit', 'dev', 'ishita', 'shreya',
    'ratan', 'varun', 'manan', 'sumit', 'roopa', 'kabir', 'aayan',
    'ashutosh', 'advait', 'anand', 'tanya', 'tarun', 'sunny', 'mani',
    'gokul', 'vijay', 'shruti', 'suhani', 'mohit', 'kavitha', 'rehan',
    'soham', 'rupali',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<SettingsState>(
      builder: (context, settingsState, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConfig.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.smart_toy, color: theme.colorScheme.primary),
                    const SizedBox(width: AppConfig.spacing8),
                    Text('AI Models', style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: AppConfig.spacing16),
                _buildDropdown(
                  context,
                  label: 'AI Agent LLM',
                  value: settingsState.settings.aiChatModel,
                  items: _chatModels,
                  onChanged: (value) => _updateSetting(
                    context,
                    settingsState.settings.copyWith(aiChatModel: value),
                  ),
                ),
                const SizedBox(height: AppConfig.spacing12),
                _buildDropdown(
                  context,
                  label: 'Formatting LLM',
                  value: settingsState.settings.aiFormattingModel,
                  items: _formattingModels,
                  onChanged: (value) => _updateSetting(
                    context,
                    settingsState.settings.copyWith(aiFormattingModel: value),
                  ),
                ),
                const SizedBox(height: AppConfig.spacing12),
                _buildDropdown(
                  context,
                  label: 'Voice Transcription',
                  value: settingsState.settings.sttModel,
                  items: _sttModels,
                  onChanged: (value) => _updateSetting(
                    context,
                    settingsState.settings.copyWith(sttModel: value),
                  ),
                ),
                const SizedBox(height: AppConfig.spacing12),
                _buildDropdown(
                  context,
                  label: 'TTS Speaker',
                  value: settingsState.settings.ttsSpeaker,
                  items: _ttsSpeakers,
                  onChanged: (value) => _updateSetting(
                    context,
                    settingsState.settings.copyWith(ttsSpeaker: value),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropdown(
    BuildContext context, {
    required String label,
    required String value,
    required List<String> items,
    required void Function(String) onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppConfig.spacing4),
        DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : null,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppConfig.spacing12,
              vertical: AppConfig.spacing8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          items: items
              .map((m) => DropdownMenuItem(value: m, child: Text(m, style: theme.textTheme.bodySmall)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }

  Future<void> _updateSetting(BuildContext context, AppSettings newSettings) async {
    final settingsState = context.read<SettingsState>();
    final settingsRepository = context.read<SettingsRepository>();
    await SettingsService.updateSettings(settingsState, settingsRepository, newSettings);
  }
}

class _StreamingSttTestCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stream, color: theme.colorScheme.primary),
                const SizedBox(width: AppConfig.spacing8),
                Text('Streaming STT', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppConfig.spacing12),
            Text(
              'Test real-time transcription via Sarvam WebSocket',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppConfig.spacing12),
            Wrap(
              spacing: AppConfig.spacing8,
              runSpacing: AppConfig.spacing8,
              children: [
                FilledButton.icon(
                  onPressed: () => StreamingSttTestDialog.show(context),
                  icon: const Icon(Icons.mic),
                  label: const Text('Test Streaming'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final formattingModel = context.read<SettingsState>().settings.aiFormattingModel;
                    final result = await StreamingVoiceBottomSheet.show(
                      context,
                      formattingModelName: formattingModel,
                    );
                    if (context.mounted && result != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result.audioWavPath != null
                                ? 'Got: ${result.text}\nAudio: ${result.audioWavPath}'
                                : 'Got: ${result.text}',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Bottom Sheet'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioBackupsCard extends StatefulWidget {
  const _AudioBackupsCard();

  @override
  State<_AudioBackupsCard> createState() => _AudioBackupsCardState();
}

class _AudioBackupsCardState extends State<_AudioBackupsCard> {
  bool _isRunning = false;
  CleanupResult? _lastResult;

  Future<void> _deleteNow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete orphan audio now?'),
        content: const Text(
          'Removes every audio backup file not linked to a measurement, '
          'ignoring the usual 30-day / 7-day grace periods. Files modified '
          'in the last 24 hours are still skipped to avoid hitting an '
          'active recording.\n\n'
          'Files linked to a saved measurement are never touched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRunning = true);
    final result = await AudioBackupCleanupService.runCleanup(
      orphanedWavGrace: Duration.zero,
      stalePcmGrace: Duration.zero,
    );
    if (!mounted) return;
    setState(() {
      _isRunning = false;
      _lastResult = result;
    });

    final freedMb = (result.bytesFreed / 1024 / 1024).toStringAsFixed(2);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.deleted == 0
              ? 'No orphans to delete (kept ${result.kept})'
              : 'Deleted ${result.deleted} files, freed ${freedMb}MB '
                  '(kept ${result.kept})',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.delete_sweep, color: theme.colorScheme.primary),
                const SizedBox(width: AppConfig.spacing8),
                Text('Audio Backups', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppConfig.spacing8),
            Text(
              'Voice recordings are kept on disk as a safety net. Files '
              'linked to a measurement stay forever; orphans are normally '
              'swept after 30 days. Use this to delete orphans immediately.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppConfig.spacing12),
            FilledButton.tonalIcon(
              onPressed: _isRunning ? null : _deleteNow,
              icon: _isRunning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              label: Text(_isRunning ? 'Cleaning…' : 'Delete orphans now'),
            ),
            if (_lastResult != null) ...[
              const SizedBox(height: AppConfig.spacing8),
              Text(
                'Last run: kept ${_lastResult!.kept}, '
                'deleted ${_lastResult!.deleted}, '
                'freed ${(_lastResult!.bytesFreed / 1024 / 1024).toStringAsFixed(2)}MB',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImageIntegritySection extends StatefulWidget {
  const _ImageIntegritySection();

  @override
  State<_ImageIntegritySection> createState() => _ImageIntegritySectionState();
}

class _ImageIntegritySectionState extends State<_ImageIntegritySection> {
  bool _isChecking = false;
  DateTime? _lastChecked;
  int _totalRefs = 0;
  int _missingCount = 0;
  int _orphanedCount = 0;
  List<_MissingImage> _missingImages = [];

  Future<void> _check() async {
    setState(() {
      _isChecking = true;
      _missingImages = [];
    });

    try {
      final orderRepo = context.read<OrderRepository>();
      final customerRepo = context.read<CustomerRepository>();
      final orders = await orderRepo.getAllOrders();

      int totalRefs = 0;
      final missing = <_MissingImage>[];

      for (final order in orders) {
        for (final path in order.imagePaths) {
          totalRefs++;
          final exists = await File(path).exists();
          if (!exists) {
            final customer = await customerRepo.getCustomerById(order.customerId);
            missing.add(_MissingImage(
              fileName: path.split('/').last,
              orderTitle: order.title,
              customerName: customer?.name ?? 'Unknown',
            ));
          }
        }
      }

      // Check for orphaned files (on disk but not referenced by any order)
      final allLocalPaths = await ImageStorageService.getAllImagePaths();
      final referencedFileNames = orders
          .expand((o) => o.imagePaths)
          .map((p) => p.split('/').last)
          .toSet();
      final orphaned = allLocalPaths
          .where((p) => !referencedFileNames.contains(p.split('/').last))
          .length;

      if (mounted) {
        setState(() {
          _totalRefs = totalRefs;
          _missingCount = missing.length;
          _orphanedCount = orphaned;
          _missingImages = missing;
          _lastChecked = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image_search, color: theme.colorScheme.primary),
                const SizedBox(width: AppConfig.spacing8),
                Expanded(
                  child: Text('Image Integrity', style: theme.textTheme.titleMedium),
                ),
                FilledButton.tonalIcon(
                  onPressed: _isChecking ? null : _check,
                  icon: _isChecking
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_lastChecked == null ? 'Check' : 'Refresh'),
                ),
              ],
            ),
            if (_lastChecked != null) ...[
              const SizedBox(height: AppConfig.spacing4),
              Text(
                'Last checked: ${DateFormat('h:mm a').format(_lastChecked!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppConfig.spacing12),
              if (_missingCount == 0)
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 18),
                    const SizedBox(width: AppConfig.spacing8),
                    Text(
                      'All $_totalRefs referenced images OK',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              if (_missingCount > 0) ...[
                Row(
                  children: [
                    Icon(Icons.warning_amber, color: theme.colorScheme.error, size: 18),
                    const SizedBox(width: AppConfig.spacing8),
                    Text(
                      '$_missingCount of $_totalRefs images missing',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConfig.spacing12),
                ...ListTile.divideTiles(
                  context: context,
                  tiles: _missingImages.map((m) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppConfig.spacing4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.fileName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: theme.colorScheme.error,
                          ),
                        ),
                        Text(
                          '${m.customerName}${m.orderTitle != null && m.orderTitle!.isNotEmpty ? ' — ${m.orderTitle}' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )),
                ),
              ],
              if (_orphanedCount > 0) ...[
                const SizedBox(height: AppConfig.spacing8),
                Row(
                  children: [
                    const Icon(Icons.folder_delete_outlined, color: Colors.orange, size: 18),
                    const SizedBox(width: AppConfig.spacing8),
                    Expanded(
                      child: Text(
                        '$_orphanedCount orphaned ${_orphanedCount == 1 ? 'file' : 'files'} on disk (not referenced by any order)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _MissingImage {
  final String fileName;
  final String? orderTitle;
  final String customerName;

  _MissingImage({
    required this.fileName,
    this.orderTitle,
    required this.customerName,
  });
}

class _DriveSyncStatusSection extends StatefulWidget {
  const _DriveSyncStatusSection();

  @override
  State<_DriveSyncStatusSection> createState() =>
      _DriveSyncStatusSectionState();
}

class _DriveSyncStatusSectionState extends State<_DriveSyncStatusSection> {
  bool _isChecking = false;
  DateTime? _lastChecked;
  DriveSyncCounts? _counts;
  String? _error;

  Future<void> _check() async {
    setState(() {
      _isChecking = true;
      _error = null;
    });
    try {
      final customerRepository = context.read<CustomerRepository>();
      final orderRepository = context.read<OrderRepository>();
      final measurementRepository = context.read<MeasurementRepository>();

      final counts = await DriveSyncStatusService.checkSyncStatus(
        customerRepository: customerRepository,
        orderRepository: orderRepository,
        measurementRepository: measurementRepository,
      );

      if (mounted) {
        setState(() {
          _counts = counts;
          _lastChecked = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.compare_arrows, color: theme.colorScheme.primary),
                const SizedBox(width: AppConfig.spacing8),
                Expanded(
                  child: Text(
                    'Drive Sync Status',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _isChecking ? null : _check,
                  icon: _isChecking
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_counts == null ? 'Check' : 'Refresh'),
                ),
              ],
            ),
            if (_lastChecked != null) ...[
              const SizedBox(height: AppConfig.spacing4),
              Text(
                'Last checked: ${DateFormat('h:mm a').format(_lastChecked!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppConfig.spacing12),
              _buildErrorRow(context),
            ],
            if (_counts != null) ...[
              const SizedBox(height: AppConfig.spacing16),
              _buildTable(context),
            ],
            if (_counts == null && _error == null && !_isChecking) ...[
              const SizedBox(height: AppConfig.spacing8),
              Text(
                'Compare your local data with what\'s on Google Drive.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorRow(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConfig.spacing12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
          const SizedBox(width: AppConfig.spacing8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context) {
    final theme = Theme.of(context);
    final counts = _counts!;
    return Column(
      children: [
        if (counts.isFullySynced) ...[
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
              const SizedBox(width: AppConfig.spacing8),
              Text(
                'Everything in sync',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.green, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: AppConfig.spacing12),
        ],
        Row(
          children: [
            const Expanded(child: SizedBox()),
            SizedBox(
              width: 52,
              child: Text(
                'Local',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                'Drive',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 88),
          ],
        ),
        const Divider(height: 12),
        _buildRow(context, 'Customers', counts.localCustomers, counts.driveCustomers),
        _buildRow(context, 'Orders', counts.localOrders, counts.driveOrders),
        _buildRow(context, 'Measurements', counts.localMeasurements, counts.driveMeasurements),
        _buildRow(context, 'Images', counts.localImages, counts.driveImages),
        _buildRow(context, 'Audio', counts.localAudio, counts.driveAudio),
      ],
    );
  }

  Widget _buildRow(BuildContext context, String label, int local, int drive) {
    final theme = Theme.of(context);
    final diff = local - drive;

    final Color statusColor;
    final IconData statusIcon;
    final String statusText;

    if (diff == 0) {
      statusColor = Colors.green;
      statusIcon = Icons.check;
      statusText = '✓';
    } else if (diff > 0) {
      statusColor = Colors.orange;
      statusIcon = Icons.arrow_upward;
      statusText = 'Local +$diff';
    } else {
      statusColor = theme.colorScheme.primary;
      statusIcon = Icons.arrow_downward;
      statusText = 'Drive +${-diff}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConfig.spacing4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          SizedBox(
            width: 52,
            child: Text(
              '$local',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '$drive',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(
            width: 88,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 8),
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    statusText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// Lists rotating local DB snapshots and lets you restore from one. This is
/// the data-loss safety net — surfaced first on the Developer screen.
///
/// Restore flow:
///   1. User taps Restore → confirmation dialog
///   2. App closes the live DB handle
///   3. Files from the snapshot are copied over the live DB position
///   4. App shows a "Reopen app" prompt and exits
///   5. On next launch the new files become the live DB (and a snapshot of
///      THIS state gets taken automatically before any further migration)
class _LocalSnapshotsCard extends StatefulWidget {
  const _LocalSnapshotsCard();

  @override
  State<_LocalSnapshotsCard> createState() => _LocalSnapshotsCardState();
}

class _LocalSnapshotsCardState extends State<_LocalSnapshotsCard> {
  Future<List<DbSnapshot>>? _future;
  bool _isWorking = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = DbSnapshotService.listSnapshots();
    });
  }

  Future<void> _snapshotNow() async {
    setState(() => _isWorking = true);
    final s = await DbSnapshotService.snapshotNow();
    if (!mounted) return;
    setState(() => _isWorking = false);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: Text(s == null
          ? 'Snapshot failed — see logs'
          : 'Snapshot taken'),
    ));
    _refresh();
  }

  Future<void> _restore(DbSnapshot snapshot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from snapshot?'),
        content: Text(
          'This will REPLACE the current data with the snapshot from\n\n'
          '${DateFormat('MMM d, yyyy · h:mm a').format(snapshot.takenAt)}\n\n'
          'The app will close. Reopen it to load the restored data.\n\n'
          'A fresh snapshot of the current state will be taken automatically '
          'on next launch — this restore is reversible if you act quickly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
              foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isWorking = true);

    // Close the open DB handle so the file copy doesn't fight a lock.
    await SqliteDatabase.close();
    final ok = await DbSnapshotService.restoreFromSnapshot(snapshot);

    if (!mounted) return;
    setState(() => _isWorking = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore failed — see logs')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Restored'),
        content: const Text(
          'Files restored successfully.\n\n'
          'Tap "Close app" and reopen to see the restored data.',
        ),
        actions: [
          FilledButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('Close app'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(DbSnapshot snapshot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this snapshot?'),
        content: Text(
          'The snapshot from '
          '${DateFormat('MMM d, h:mm a').format(snapshot.takenAt)} will be '
          'permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await DbSnapshotService.deleteSnapshot(snapshot);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete failed — see logs')),
      );
    }
    _refresh();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: AppConfig.spacing8),
                Expanded(
                  child: Text('Local DB snapshots',
                      style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh',
                  onPressed: _isWorking ? null : _refresh,
                ),
              ],
            ),
            const SizedBox(height: AppConfig.spacing4),
            Text(
              'Automatic snapshots of stitch_genie.db taken at app launch '
              '(throttled to one per ${DbSnapshotService.minInterval.inMinutes} min). '
              'Restore here if anything ever overwrites the live data.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppConfig.spacing12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Snapshot now'),
              onPressed: _isWorking ? null : _snapshotNow,
            ),
            const SizedBox(height: AppConfig.spacing12),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppConfig.spacing8),
                child: Row(
                  children: [
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppConfig.spacing8),
                    Text(
                      _expanded ? 'Hide snapshots' : 'Show snapshots',
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              FutureBuilder<List<DbSnapshot>>(
                future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppConfig.spacing16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final list = snap.data ?? const <DbSnapshot>[];
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppConfig.spacing16),
                    child: Text(
                      'No snapshots yet — one will be taken next launch.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppConfig.spacing8),
                      child: Text(
                        '${list.length} of ${DbSnapshotService.maxSnapshots} · '
                        'oldest: ${DateFormat('MMM d').format(list.last.takenAt)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final s in list)
                      _SnapshotRow(
                        snapshot: s,
                        isWorking: _isWorking,
                        sizeLabel: _formatSize(s.sizeBytes),
                        onRestore: () => _restore(s),
                        onDelete: () => _delete(s),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  final DbSnapshot snapshot;
  final bool isWorking;
  final String sizeLabel;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _SnapshotRow({
    required this.snapshot,
    required this.isWorking,
    required this.sizeLabel,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConfig.spacing4),
      child: Row(
        children: [
          Icon(Icons.history,
              size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppConfig.spacing8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMM d, h:mm a').format(snapshot.takenAt),
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  sizeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Delete snapshot',
            onPressed: isWorking ? null : onDelete,
          ),
          TextButton(
            onPressed: isWorking ? null : onRestore,
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}
