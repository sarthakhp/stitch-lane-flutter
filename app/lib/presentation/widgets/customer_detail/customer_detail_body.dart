import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../backend/models/customer.dart';
import '../../../config/app_config.dart';
import '../../../constants/app_constants.dart';
import '../../../domain/domain.dart';
import '../markdown_description_text.dart';
import '../measurement_card.dart';

/// Scrollable content of a customer's detail: name, latest measurement, unpaid
/// total, phone, and description. Purely presentational — reused by both the
/// full-screen detail and the tablet detail pane.
class CustomerDetailBody extends StatelessWidget {
  final Customer customer;

  const CustomerDetailBody({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConfig.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoCard(
            context,
            icon: Icons.person,
            label: 'Name',
            child: Text(
              customer.name,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: AppConfig.spacing16),
          _buildMeasurementCard(context),
          const SizedBox(height: AppConfig.spacing16),
          _buildUnpaidCard(context),
          if (customer.phoneNumber != null && customer.phoneNumber!.isNotEmpty) ...[
            const SizedBox(height: AppConfig.spacing16),
            _infoCard(
              context,
              icon: Icons.phone,
              label: 'Phone Number',
              child: Text(
                customer.phoneNumber!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
          if (customer.description != null && customer.description!.isNotEmpty) ...[
            const SizedBox(height: AppConfig.spacing16),
            _infoCard(
              context,
              icon: Icons.description,
              label: 'Description',
              crossStart: true,
              child: MarkdownDescriptionText(text: customer.description!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Widget child,
    bool crossStart = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Row(
          crossAxisAlignment:
              crossStart ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppConfig.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: AppConfig.spacing8),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementCard(BuildContext context) {
    return Consumer<MeasurementState>(
      builder: (context, measurementState, _) {
        final latest =
            measurementState.getLatestMeasurementForCustomer(customer.id);
        return MeasurementCard(
          latestMeasurement: latest,
          onCreateNew: () => Navigator.pushNamed(
            context,
            AppConstants.measurementFormRoute,
            arguments: {'customer': customer},
          ),
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

  Widget _buildUnpaidCard(BuildContext context) {
    return Consumer<OrderState>(
      builder: (context, orderState, _) {
        final unpaid = orderState.getTotalUnpaidAmount(customer.id);
        final hasUnpaid = unpaid > 0;
        final colorScheme = Theme.of(context).colorScheme;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConfig.spacing16),
            child: Row(
              children: [
                Icon(
                  Icons.currency_rupee,
                  color: hasUnpaid ? colorScheme.error : colorScheme.primary,
                ),
                const SizedBox(width: AppConfig.spacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Unpaid Amount',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: AppConfig.spacing8),
                      Text(
                        '$unpaid',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              color: hasUnpaid
                                  ? colorScheme.error
                                  : colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConfig.spacing12,
                    vertical: AppConfig.spacing8,
                  ),
                  decoration: BoxDecoration(
                    color: hasUnpaid
                        ? colorScheme.errorContainer
                        : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppConfig.spacing12),
                  ),
                  child: Text(
                    hasUnpaid ? 'Unpaid' : 'All Paid',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: hasUnpaid
                              ? colorScheme.onErrorContainer
                              : colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
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
}
