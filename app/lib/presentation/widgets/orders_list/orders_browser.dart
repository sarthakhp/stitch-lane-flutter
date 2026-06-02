import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../backend/backend.dart';
import '../../../constants/app_constants.dart';
import '../../../domain/domain.dart';
import '../../../domain/models/filter_preset.dart';
import '../../../domain/models/order_filter_options.dart';
import '../../../utils/utils.dart';
import '../../presentation.dart';
import '../order_filter_dialog.dart';

/// The shared orders surface: search, filter chips/dialog, and a responsive
/// master–detail list (single column on phone → navigates; two panes on tablet
/// → selects). Both the Orders tab and the per-customer / all-orders route are
/// thin wrappers over this — there is no duplicated list/filter logic.
class OrdersBrowser extends StatefulWidget {
  /// When set, scopes to one customer's orders and hides the per-row name.
  final Customer? customer;
  final String title;
  final FilterPreset? initialPreset;

  /// When provided, a sticky "Create Order" button is shown at the bottom of
  /// the list pane. Left null where a shell FAB already offers creation.
  final VoidCallback? onCreate;

  const OrdersBrowser({
    super.key,
    this.customer,
    required this.title,
    this.initialPreset,
    this.onCreate,
  });

  @override
  State<OrdersBrowser> createState() => OrdersBrowserState();
}

class OrdersBrowserState extends State<OrdersBrowser>
    with UnfocusOnNavigationBackMixin {
  String _searchQuery = '';
  late OrderFilterOptions _filterOptions;
  FilterPreset? _selectedPreset;

  /// Selected order id for the tablet master–detail pane (null on phone).
  String? _selectedOrderId;

  @override
  void initState() {
    super.initState();
    _filterOptions = widget.initialPreset?.options ?? const OrderFilterOptions();
    _selectedPreset = widget.initialPreset;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDataIfNeeded());
  }

  /// Force-apply a preset requested from outside (e.g. a home KPI tap routed
  /// through the shell). Unlike tapping a chip, this never toggles off.
  void applyExternalFilter(FilterPreset preset) {
    setState(() {
      _filterOptions = preset.options;
      _selectedPreset = preset;
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

  Future<void> _refreshOrders() => OrderService.loadOrders(
        context.read<OrderState>(),
        context.read<OrderRepository>(),
      );

  void _onSearchChanged(String q) => setState(() => _searchQuery = q);
  void _onClearSearch() => setState(() => _searchQuery = '');

  FilterPreset? _findMatchingPreset(OrderFilterOptions options) {
    for (final preset in FilterPreset.allPresets) {
      if (preset.options == options) return preset;
    }
    return null;
  }

  Future<void> _openFilterDialog() async {
    final result = await showDialog<OrderFilterOptions>(
      context: context,
      builder: (_) => OrderFilterDialog(initialOptions: _filterOptions),
    );
    if (result != null && mounted) {
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
    CustomerLookup customers,
  ) {
    var result = List<Order>.from(
      SearchHelper.filterOrders(orders, _searchQuery, customers: customers),
    ).where((o) => _filterOptions.matchesOrder(o)).toList();

    if (_filterOptions.sortMode == OrderSortMode.createdDate) {
      result.sort((a, b) => b.created.compareTo(a.created));
    } else {
      result.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    }
    return result;
  }

  Future<void> _toggleOrderStatus(Order order) async {
    try {
      final updated = await OrderService.toggleOrderStatus(
        context.read<OrderState>(),
        context.read<OrderRepository>(),
        order,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(milliseconds: 800),
          content: Text(OrderService.getStatusToggleMessage(updated.status)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update order status: $e')),
        );
      }
    }
  }

  Order? _selectedFrom(List<Order> filtered) {
    for (final o in filtered) {
      if (o.id == _selectedOrderId) return o;
    }
    return filtered.first;
  }

  Customer? _resolveCustomer(CustomerLookup customers, Order order) {
    return widget.customer ?? customers.byId(order.customerId);
  }

  void _onOrderTap(Order order, Customer customer, bool twoPane) {
    if (twoPane) {
      setState(() => _selectedOrderId = order.id);
    } else {
      Navigator.pushNamed(
        context,
        AppConstants.orderDetailRoute,
        arguments: {'order': order, 'customer': customer},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(widget.title),
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
      body: Consumer3<OrderState, CustomerState, SettingsState>(
        builder: (context, orderState, customerState, settingsState, _) {
          if (orderState.isLoading && orderState.orders.isEmpty) {
            return const LoadingWidget();
          }
          if (orderState.error != null && orderState.orders.isEmpty) {
            return ErrorDisplayWidget(
              message: orderState.error!,
              onRetry: _refreshOrders,
            );
          }

          final displayOrders = widget.customer != null
              ? orderState.orders
                  .where((o) => o.customerId == widget.customer!.id)
                  .toList()
              : orderState.orders;
          final lookup = customerState.lookup;
          final filtered = displayOrders.isEmpty
              ? const <Order>[]
              : _getFilteredAndSortedOrders(displayOrders, lookup);

          final twoPane = MasterDetailLayout.isTwoPane(context);
          final selected =
              (twoPane && filtered.isNotEmpty) ? _selectedFrom(filtered) : null;

          final master = _buildMasterPane(
            displayOrders: displayOrders,
            filtered: filtered,
            customers: lookup,
            dueThreshold: settingsState.dueDateWarningThreshold,
            selectedId: selected?.id,
            twoPane: twoPane,
          );

          Widget? detail;
          if (selected != null) {
            final customer = _resolveCustomer(lookup, selected);
            if (customer != null) {
              detail = OrderDetailView(
                key: ValueKey(selected.id),
                order: selected,
                customer: customer,
                onDeleted: () => setState(() => _selectedOrderId = null),
                showViewCustomer: widget.customer == null,
              );
            }
          }

          return MasterDetailLayout(
            master: master,
            detail: detail,
            placeholder: const MasterDetailPlaceholder(
              icon: Icons.receipt_long_outlined,
              message: 'Select an order to view its details',
            ),
          );
        },
      ),
    );
  }

  Widget _buildMasterPane({
    required List<Order> displayOrders,
    required List<Order> filtered,
    required CustomerLookup customers,
    required int dueThreshold,
    required String? selectedId,
    required bool twoPane,
  }) {
    // A Scaffold per master pane so the create FAB sits at the bottom-right of
    // the list (left pane in two-pane mode), not over the detail pane.
    return Scaffold(
      body: Column(
        children: [
          OrderFilterPresetChips(
            selectedPreset: _selectedPreset,
            onPresetSelected: _applyPreset,
          ),
          Expanded(
            child: _buildListArea(
              displayOrders: displayOrders,
              filtered: filtered,
              customers: customers,
              dueThreshold: dueThreshold,
              selectedId: selectedId,
              twoPane: twoPane,
            ),
          ),
        ],
      ),
      floatingActionButton: widget.onCreate == null
          ? null
          : FloatingActionButton(
              onPressed: widget.onCreate,
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildListArea({
    required List<Order> displayOrders,
    required List<Order> filtered,
    required CustomerLookup customers,
    required int dueThreshold,
    required String? selectedId,
    required bool twoPane,
  }) {
    if (displayOrders.isEmpty) return const EmptyOrdersState();
    if (filtered.isEmpty) {
      return const EmptySearchState(message: 'No orders found');
    }
    return OrdersListView(
      orders: filtered,
      resolveCustomer: (order) => _resolveCustomer(customers, order),
      selectedOrderId: selectedId,
      showCustomerName: widget.customer == null,
      dueDateWarningThreshold: dueThreshold,
      onSelect: (order, customer) => _onOrderTap(order, customer, twoPane),
      onToggleStatus: _toggleOrderStatus,
      onRefresh: _refreshOrders,
    );
  }
}
