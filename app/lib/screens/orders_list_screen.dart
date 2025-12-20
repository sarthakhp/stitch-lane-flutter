import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/domain.dart';
import '../backend/backend.dart';
import '../presentation/presentation.dart';
import '../constants/app_constants.dart';
import '../utils/utils.dart';
import '../domain/models/order_filter_options.dart';
import '../domain/models/filter_preset.dart';
import '../presentation/widgets/order_filter_dialog.dart';

class OrdersListScreen extends StatefulWidget {
  final Customer? customer;
  final FilterPreset? initialFilterPreset;

  const OrdersListScreen({
    super.key,
    this.customer,
    this.initialFilterPreset,
  });

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen>
    with UnfocusOnNavigationBackMixin {
  String _searchQuery = '';
  late OrderFilterOptions _filterOptions;
  FilterPreset? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _initializeFilters();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDataIfNeeded();
    });
  }

  void _initializeFilters() {
    if (widget.initialFilterPreset != null) {
      _selectedPreset = widget.initialFilterPreset;
      _filterOptions = widget.initialFilterPreset!.options;
    } else {
      _filterOptions = const OrderFilterOptions();
      _selectedPreset = null;
    }
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

  FilterPreset? _findMatchingPreset(OrderFilterOptions options) {
    for (final preset in FilterPreset.allPresets) {
      if (preset.options == options) {
        return preset;
      }
    }
    return null;
  }

  Future<void> _openFilterDialog() async {
    final result = await showDialog<OrderFilterOptions>(
      context: context,
      builder: (context) => OrderFilterDialog(
        initialOptions: _filterOptions,
      ),
    );

    if (result != null) {
      setState(() {
        _filterOptions = result;
        _selectedPreset = _findMatchingPreset(result);
      });
    }
  }

  void _applyPreset(FilterPreset preset) {
    setState(() {
      if (_selectedPreset == preset) {
        _filterOptions = const OrderFilterOptions();
        _selectedPreset = null;
      } else {
        _filterOptions = preset.options;
        _selectedPreset = preset;
      }
    });
  }

  List<Order> _getFilteredAndSortedOrders(
    List<Order> orders,
    List<Customer> customers,
  ) {
    var filteredOrders = List<Order>.from(
      SearchHelper.filterOrders(
        orders,
        _searchQuery,
        customers: customers,
      ),
    );

    filteredOrders = filteredOrders
        .where((order) => _filterOptions.matchesOrder(order))
        .toList();

    filteredOrders.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return filteredOrders;
  }

  Future<void> _toggleOrderStatus(Order order) async {
    final state = context.read<OrderState>();
    final repository = context.read<OrderRepository>();

    try {
      final updatedOrder = await OrderService.toggleOrderStatus(
        state,
        repository,
        order,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 800),
            content: Text(OrderService.getStatusToggleMessage(updatedOrder.status)),
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
      appBar: CustomAppBar(
        title: Text(widget.customer != null
            ? '${widget.customer!.name}\'s Orders'
            : 'All Orders'),
        actions: [
          Badge(
            isLabelVisible: _filterOptions.isFilterActive,
            child: IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _openFilterDialog,
              tooltip: 'Filter orders',
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: SearchBarWidget(
            hintText: 'Search orders...',
            onSearchChanged: _onSearchChanged,
            onClear: _onClearSearch,
          ),
        ),
      ),
      body: Column(
        children: [
          OrderFilterPresetChips(
            selectedPreset: _selectedPreset,
            onPresetSelected: _applyPreset,
          ),
          Expanded(
            child: Consumer3<OrderState, CustomerState, SettingsState>(
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

          final filteredOrders = _getFilteredAndSortedOrders(
            displayOrders,
            customerState.customers,
          );

          if (filteredOrders.isEmpty) {
            return const EmptySearchState(
              message: 'No orders found',
            );
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (scrollNotification) {
              if (scrollNotification is ScrollStartNotification) {
                FocusScope.of(context).unfocus();
              }
              return false;
            },
            child: RefreshIndicator(
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
            ),
          );
        },
            ),
          ),
          StickyActionButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppConstants.orderFormRoute,
                arguments: widget.customer != null
                    ? <String, dynamic>{'customer': widget.customer}
                    : <String, dynamic>{},
              );
            },
            icon: Icons.add,
            label: 'Create Order',
          ),
        ],
      ),
    );
  }
}

