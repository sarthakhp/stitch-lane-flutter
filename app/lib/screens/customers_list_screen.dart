import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/domain.dart';
import '../backend/backend.dart';
import '../presentation/presentation.dart';
import '../constants/app_constants.dart';
import '../utils/utils.dart';

class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({super.key});

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  String _searchQuery = '';

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

  Future<void> _deleteCustomer(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: const Text('Are you sure you want to delete this customer?'),
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

    if (confirmed == true && mounted) {
      try {
        final customerState = context.read<CustomerState>();
        final customerRepository = context.read<CustomerRepository>();
        final orderState = context.read<OrderState>();
        final orderRepository = context.read<OrderRepository>();
        await CustomerService.deleteCustomer(
          customerState,
          customerRepository,
          id,
          orderState: orderState,
          orderRepository: orderRepository,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete customer: $e')),
          );
        }
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: SearchBarWidget(
            hintText: 'Search customers...',
            onSearchChanged: _onSearchChanged,
            onClear: _onClearSearch,
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
          )..sort((a, b) => b.created.compareTo(a.created));

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

