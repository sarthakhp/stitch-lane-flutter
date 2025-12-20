import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/domain.dart';
import '../backend/backend.dart';
import '../presentation/presentation.dart';
import '../presentation/widgets/measurement_list_item.dart';
import '../presentation/widgets/empty_measurements_state.dart';
import '../constants/app_constants.dart';

class MeasurementsListScreen extends StatefulWidget {
  final Customer customer;

  const MeasurementsListScreen({
    super.key,
    required this.customer,
  });

  @override
  State<MeasurementsListScreen> createState() => _MeasurementsListScreenState();
}

class _MeasurementsListScreenState extends State<MeasurementsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMeasurements();
    });
  }

  Future<void> _loadMeasurements() async {
    final state = context.read<MeasurementState>();
    final repository = context.read<MeasurementRepository>();
    await MeasurementService.loadMeasurementsByCustomerId(
      state,
      repository,
      widget.customer.id,
    );
  }

  Future<void> _refreshMeasurements() async {
    await _loadMeasurements();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text('${widget.customer.name} - Measurements'),
      ),
      body: Consumer<MeasurementState>(
        builder: (context, state, child) {
          if (state.isLoading && state.measurements.isEmpty) {
            return const LoadingWidget();
          }

          if (state.error != null && state.measurements.isEmpty) {
            return ErrorDisplayWidget(
              message: state.error!,
              onRetry: _refreshMeasurements,
            );
          }

          final customerMeasurements = state.measurements
              .where((m) => m.customerId == widget.customer.id)
              .toList()
            ..sort((a, b) => b.modified.compareTo(a.modified));

          if (customerMeasurements.isEmpty) {
            return const EmptyMeasurementsState();
          }

          return RefreshIndicator(
            onRefresh: _refreshMeasurements,
            child: ListView.builder(
              itemCount: customerMeasurements.length,
              itemBuilder: (context, index) {
                final measurement = customerMeasurements[index];
                return MeasurementListItem(
                  measurement: measurement,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppConstants.measurementDetailRoute,
                      arguments: {
                        'measurement': measurement,
                        'customer': widget.customer,
                      },
                    );
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(
            context,
            AppConstants.measurementFormRoute,
            arguments: {'customer': widget.customer},
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
    );
  }
}

