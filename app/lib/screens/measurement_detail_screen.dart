import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../backend/backend.dart';
import '../domain/domain.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../presentation/presentation.dart';
import '../presentation/widgets/confirmation_dialog.dart';
import '../presentation/widgets/audio_player_widget.dart';
import '../presentation/widgets/markdown_description_text.dart';

class MeasurementDetailScreen extends StatefulWidget {
  final Measurement measurement;
  final Customer customer;

  const MeasurementDetailScreen({
    super.key,
    required this.measurement,
    required this.customer,
  });

  @override
  State<MeasurementDetailScreen> createState() => _MeasurementDetailScreenState();
}

class _MeasurementDetailScreenState extends State<MeasurementDetailScreen> {
  late String _measurementId;

  @override
  void initState() {
    super.initState();
    _measurementId = widget.measurement.id;
  }

  String _getAudioPlayerKey() {
    if (widget.measurement.audioFilePath == null) return '';
    final file = File(widget.measurement.audioFilePath!);
    if (!file.existsSync()) return widget.measurement.audioFilePath!;
    return '${widget.measurement.audioFilePath}_${file.lastModifiedSync().millisecondsSinceEpoch}';
  }

  Future<void> _deleteMeasurement(BuildContext context, String measurementId) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete Measurement',
      content: 'Are you sure you want to delete this measurement?',
    );

    if (!confirmed || !context.mounted) return;

    final state = context.read<MeasurementState>();
    final repository = context.read<MeasurementRepository>();

    try {
      await MeasurementService.deleteMeasurement(state, repository, measurementId);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Measurement deleted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete measurement: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeasurementState>(
      builder: (context, measurementState, child) {
        final measurement = measurementState.measurements.firstWhere(
          (m) => m.id == _measurementId,
          orElse: () => widget.measurement,
        );

        return Scaffold(
          appBar: CustomAppBar(
            title: const Text('Measurement Details'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppConstants.measurementFormRoute,
                    arguments: {
                      'measurement': measurement,
                      'customer': widget.customer,
                    },
                  );
                },
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _deleteMeasurement(context, _measurementId),
                tooltip: 'Delete',
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConfig.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConfig.spacing16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.straighten,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: AppConfig.spacing16),
                            Expanded(
                              child: Text(
                                'Measurement',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppConfig.spacing16),
                        MarkdownDescriptionText(
                          text: measurement.description,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppConfig.spacing16),
                if (measurement.audioFilePath != null && File(measurement.audioFilePath!).existsSync())
                  Column(
                    children: [
                      AudioPlayerWidget(
                        key: ValueKey(_getAudioPlayerKey()),
                        audioFilePath: measurement.audioFilePath!,
                      ),
                      const SizedBox(height: AppConfig.spacing16),
                    ],
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppConfig.spacing16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.mic_off,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppConfig.spacing16),
                          Text(
                            'No audio recording',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: AppConfig.spacing16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConfig.spacing16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateRow(
                          context,
                          'Created',
                          measurement.created,
                        ),
                        const SizedBox(height: AppConfig.spacing12),
                        _buildDateRow(
                          context,
                          'Modified',
                          measurement.modified,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateRow(BuildContext context, String label, DateTime date) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        Text(
          DateFormat('MMM d, y').format(date),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

