import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../backend/backend.dart';
import '../domain/domain.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../presentation/widgets/order_detail_card.dart';
import '../presentation/widgets/order_status_toggle.dart';
import '../presentation/widgets/confirmation_dialog.dart';
import '../presentation/widgets/measurement_card.dart';

class OrderDetailScreen extends StatefulWidget {
  final Order order;
  final Customer customer;

  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.customer,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late String _orderId;
  late String _customerId;

  @override
  void initState() {
    super.initState();
    _orderId = widget.order.id;
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

  String _formatDate(DateTime date) {
    return DateFormat('MMMM d, y').format(date);
  }

  Future<void> _deleteOrder(BuildContext context, String orderId) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete Order',
      content: 'Are you sure you want to delete this order?',
    );

    if (!confirmed || !context.mounted) return;

    final state = context.read<OrderState>();
    final repository = context.read<OrderRepository>();

    try {
      await OrderService.deleteOrder(state, repository, orderId);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order deleted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete order: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderState>(
      builder: (context, orderState, child) {
        final order = orderState.orders.firstWhere(
          (o) => o.id == _orderId,
          orElse: () => widget.order,
        );

        return Consumer<CustomerState>(
          builder: (context, customerState, child) {
            final customer = customerState.customers.firstWhere(
              (c) => c.id == _customerId,
              orElse: () => widget.customer,
            );

            return Scaffold(
              appBar: AppBar(
                title: const Text('Order Details'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppConstants.orderFormRoute,
                        arguments: {'order': order, 'customer': customer},
                      );
                    },
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteOrder(context, _orderId),
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
                        );
                      },
                    ),
                    const SizedBox(height: AppConfig.spacing16),
                    if (order.title != null && order.title!.isNotEmpty) ...[
                      OrderDetailCard(
                        icon: Icons.assignment,
                        label: 'Title',
                        value: order.title!,
                      ),
                      const SizedBox(height: AppConfig.spacing16),
                    ],
                    OrderStatusToggle(order: order),
                    const SizedBox(height: AppConfig.spacing16),
                    OrderDetailCard(
                      icon: Icons.calendar_today,
                      label: 'Due Date',
                      value: _formatDate(order.dueDate),
                    ),
                    const SizedBox(height: AppConfig.spacing16),
                    OrderDetailCard(
                      icon: Icons.currency_rupee,
                      label: 'Order Value',
                      value: '₹${order.value}',
                    ),
                    const SizedBox(height: AppConfig.spacing16),
                    Card(
                      child: SwitchListTile(
                        title: const Text('Payment Status'),
                        subtitle: Text(
                          order.isPaid ? 'Paid' : 'Not Paid',
                          style: TextStyle(
                            color: order.isPaid
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value: order.isPaid,
                        onChanged: (value) async {
                          final state = context.read<OrderState>();
                          final repository = context.read<OrderRepository>();
                          final updatedOrder = order.copyWith(isPaid: value);
                          try {
                            await OrderService.updateOrder(state, repository, updatedOrder);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: const Duration(milliseconds: 800),
                                  content: Text(
                                    value ? 'Marked as paid' : 'Marked as not paid',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update payment status: $e')),
                              );
                            }
                          }
                        },
                        secondary: Icon(
                          order.isPaid ? Icons.check_circle : Icons.pending,
                          color: order.isPaid
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    if (order.description != null && order.description!.isNotEmpty) ...[
                      const SizedBox(height: AppConfig.spacing16),
                      OrderDetailCard(
                        icon: Icons.notes,
                        label: 'Description',
                        value: order.description!,
                      ),
                    ],
                    const SizedBox(height: AppConfig.spacing16),
                    OrderDetailCard(
                      icon: Icons.access_time,
                      label: 'Created',
                      value: _formatDate(order.created),
                    ),
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
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppConstants.customerDetailRoute,
                              arguments: customer,
                            );
                          },
                          icon: const Icon(Icons.person),
                          label: Text('View Customer: ${customer.name}'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

