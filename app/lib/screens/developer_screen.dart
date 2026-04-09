import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../backend/backend.dart';
import '../config/app_config.dart';
import '../domain/domain.dart';
import '../presentation/presentation.dart';
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
                const DebugLogsCard(),
                const SizedBox(height: AppConfig.spacing24),
                _AiModelsCard(),
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

class _AiModelsCard extends StatelessWidget {
  static const _chatModels = [
    'gemini-3.1-flash-lite-preview',
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];

  static const _voiceModels = [
    'gemini-2.5-flash-lite',
    'gemini-3.1-flash-lite-preview',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
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
                  label: 'Chat Model',
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
                  label: 'Voice Model',
                  value: settingsState.settings.aiVoiceModel,
                  items: _voiceModels,
                  onChanged: (value) => _updateSetting(
                    context,
                    settingsState.settings.copyWith(aiVoiceModel: value),
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

      if (mounted) {
        setState(() {
          _totalRefs = totalRefs;
          _missingCount = missing.length;
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
                      'All $_totalRefs images OK',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              else ...[
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
