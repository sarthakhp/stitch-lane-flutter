import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../backend/backend.dart';
import '../config/app_config.dart';
import '../domain/domain.dart';
import '../domain/services/recordings/customer_recordings_service.dart';
import '../domain/services/recordings/entity_recording.dart';
import '../presentation/presentation.dart';
import '../presentation/widgets/audio/recording_list_tile.dart';
import '../presentation/widgets/customer_detail/customer_recording_actions.dart';

/// Full, scrollable list of every voice note linked to a customer (across all
/// their orders and measurements), grouped by date. Reached via "View all"
/// from the customer detail card when there are too many to preview inline.
class CustomerRecordingsScreen extends StatelessWidget {
  final Customer customer;

  const CustomerRecordingsScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: Text('Voice Notes')),
      body: Consumer2<OrderState, MeasurementState>(
        builder: (context, orderState, measurementState, _) {
          final timeline = CustomerRecordingsService.buildTimeline(
            orders: orderState.orders
                .where((o) => o.customerId == customer.id)
                .toList(),
            measurements:
                measurementState.getMeasurementsByCustomerId(customer.id),
          ).where((r) => File(r.filePath).existsSync()).toList();

          if (timeline.isEmpty) {
            return const Center(child: Text('No voice notes yet'));
          }

          return ListView(
            padding: const EdgeInsets.all(AppConfig.spacing16),
            children: _buildDatedItems(
              context,
              timeline,
              orderState,
              measurementState,
            ),
          );
        },
      ),
    );
  }

  /// Flatten the (newest-first) timeline into date headers + tiles.
  List<Widget> _buildDatedItems(
    BuildContext context,
    List<EntityRecording> timeline,
    OrderState orderState,
    MeasurementState measurementState,
  ) {
    final theme = Theme.of(context);
    final items = <Widget>[];
    String? currentDay;
    for (final rec in timeline) {
      final day = CustomerRecordingActions.dateLabel(rec.createdAt);
      if (day != currentDay) {
        currentDay = day;
        items.add(Padding(
          padding: EdgeInsets.only(
            top: items.isEmpty ? 0 : AppConfig.spacing16,
            bottom: AppConfig.spacing8,
          ),
          child: Text(
            day,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ));
      }
      items.add(RecordingListTile(
        filePath: rec.filePath,
        title: rec.label,
        badge: rec.kind.label,
        subtitle: CustomerRecordingActions.dateLabel(rec.createdAt),
        onOpen: () => CustomerRecordingActions.openSource(
          context,
          rec,
          customer,
          orderState,
          measurementState,
        ),
      ));
    }
    return items;
  }
}
