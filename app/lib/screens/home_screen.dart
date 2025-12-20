import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/repositories/order_repository.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../domain/services/order_service.dart';
import '../domain/state/order_state.dart';
import '../domain/models/filter_preset.dart';
import '../domain/models/customer_filter_preset.dart';
import '../presentation/presentation.dart';
import '../presentation/widgets/home_action_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  Future<void> _loadOrders() async {
    final orderState = context.read<OrderState>();
    final orderRepository = context.read<OrderRepository>();

    if (orderState.orders.isEmpty) {
      await OrderService.loadOrders(orderState, orderRepository);
    }
  }

  int _getCrossAxisCount(double width) {
    if (width > 1200) return 4;
    if (width > 900) return 3;
    return 2;
  }

  double _getChildAspectRatio(double width) {
    if (width > 1200) return 1.0;
    if (width > 900) return 0.95;
    return 0.9;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = _getCrossAxisCount(screenWidth);
    final childAspectRatio = _getChildAspectRatio(screenWidth);

    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Stitch Lane'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Consumer<OrderState>(
              builder: (context, orderState, child) {
                final orders = orderState.orders;
                final pendingCount = OrderService.getPendingOrdersCount(orders);
                final customersWithPendingCount = OrderService.getCustomersWithPendingOrdersCount(orders);
                final unpaidAmount = OrderService.getTotalUnpaidAmount(orders);
                final theme = Theme.of(context);

                return Column(
                  children: [
                    Card(
                      elevation: 1,
                      child: InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppConstants.allOrdersListRoute,
                            arguments: {
                              'initialFilterPreset': FilterPreset.allPending(),
                            },
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          leading: Icon(
                            Icons.pending_actions,
                            color: theme.colorScheme.error,
                          ),
                          title: Text(
                            pendingCount.toString(),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: const Text('Pending Orders'),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          dense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConfig.spacing8),
                    Card(
                      elevation: 1,
                      child: InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppConstants.customersListRoute,
                            arguments: {
                              'initialFilterPreset': CustomerFilterPreset.pending(),
                            },
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          leading: Icon(
                            Icons.people_outline,
                            color: theme.colorScheme.tertiary,
                          ),
                          title: Text(
                            customersWithPendingCount.toString(),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: theme.colorScheme.tertiary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: const Text('Customers with Pending Orders'),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          dense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConfig.spacing8),
                    Card(
                      elevation: 1,
                      child: InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppConstants.allOrdersListRoute,
                            arguments: {
                              'initialFilterPreset': FilterPreset.unpaid(),
                            },
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          leading: Icon(
                            Icons.currency_rupee,
                            color: theme.colorScheme.error,
                          ),
                          title: Text(
                            unpaidAmount.toString(),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: const Text('Unpaid Amount'),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          dense: true,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppConfig.spacing24),
            GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppConfig.spacing16,
              crossAxisSpacing: AppConfig.spacing16,
              childAspectRatio: childAspectRatio,
              children: [
                HomeActionTile(
                  icon: Icons.note_add,
                  title: 'Create Order',
                  subtitle: 'Add a new order',
                  isCreateAction: true,
                  onTap: () {
                    Navigator.pushNamed(context, AppConstants.orderFormRoute);
                  },
                ),
                HomeActionTile(
                  icon: Icons.assignment,
                  title: 'Show Orders',
                  subtitle: 'View all orders',
                  onTap: () {
                    Navigator.pushNamed(context, AppConstants.allOrdersListRoute);
                  },
                ),
                HomeActionTile(
                  icon: Icons.person_add,
                  title: 'Create Customer',
                  subtitle: 'Add a new customer',
                  isCreateAction: true,
                  onTap: () {
                    Navigator.pushNamed(context, AppConstants.customerFormRoute);
                  },
                ),
                HomeActionTile(
                  icon: Icons.people,
                  title: 'Show Customers',
                  subtitle: 'Manage your customer list',
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppConstants.customersListRoute,
                      arguments: {'autoFocusSearch': true},
                    );
                  },
                ),
                HomeActionTile(
                  icon: Icons.settings,
                  title: 'Settings',
                  subtitle: 'Configure app preferences',
                  onTap: () {
                    Navigator.pushNamed(context, AppConstants.settingsRoute);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}