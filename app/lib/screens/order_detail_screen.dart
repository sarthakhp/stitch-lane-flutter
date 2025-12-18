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
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConfig.spacing16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
            );
          },
        );
      },
    );
  }
}

