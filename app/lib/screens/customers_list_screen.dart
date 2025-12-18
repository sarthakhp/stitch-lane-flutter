import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stitch_lane_app/utils/app_logger.dart';
import '../domain/domain.dart';
import '../backend/backend.dart';
import '../presentation/presentation.dart';
import '../constants/app_constants.dart';
import '../utils/utils.dart';

enum CustomerSort {
  dueDate,
  orderCount,
  pendingAmount,
}

class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({super.key});

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  String _searchQuery = '';
  CustomerSort _selectedSort = CustomerSort.dueDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final customerState = context.read<CustomerState>();
    final customerRepository = context.read<CustomerRepository>();
    final orderState = context.read<OrderState>();
    final orderRepository = context.read<OrderRepository>();

    await Future.wait([
      CustomerService.loadCustomers(customerState, customerRepository),
      OrderService.loadOrders(orderState, orderRepository),
    ]);
  }

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

  DateTime? _getEarliestDueDate(String customerId, List<Order> orders) {
    final customerOrders = orders
        .where((order) => order.customerId == customerId && order.status == OrderStatus.pending)
        .toList();

    if (customerOrders.isEmpty) return null;


    customerOrders.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return customerOrders.first.dueDate;
  }

  int _getOrderCount(String customerId, List<Order> orders) {
    return orders.where((order) => order.customerId == customerId).length;
  }

  int _getTotalPendingAmount(String customerId, List<Order> orders) {
    return orders
        .where((order) => order.customerId == customerId && !order.isPaid)
        .fold(0, (sum, order) => sum + order.value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              SearchBarWidget(
                hintText: 'Search customers...',
                onSearchChanged: _onSearchChanged,
                onClear: _onClearSearch,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.sort, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<CustomerSort>(
                          value: _selectedSort,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: CustomerSort.dueDate,
                              child: Text('Sort by: Due Date'),
                            ),
                            DropdownMenuItem(
                              value: CustomerSort.orderCount,
                              child: Text('Sort by: Pending Orders'),
                            ),
                            DropdownMenuItem(
                              value: CustomerSort.pendingAmount,
                              child: Text('Sort by: Pending Amount'),
                            ),
                          ],
                          onChanged: (CustomerSort? value) {
                            if (value != null) {
                              setState(() {
                                _selectedSort = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Consumer2<CustomerState, OrderState>(
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

          final filteredCustomers = List<Customer>.from(
            SearchHelper.filterCustomers(
              customerState.customers,
              _searchQuery,
            ),
          );

          final orders = orderState.orders;

          switch (_selectedSort) {
            case CustomerSort.dueDate:
              filteredCustomers.sort((a, b) {
                final aDueDate = _getEarliestDueDate(a.id, orders);
                final bDueDate = _getEarliestDueDate(b.id, orders);

                if (aDueDate == null && bDueDate == null) return 0;
                if (aDueDate == null) return 1;
                if (bDueDate == null) return -1;

                return aDueDate.compareTo(bDueDate);
              });
              break;
            case CustomerSort.orderCount:
              filteredCustomers.sort((a, b) {
                final aCount = _getOrderCount(a.id, orders);
                final bCount = _getOrderCount(b.id, orders);
                return bCount.compareTo(aCount);
              });
              break;
            case CustomerSort.pendingAmount:
              filteredCustomers.sort((a, b) {
                final aAmount = _getTotalPendingAmount(a.id, orders);
                final bAmount = _getTotalPendingAmount(b.id, orders);
                return bAmount.compareTo(aAmount);
              });
              break;
          }

          if (filteredCustomers.isEmpty) {
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
                    'No customers found',
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
            onRefresh: _loadCustomers,
            child: ListView.builder(
              itemCount: filteredCustomers.length,
              itemBuilder: (context, index) {
                final customer = filteredCustomers[index];

                return CustomerListItem(
                  customer: customer,
                  pendingOrderCount: orderState.getPendingOrderCount(customer.id),
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, AppConstants.customerFormRoute);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

