import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../backend/backend.dart';
import '../domain/domain.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';

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
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMMM d, y').format(date);
  }

  Future<void> _toggleOrderStatus(BuildContext context, Order order) async {
    try {
      final state = context.read<OrderState>();
      final repository = context.read<OrderRepository>();

      final newStatus = order.status == OrderStatus.done
          ? OrderStatus.pending
          : OrderStatus.done;

      final updatedOrder = order.copyWith(status: newStatus);

      await OrderService.updateOrder(state, repository, updatedOrder);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == OrderStatus.done
                  ? 'Order marked as done'
                  : 'Order marked as pending',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update order status: $e')),
        );
      }
    }
  }

  Future<void> _deleteOrder(BuildContext context, String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: const Text('Are you sure you want to delete this order?'),
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
        final state = context.read<OrderState>();
        final repository = context.read<OrderRepository>();
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
                                  Icons.assignment,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: AppConfig.spacing16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Title',
                                        style: Theme.of(context).textTheme.labelMedium,
                                      ),
                                      const SizedBox(height: AppConfig.spacing8),
                                      Text(
                                        order.title,
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
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<OrderStatus>(
                        segments: [
                          ButtonSegment<OrderStatus>(
                            value: OrderStatus.pending,
                            label: const Text('Pending'),
                            icon: const Icon(Icons.pending_outlined),
                          ),
                          ButtonSegment<OrderStatus>(
                            value: OrderStatus.done,
                            label: const Text('Done'),
                            icon: const Icon(Icons.check_circle_outline),
                          ),
                        ],
                        selected: {order.status},
                        onSelectionChanged: (Set<OrderStatus> newSelection) {
                          _toggleOrderStatus(context, order);
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.comfortable,
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
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: AppConfig.spacing16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Due Date',
                                        style: Theme.of(context).textTheme.labelMedium,
                                      ),
                                      const SizedBox(height: AppConfig.spacing8),
                                      Text(
                                        _formatDate(order.dueDate),
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
                    if (order.description != null && order.description!.isNotEmpty) ...[
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
                                    Icons.notes,
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
                                        Text(
                                          order.description!,
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
                                  Icons.access_time,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: AppConfig.spacing16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Created',
                                        style: Theme.of(context).textTheme.labelMedium,
                                      ),
                                      const SizedBox(height: AppConfig.spacing8),
                                      Text(
                                        _formatDate(order.created),
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
                ),
              ),
            );
          },
        );
      },
    );
  }
}

