import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/domain.dart';
import '../backend/backend.dart';
import '../presentation/presentation.dart';
import '../constants/app_constants.dart';
import '../utils/utils.dart';

class OrdersListScreen extends StatefulWidget {
  final Customer? customer;

  const OrdersListScreen({
    super.key,
    this.customer,
  });

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDataIfNeeded();
    });
  }

  Future<void> _loadDataIfNeeded() async {
    final orderState = context.read<OrderState>();
    final customerState = context.read<CustomerState>();
    final orderRepository = context.read<OrderRepository>();
    final customerRepository = context.read<CustomerRepository>();

    if (orderState.orders.isEmpty) {
      await OrderService.loadOrders(orderState, orderRepository);
    }

    if (customerState.customers.isEmpty) {
      await CustomerService.loadCustomers(customerState, customerRepository);
    }
  }

  Future<void> _refreshOrders() async {
    final state = context.read<OrderState>();
    final repository = context.read<OrderRepository>();
    await OrderService.loadOrders(state, repository);
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _onClearSearch() {
    setState(() {
      _searchQuery = '';
    });
  }

  Future<void> _toggleOrderStatus(Order order) async {
    final state = context.read<OrderState>();
    final repository = context.read<OrderRepository>();

    try {
      final newStatus = order.status == OrderStatus.done
          ? OrderStatus.pending
          : OrderStatus.done;

      final updatedOrder = order.copyWith(status: newStatus);

      await OrderService.updateOrder(state, repository, updatedOrder);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 800),
            content: Text(
              newStatus == OrderStatus.done
                  ? 'Order marked as done'
                  : 'Order marked as pending',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update order status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer != null
            ? '${widget.customer!.name}\'s Orders'
            : 'All Orders'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: SearchBarWidget(
            hintText: 'Search orders...',
            onSearchChanged: _onSearchChanged,
            onClear: _onClearSearch,
          ),
        ),
      ),
      body: Consumer3<OrderState, CustomerState, SettingsState>(
        builder: (context, orderState, customerState, settingsState, child) {
          final state = orderState;
          if (state.isLoading && state.orders.isEmpty) {
            return const LoadingWidget();
          }

          if (state.error != null && state.orders.isEmpty) {
            return ErrorDisplayWidget(
              message: state.error!,
              onRetry: _refreshOrders,
            );
          }

          final displayOrders = widget.customer != null
              ? state.orders
                  .where((order) => order.customerId == widget.customer!.id)
                  .toList()
              : state.orders;

          if (displayOrders.isEmpty) {
            return const EmptyOrdersState();
          }

          final filteredOrders = List<Order>.from(
            SearchHelper.filterOrders(
              displayOrders,
              _searchQuery,
              customers: customerState.customers,
            ),
          // )..sort((a, b) => b.created.compareTo(a.created));
          )..sort((a, b) => a.dueDate.compareTo(b.dueDate));

          if (filteredOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No orders found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try a different search term',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshOrders,
            child: ListView.builder(
              itemCount: filteredOrders.length,
              itemBuilder: (context, index) {
                final order = filteredOrders[index];
                final customer = widget.customer ??
                    customerState.customers.firstWhere(
                      (c) => c.id == order.customerId,
                    );
                return OrderListItem(
                  order: order,
                  customerName: widget.customer == null ? customer.name : null,
                  dueDateWarningThreshold: settingsState.dueDateWarningThreshold,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppConstants.orderDetailRoute,
                      arguments: {'order': order, 'customer': customer},
                    );
                  },
                  onStatusToggle: () => _toggleOrderStatus(order),
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
            AppConstants.orderFormRoute,
            arguments: widget.customer != null
                ? <String, dynamic>{'customer': widget.customer}
                : <String, dynamic>{},
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Order'),
      ),
    );
  }
}

