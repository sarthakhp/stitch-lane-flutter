import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/repositories/order_repository.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../domain/services/order_service.dart';
import '../domain/state/order_state.dart';
import '../presentation/widgets/dashboard_stats_card.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stitch Lane'),
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

                return Row(
                  children: [
                    Expanded(
                      child: DashboardStatsCard(
                        icon: Icons.pending_actions,
                        label: 'Pending Orders',
                        value: pendingCount.toString(),
                        valueColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(width: AppConfig.spacing16),
                    Expanded(
                      child: DashboardStatsCard(
                        icon: Icons.people_outline,
                        label: 'Customers Pending',
                        value: customersWithPendingCount.toString(),
                        valueColor: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                    const SizedBox(width: AppConfig.spacing16),
                    Expanded(
                      child: DashboardStatsCard(
                        icon: Icons.currency_rupee,
                        label: 'Unpaid Amount',
                        value: '$unpaidAmount',
                        valueColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppConfig.spacing24),
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppConstants.customersListRoute);
                },
                borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                child: Padding(
                  padding: const EdgeInsets.all(AppConfig.spacing24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people,
                        size: AppConfig.largeIconSize,
                        color: Theme
                            .of(context)
                            .colorScheme
                            .primary,
                      ),
                      const SizedBox(height: AppConfig.spacing16),
                      Text(
                        'Show Customers',
                        style: Theme
                            .of(context)
                            .textTheme
                            .titleLarge,
                      ),
                      const SizedBox(height: AppConfig.spacing8),
                      Text(
                        'Manage your customer list',
                        style: Theme
                            .of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          color: Theme
                              .of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConfig.spacing16),
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppConstants.allOrdersListRoute);
                },
                borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                child: Padding(
                  padding: const EdgeInsets.all(AppConfig.spacing24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.assignment,
                        size: AppConfig.largeIconSize,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: AppConfig.spacing16),
                      Text(
                        'Show Orders',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppConfig.spacing8),
                      Text(
                        'View all orders',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConfig.spacing16),
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppConstants.settingsRoute);
                },
                borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                child: Padding(
                  padding: const EdgeInsets.all(AppConfig.spacing24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.settings,
                        size: AppConfig.largeIconSize,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: AppConfig.spacing16),
                      Text(
                        'Settings',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppConfig.spacing8),
                      Text(
                        'Configure app preferences',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}