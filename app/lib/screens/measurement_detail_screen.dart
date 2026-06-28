import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../backend/backend.dart';
import '../domain/domain.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../presentation/presentation.dart';
import '../presentation/widgets/confirmation_dialog.dart';
import '../presentation/widgets/audio/recordings_card.dart';
import '../presentation/widgets/markdown_description_text.dart';
import '../presentation/widgets/measurement/structured_measurement_view.dart';
import '../domain/services/measurement_structurer.dart';
import '../presentation/widgets/sync/writer_only.dart';

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
              WriterOnly(
                child: IconButton(
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
              ),
              WriterOnly(
                child: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteMeasurement(context, _measurementId),
                  tooltip: 'Delete',
                ),
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
                        _buildMeasurementBody(measurement),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppConfig.spacing16),
                RecordingsCard(
                  filePaths: measurement.audioFilePaths,
                  emptyLabel: 'No audio recording',
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

  /// Prefer the structured view when the measurement carries structured data
  /// (everything created since the predefined-fields feature). Older
  /// measurements have only the markdown [description] and keep rendering
  /// through [MarkdownDescriptionText].
  Widget _buildMeasurementBody(Measurement measurement) {
    final structuredData = measurement.structuredData;
    if (structuredData != null) {
      final structured = StructuredMeasurement.fromJson(structuredData);
      if (!structured.isEmpty) {
        return StructuredMeasurementView(data: structured);
      }
    }
    return MarkdownDescriptionText(text: measurement.description);
  }

  Widget _buildDateRow(BuildContext context, String label, DateTime date) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(width: AppConfig.spacing8),
        Flexible(
          child: Text(
            DateFormat('MMM d, y').format(date),
            style: Theme.of(context).textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

