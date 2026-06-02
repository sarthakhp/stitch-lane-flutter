import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../backend/backend.dart';
import '../../../constants/app_constants.dart';
import '../../../domain/domain.dart';
import '../../../utils/utils.dart';
import '../../presentation.dart';

/// The shared customers surface: search, filter chips/dialog, sort, and a
/// responsive master–detail list (single column on phone → navigates; two panes
/// on tablet → selects). Both the Customers tab and the customers route are
/// thin wrappers over this — no duplicated list/filter logic.
class CustomersBrowser extends StatefulWidget {
  final String title;
  final CustomerFilterPreset? initialPreset;
  final bool autoFocusSearch;

  /// When provided, a "create customer" FAB is shown. Left null where a shell
  /// FAB already offers creation (the Customers tab).
  final VoidCallback? onCreate;

  const CustomersBrowser({
    super.key,
    required this.title,
    this.initialPreset,
    this.autoFocusSearch = false,
    this.onCreate,
  });

  @override
  State<CustomersBrowser> createState() => CustomersBrowserState();
}

class CustomersBrowserState extends State<CustomersBrowser>
    with UnfocusOnNavigationBackMixin {
  String _searchQuery = '';
  CustomerSort _selectedSort = CustomerSort.dueDate;
  late CustomerFilterOptions _filterOptions;
  CustomerFilterPreset? _selectedPreset;

  /// Selected customer id for the tablet master–detail pane (null on phone).
  String? _selectedCustomerId;

  @override
  void initState() {
    super.initState();
    _filterOptions =
        widget.initialPreset?.options ?? const CustomerFilterOptions();
    _selectedPreset = widget.initialPreset;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDataIfNeeded());
  }

  /// Force-apply a preset requested from outside (e.g. a home KPI tap routed
  /// through the shell). Unlike tapping a chip, this never toggles off.
  void applyExternalFilter(CustomerFilterPreset preset) {
    setState(() {
      _filterOptions = preset.options;
      _selectedPreset = preset;
    });
  }

  Future<void> _loadDataIfNeeded() async {
    final customerState = context.read<CustomerState>();
    final orderState = context.read<OrderState>();
    final customerRepo = context.read<CustomerRepository>();
    final orderRepo = context.read<OrderRepository>();
    if (customerState.customers.isEmpty) {
      await CustomerService.loadCustomers(customerState, customerRepo);
    }
    if (orderState.orders.isEmpty) {
      await OrderService.loadOrders(orderState, orderRepo);
    }
  }

  Future<void> _refreshCustomers() => CustomerService.loadCustomers(
        context.read<CustomerState>(),
        context.read<CustomerRepository>(),
      );

  void _onSearchChanged(String q) => setState(() => _searchQuery = q);
  void _onClearSearch() => setState(() => _searchQuery = '');

  CustomerFilterPreset? _findMatchingPreset(CustomerFilterOptions options) {
    for (final preset in CustomerFilterPreset.allPresets) {
      if (preset.options == options) return preset;
    }
    return null;
  }

  Future<void> _openFilterDialog() async {
    final result = await showDialog<CustomerFilterOptions>(
      context: context,
      builder: (_) => CustomerFilterDialog(initialOptions: _filterOptions),
    );
    if (result != null && mounted) {
      setState(() {
        _filterOptions = result;
        _selectedPreset = _findMatchingPreset(result);
      });
    }
  }

  void _applyPreset(CustomerFilterPreset preset) {
    setState(() {
      if (_selectedPreset == preset) {
        _filterOptions = const CustomerFilterOptions();
        _selectedPreset = null;
      } else {
        _filterOptions = preset.options;
        _selectedPreset = preset;
      }
    });
  }

  List<Customer> _getFilteredAndSortedCustomers(
    List<Customer> customers,
    List<Order> orders,
  ) {
    var result = List<Customer>.from(
      SearchHelper.filterCustomers(customers, _searchQuery),
    );
    if (_filterOptions.isFilterActive) {
      result =
          result.where((c) => _filterOptions.matchesCustomer(c, orders)).toList();
    }
    return CustomerSortHelper.sortCustomersWithMode(
      result,
      orders,
      _selectedSort,
      _filterOptions.sortMode,
    );
  }

  Customer? _selectedFrom(List<Customer> filtered) {
    for (final c in filtered) {
      if (c.id == _selectedCustomerId) return c;
    }
    return filtered.first;
  }

  void _onCustomerTap(Customer customer, bool twoPane) {
    if (twoPane) {
      setState(() => _selectedCustomerId = customer.id);
    } else {
      Navigator.pushNamed(
        context,
        AppConstants.customerDetailRoute,
        arguments: customer,
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
              tooltip: 'Filter customers',
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: SearchBarWidget(
            hintText: 'Search customers...',
            onSearchChanged: _onSearchChanged,
            onClear: _onClearSearch,
            autofocus: widget.autoFocusSearch,
          ),
        ),
      ),
      body: Consumer3<CustomerState, OrderState, SettingsState>(
        builder: (context, customerState, orderState, settingsState, _) {
          if (customerState.isLoading && customerState.customers.isEmpty) {
            return const LoadingWidget();
          }
          if (customerState.error != null && customerState.customers.isEmpty) {
            return ErrorDisplayWidget(
              message: customerState.error!,
              onRetry: _refreshCustomers,
            );
          }
          if (customerState.customers.isEmpty) {
            return const EmptyCustomersState();
          }

          final filtered = _getFilteredAndSortedCustomers(
            customerState.customers,
            orderState.orders,
          );

          final twoPane = MasterDetailLayout.isTwoPane(context);
          final selected =
              (twoPane && filtered.isNotEmpty) ? _selectedFrom(filtered) : null;

          final master = _buildMasterPane(
            filtered: filtered,
            orders: orderState.orders,
            orderStats: orderState,
            dueThreshold: settingsState.dueDateWarningThreshold,
            selectedId: selected?.id,
            twoPane: twoPane,
          );

          Widget? detail;
          if (selected != null) {
            detail = CustomerDetailView(
              key: ValueKey(selected.id),
              customer: selected,
              onDeleted: () => setState(() => _selectedCustomerId = null),
            );
          }

          return MasterDetailLayout(
            master: master,
            detail: detail,
            placeholder: const MasterDetailPlaceholder(
              icon: Icons.people_outline,
              message: 'Select a customer to view their details',
            ),
          );
        },
      ),
    );
  }

  Widget _buildMasterPane({
    required List<Customer> filtered,
    required List<Order> orders,
    required OrderState orderStats,
    required int dueThreshold,
    required String? selectedId,
    required bool twoPane,
  }) {
    // A Scaffold per master pane so the create FAB sits at the bottom-right of
    // the list (left pane in two-pane mode), not over the detail pane.
    return Scaffold(
      body: Column(
        children: [
          FilterPresetChips(
            selectedPreset: _selectedPreset,
            onPresetSelected: _applyPreset,
          ),
          CustomerSortDropdown(
            selectedSort: _selectedSort,
            onSortChanged: (value) => setState(() => _selectedSort = value),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const EmptySearchState(message: 'No customers found')
                : CustomersListView(
                    customers: filtered,
                    allOrders: orders,
                    selectedCustomerId: selectedId,
                    dueDateWarningThreshold: dueThreshold,
                    statsFor: (id) => (
                      pending: orderStats.getPendingOrderCount(id),
                      ready: orderStats.getReadyOrderCount(id),
                      unpaid: orderStats.getTotalUnpaidAmount(id),
                    ),
                    onSelect: (customer) => _onCustomerTap(customer, twoPane),
                    onRefresh: _refreshCustomers,
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
}
