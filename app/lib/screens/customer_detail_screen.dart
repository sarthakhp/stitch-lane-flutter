import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/backend.dart';
import '../domain/domain.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../presentation/presentation.dart';
import '../presentation/widgets/contact_action_buttons.dart';
import '../presentation/widgets/measurement_card.dart';
import '../presentation/widgets/markdown_description_text.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late String _customerId;

  @override
  void initState() {
    super.initState();
    _customerId = widget.customer.id;
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
      _customerId,
    );
  }

  Future<void> _deleteCustomer(BuildContext context, String customerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: const Text('Are you sure you want to delete this customer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final customerState = context.read<CustomerState>();
        final customerRepository = context.read<CustomerRepository>();
        final orderState = context.read<OrderState>();
        final orderRepository = context.read<OrderRepository>();
        await CustomerService.deleteCustomer(
          customerState,
          customerRepository,
          customerId,
          orderState: orderState,
          orderRepository: orderRepository,
        );
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete customer: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerState>(
      builder: (context, customerState, child) {
        final customer = customerState.customers.firstWhere(
          (c) => c.id == _customerId,
          orElse: () => widget.customer,
        );

        return Scaffold(
          appBar: CustomAppBar(
            title: Text(customer.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppConstants.customerFormRoute,
                    arguments: customer,
                  );
                },
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _deleteCustomer(context, _customerId),
                tooltip: 'Delete',
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
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
                          Icons.person,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: AppConfig.spacing16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Name',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              const SizedBox(height: AppConfig.spacing8),
                              Text(
                                customer.name,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppConfig.spacing16),
            Consumer<MeasurementState>(
              builder: (context, measurementState, child) {
                final latestMeasurement = measurementState.getLatestMeasurementForCustomer(_customerId);
                return MeasurementCard(
                  latestMeasurement: latestMeasurement,
                  onCreateNew: () {
                    Navigator.pushNamed(
                      context,
                      AppConstants.measurementFormRoute,
                      arguments: {'customer': customer},
                    );
                  },
                  onViewAll: () {
                    Navigator.pushNamed(
                      context,
                      AppConstants.measurementsListRoute,
                      arguments: customer,
                    );
                  },
                  onTapLatest: latestMeasurement != null
                      ? () {
                          Navigator.pushNamed(
                            context,
                            AppConstants.measurementDetailRoute,
                            arguments: {
                              'measurement': latestMeasurement,
                              'customer': customer,
                            },
                          );
                        }
                      : null,
                );
              },
            ),
            const SizedBox(height: AppConfig.spacing16),
            Consumer<OrderState>(
              builder: (context, orderState, child) {
                final totalUnpaidAmount = orderState.getTotalUnpaidAmount(customer.id);
                final hasUnpaidAmount = totalUnpaidAmount > 0;
                final colorScheme = Theme.of(context).colorScheme;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConfig.spacing16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.currency_rupee,
                          color: hasUnpaidAmount
                              ? colorScheme.error
                              : colorScheme.primary,
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
                                '$totalUnpaidAmount',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: hasUnpaidAmount
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
                            color: hasUnpaidAmount
                                ? colorScheme.errorContainer
                                : colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(AppConfig.spacing12),
                          ),
                          child: Text(
                            hasUnpaidAmount ? 'Unpaid' : 'All Paid',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: hasUnpaidAmount
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
            ),
            if (customer.phoneNumber != null && customer.phoneNumber!.isNotEmpty) ...[
              const SizedBox(height: AppConfig.spacing16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppConfig.spacing16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: AppConfig.spacing16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Phone Number',
                                  style: Theme.of(context).textTheme.labelMedium,
                                ),
                                const SizedBox(height: AppConfig.spacing8),
                                Text(
                                  customer.phoneNumber!,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (customer.description != null && customer.description!.isNotEmpty) ...[
              const SizedBox(height: AppConfig.spacing16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppConfig.spacing16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.description,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: AppConfig.spacing16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Description',
                                  style: Theme.of(context).textTheme.labelMedium,
                                ),
                                const SizedBox(height: AppConfig.spacing8),
                                MarkdownDescriptionText(
                                  text: customer.description!,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppConfig.spacing16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Consumer<OrderState>(
                    builder: (context, orderState, child) {
                      final customerOrders = orderState.orders
                          .where((order) => order.customerId == customer.id)
                          .toList();
                      final orderCount = customerOrders.length;
                      final hasPhone = customer.phoneNumber != null &&
                                      customer.phoneNumber!.isNotEmpty;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  AppConstants.ordersListRoute,
                                  arguments: customer,
                                );
                              },
                              icon: Badge(
                                label: Text('$orderCount'),
                                isLabelVisible: orderCount > 0,
                                child: const Icon(Icons.assignment),
                              ),
                              label: const Text('View Orders'),
                            ),
                          ),
                          const SizedBox(height: AppConfig.spacing8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  AppConstants.orderFormRoute,
                                  arguments: {'customer': customer},
                                );
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Create Order'),
                            ),
                          ),
                          if (hasPhone) ...[
                            const SizedBox(height: AppConfig.spacing8),
                            ContactActionButtons(
                              phoneNumber: customer.phoneNumber!,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

