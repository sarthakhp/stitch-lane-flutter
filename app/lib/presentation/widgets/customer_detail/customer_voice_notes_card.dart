import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../backend/models/customer.dart';
import '../../../config/app_config.dart';
import '../../../constants/app_constants.dart';
import '../../../domain/domain.dart';
import '../../../domain/services/recordings/customer_recordings_service.dart';
import '../../../domain/services/recordings/entity_recording.dart' show EntityRecordingKindLabel;
import '../audio/recording_list_tile.dart';
import 'customer_recording_actions.dart';

/// "Voice Notes" preview on the customer detail screen: the most recent few
/// recordings linked to this customer's orders and measurements, with a
/// "View all" link to the full screen when there are more. Reactive to
/// [OrderState] / [MeasurementState]; hidden entirely when there are none.
class CustomerVoiceNotesCard extends StatelessWidget {
  final Customer customer;

  /// How many to show inline before collapsing the rest behind "View all".
  static const int _previewCount = 3;

  const CustomerVoiceNotesCard({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return Consumer2<OrderState, MeasurementState>(
      builder: (context, orderState, measurementState, _) {
        final timeline = CustomerRecordingsService.buildTimeline(
          orders: orderState.orders
              .where((o) => o.customerId == customer.id)
              .toList(),
          measurements:
              measurementState.getMeasurementsByCustomerId(customer.id),
        ).where((r) => File(r.filePath).existsSync()).toList();

        if (timeline.isEmpty) return const SizedBox.shrink();

        final preview = timeline.take(_previewCount).toList();
        final remaining = timeline.length - preview.length;

        return Padding(
          padding: const EdgeInsets.only(top: AppConfig.spacing16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConfig.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(count: timeline.length),
                  const SizedBox(height: AppConfig.spacing8),
                  for (var i = 0; i < preview.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    RecordingListTile(
                      filePath: preview[i].filePath,
                      title: preview[i].label,
                      badge: preview[i].kind.label,
                      subtitle:
                          CustomerRecordingActions.dateLabel(preview[i].createdAt),
                      onOpen: () => CustomerRecordingActions.openSource(
                        context, preview[i], customer, orderState, measurementState),
                    ),
                  ],
                  if (remaining > 0)
                    _ViewAllButton(
                      remaining: remaining,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppConstants.customerRecordingsRoute,
                        arguments: customer,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final int count;
  const _Header({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.graphic_eq, color: theme.colorScheme.primary),
        const SizedBox(width: AppConfig.spacing16),
        Expanded(
          child: Text(
            'Voice Notes',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Text(
          '$count',
          style: theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ViewAllButton extends StatelessWidget {
  final int remaining;
  final VoidCallback onTap;

  const _ViewAllButton({required this.remaining, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onTap,
        child: Text('View all ($remaining more)'),
      ),
    );
  }
}
