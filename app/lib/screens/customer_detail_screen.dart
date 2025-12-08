import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/backend.dart';
import '../domain/domain.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late String _customerId;

  @override
  void initState() {
    super.initState();
    _customerId = widget.customer.id;
  }

  Future<void> _deleteCustomer(BuildContext context, String customerId) async {
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

    if (confirmed == true && context.mounted) {
      try {
        final customerState = context.read<CustomerState>();
        final customerRepository = context.read<CustomerRepository>();
        final orderState = context.read<OrderState>();
        final orderRepository = context.read<OrderRepository>();
        await CustomerService.deleteCustomer(
          customerState,
          customerRepository,
          customerId,
          orderState: orderState,
          orderRepository: orderRepository,
        );
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete customer: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerState>(
      builder: (context, customerState, child) {
        final customer = customerState.customers.firstWhere(
          (c) => c.id == _customerId,
          orElse: () => widget.customer,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(customer.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppConstants.customerFormRoute,
                    arguments: customer,
                  );
                },
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _deleteCustomer(context, _customerId),
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConfig.spacing16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: AppConfig.spacing16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Name',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              const SizedBox(height: AppConfig.spacing8),
                              Text(
                                customer.name,
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
            if (customer.phoneNumber != null && customer.phoneNumber!.isNotEmpty) ...[
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
                            Icons.phone,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: AppConfig.spacing16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Phone Number',
                                  style: Theme.of(context).textTheme.labelMedium,
                                ),
                                const SizedBox(height: AppConfig.spacing8),
                                Text(
                                  customer.phoneNumber!,
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
            if (customer.description != null && customer.description!.isNotEmpty) ...[
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
                            Icons.description,
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
                                  customer.description!,
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
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Consumer<OrderState>(
                    builder: (context, orderState, child) {
                      final customerOrders = orderState.orders
                          .where((order) => order.customerId == customer.id)
                          .toList();
                      final orderCount = customerOrders.length;

                      return SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppConstants.ordersListRoute,
                              arguments: customer,
                            );
                          },
                          icon: Badge(
                            label: Text('$orderCount'),
                            isLabelVisible: orderCount > 0,
                            child: const Icon(Icons.assignment),
                          ),
                          label: const Text('View Orders'),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

