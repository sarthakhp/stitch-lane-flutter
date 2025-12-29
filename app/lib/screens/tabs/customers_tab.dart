import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/domain.dart';
import '../../backend/backend.dart';
import '../../presentation/presentation.dart';
import '../../constants/app_constants.dart';
import '../../utils/utils.dart';

class CustomersTab extends StatefulWidget {
  const CustomersTab({super.key});

  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  String _searchQuery = '';
  CustomerSort _selectedSort = CustomerSort.dueDate;
  CustomerFilterOptions _filterOptions = const CustomerFilterOptions();
  CustomerFilterPreset? _selectedPreset;

  Future<void> _loadCustomers() async {
    final state = context.read<CustomerState>();
    final repository = context.read<CustomerRepository>();
    await CustomerService.loadCustomers(state, repository);
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

  Future<void> _openFilterDialog() async {
    final result = await showDialog<CustomerFilterOptions>(
      context: context,
      builder: (context) => CustomerFilterDialog(
        initialOptions: _filterOptions,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _filterOptions = result;
        _selectedPreset = _findMatchingPreset(result);
      });
    }
  }

  CustomerFilterPreset? _findMatchingPreset(CustomerFilterOptions options) {
    for (final preset in CustomerFilterPreset.allPresets) {
      if (preset.options == options) {
        return preset;
      }
    }
    return null;
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
    var filteredCustomers = List<Customer>.from(
      SearchHelper.filterCustomers(customers, _searchQuery),
    );

    if (_filterOptions.isFilterActive) {
      filteredCustomers = filteredCustomers.where((customer) {
        return _filterOptions.matchesCustomer(customer, orders);
      }).toList();
    }

    return CustomerSortHelper.sortCustomersWithMode(
      filteredCustomers,
      orders,
      _selectedSort,
      _filterOptions.sortMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: const Text('Customers'),
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
          ),
        ),
      ),
      body: Column(
        children: [
          FilterPresetChips(
            selectedPreset: _selectedPreset,
            onPresetSelected: _applyPreset,
          ),
          CustomerSortDropdown(
            selectedSort: _selectedSort,
            onSortChanged: (value) {
              setState(() {
                _selectedSort = value;
              });
            },
          ),
          Expanded(
            child: Consumer2<CustomerState, OrderState>(
              builder: (context, customerState, orderState, child) {
                if (customerState.isLoading && customerState.customers.isEmpty) {
                  return const LoadingWidget();
                }

                if (customerState.error != null && customerState.customers.isEmpty) {
                  return ErrorDisplayWidget(
                    message: customerState.error!,
                    onRetry: _loadCustomers,
                  );
                }

                if (customerState.customers.isEmpty) {
                  return const EmptyCustomersState();
                }

                final filteredCustomers = _getFilteredAndSortedCustomers(
                  customerState.customers,
                  orderState.orders,
                );

                if (filteredCustomers.isEmpty) {
                  return const EmptySearchState(message: 'No customers found');
                }

                return NotificationListener<ScrollNotification>(
                  onNotification: (scrollNotification) {
                    if (scrollNotification is ScrollStartNotification) {
                      FocusScope.of(context).unfocus();
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    onRefresh: _loadCustomers,
                    child: ListView.builder(
                      itemCount: filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = filteredCustomers[index];

                        return CustomerListItem(
                          customer: customer,
                          pendingOrderCount: orderState.getPendingOrderCount(customer.id),
                          readyOrderCount: orderState.getReadyOrderCount(customer.id),
                          totalUnpaidAmount: orderState.getTotalUnpaidAmount(customer.id),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              AppConstants.customerDetailRoute,
                              arguments: customer,
                            );
                          },
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

