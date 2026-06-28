import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../backend/models/customer.dart';
import '../../../backend/models/order.dart';
import '../../../config/app_config.dart';
import '../../../constants/app_constants.dart';
import '../../../domain/domain.dart';
import '../../../domain/state/sync_state.dart';
import '../audio/recordings_card.dart';
import '../detail/delete_entity_button.dart';
import '../markdown_description_text.dart';
import '../measurement_card.dart';
import '../sync/writer_only.dart';
import '../order_detail_card.dart';
import '../order_images_section.dart';
import '../payments_section.dart';

/// Scrollable content of an order's detail: latest measurement, the order's
/// fields, payments, and images. Purely presentational — it emits an updated
/// [Order] via [onOrderUpdated] (payments, image edits) and lets the parent
/// persist. Reused by both the full-screen detail and the tablet detail pane.
class OrderDetailBody extends StatelessWidget {
  final Order order;
  final Customer customer;
  final ValueChanged<Order> onOrderUpdated;
  final VoidCallback onDelete;

  const OrderDetailBody({
    super.key,
    required this.order,
    required this.customer,
    required this.onOrderUpdated,
    required this.onDelete,
  });

  String _formatDate(DateTime date) => DateFormat('MMMM d, y').format(date);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConfig.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMeasurementCard(context),
          const SizedBox(height: AppConfig.spacing16),
          if (order.title != null && order.title!.isNotEmpty) ...[
            OrderDetailCard(
              icon: Icons.assignment,
              label: 'Title',
              value: order.title!,
            ),
            const SizedBox(height: AppConfig.spacing16),
          ],
          OrderDetailCard(
            icon: Icons.calendar_today,
            label: 'Due Date',
            value: _formatDate(order.dueDate),
          ),
          const SizedBox(height: AppConfig.spacing16),
          OrderDetailCard(
            icon: Icons.currency_rupee,
            label: 'Order Value',
            value: order.value == null ? 'Not set' : '₹${order.value}',
          ),
          if (order.description != null && order.description!.isNotEmpty) ...[
            const SizedBox(height: AppConfig.spacing16),
            OrderDetailCard(
              icon: Icons.notes,
              label: 'Description',
              child: MarkdownDescriptionText(text: order.description!),
            ),
          ],
          if (order.audioFilePaths.isNotEmpty) ...[
            const SizedBox(height: AppConfig.spacing16),
            RecordingsCard(filePaths: order.audioFilePaths),
          ],
          const SizedBox(height: AppConfig.spacing16),
          OrderDetailCard(
            icon: Icons.access_time,
            label: 'Created',
            value: _formatDate(order.created),
          ),
          const SizedBox(height: AppConfig.spacing16),
          PaymentsSection(order: order, onOrderUpdated: onOrderUpdated),
          const SizedBox(height: AppConfig.spacing16),
          OrderImagesSection(
            imagePaths: order.imagePaths,
            onImagesChanged: (paths) =>
                onOrderUpdated(order.copyWith(imagePaths: paths)),
          ),
          const SizedBox(height: AppConfig.spacing24),
          WriterOnly(
            child: DeleteEntityButton(label: 'Delete Order', onPressed: onDelete),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementCard(BuildContext context) {
    return Consumer<MeasurementState>(
      builder: (context, measurementState, _) {
        final latest =
            measurementState.getLatestMeasurementForCustomer(customer.id);
        final canWrite =
            context.select<SyncState, bool>((s) => s.canWrite);
        return MeasurementCard(
          latestMeasurement: latest,
          onCreateNew: canWrite
              ? () => Navigator.pushNamed(
                    context,
                    AppConstants.measurementFormRoute,
                    arguments: {'customer': customer},
                  )
              : null,
          onViewAll: () => Navigator.pushNamed(
            context,
            AppConstants.measurementsListRoute,
            arguments: customer,
          ),
          onTapLatest: latest != null
              ? () => Navigator.pushNamed(
                    context,
                    AppConstants.measurementDetailRoute,
                    arguments: {'measurement': latest, 'customer': customer},
                  )
              : null,
        );
      },
    );
  }
}
