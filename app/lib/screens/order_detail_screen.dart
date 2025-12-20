import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../backend/backend.dart';
import '../domain/domain.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../presentation/presentation.dart';
import '../presentation/widgets/order_detail_card.dart';
import '../presentation/widgets/confirmation_dialog.dart';
import '../presentation/widgets/measurement_card.dart';
import '../presentation/widgets/order_images_section.dart';

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

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.done:
        return 'Done';
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.access_time_outlined;
      case OrderStatus.ready:
        return Icons.check;
      case OrderStatus.done:
        return Icons.done_all;
    }
  }

  Color _getStatusColor(BuildContext context, OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Theme.of(context).colorScheme.onSecondaryContainer;
      case OrderStatus.ready:
        return Colors.orange.shade700;
      case OrderStatus.done:
        return Colors.green.shade700;
    }
  }

  Future<void> _toggleOrderStatus(BuildContext context, Order order) async {
    final state = context.read<OrderState>();
    final repository = context.read<OrderRepository>();

    try {
      final OrderStatus newStatus;

      switch (order.status) {
        case OrderStatus.pending:
          newStatus = OrderStatus.ready;
          break;
        case OrderStatus.ready:
          newStatus = OrderStatus.done;
          break;
        case OrderStatus.done:
          newStatus = OrderStatus.pending;
          break;
      }

      final updatedOrder = order.copyWith(status: newStatus);
      await OrderService.updateOrder(state, repository, updatedOrder);

      if (context.mounted) {
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update order status: $e')),
        );
      }
    }
  }

  Future<void> _togglePaymentStatus(BuildContext context, Order order) async {
    final state = context.read<OrderState>();
    final repository = context.read<OrderRepository>();

    try {
      final newValue = !order.isPaid;
      final updatedOrder = order.copyWith(isPaid: newValue);
      await OrderService.updateOrder(state, repository, updatedOrder);

      if (context.mounted) {
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update payment status: $e')),
        );
      }
    }
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
              appBar: CustomAppBar(
                title: Text('Order for ${customer.name}'),
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
                      value: '${order.value}',
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
                    const SizedBox(height: AppConfig.spacing16),
                    OrderImagesSection(
                      imagePaths: order.imagePaths,
                      onImagesChanged: (updatedPaths) async {
                        final state = context.read<OrderState>();
                        final repository = context.read<OrderRepository>();
                        final updatedOrder = order.copyWith(imagePaths: updatedPaths);
                        try {
                          await OrderService.updateOrder(state, repository, updatedOrder);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update images: $e')),
                            );
                          }
                        }
                      },
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  onPressed: () => _toggleOrderStatus(context, order),
                                  icon: Icon(_getStatusIcon(order.status)),
                                  label: Text(_getStatusText(order.status)),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _getStatusColor(context, order.status).withValues(alpha: 0.2),
                                    foregroundColor: _getStatusColor(context, order.status),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppConfig.spacing8),
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  onPressed: () => _togglePaymentStatus(context, order),
                                  icon: Icon(order.isPaid ? Icons.check_circle : Icons.pending),
                                  label: Text(order.isPaid ? 'Paid' : 'Not Paid'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: order.isPaid
                                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                                        : Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                                    foregroundColor: order.isPaid
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppConfig.spacing8),
                          SizedBox(
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
                        ],
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

