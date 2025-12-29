import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../constants/app_constants.dart';
import '../../domain/services/order_service.dart';
import '../../domain/state/order_state.dart';
import '../../domain/state/main_shell_state.dart';
import '../../domain/models/filter_preset.dart';
import '../../domain/models/customer_filter_preset.dart';
import '../../presentation/presentation.dart';
import '../../presentation/widgets/home_action_tile.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

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
      appBar: CustomAppBar(
        title: const Text('Stitch Lane'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.pushNamed(context, AppConstants.settingsRoute);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
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
                final customersWithPendingCount =
                    OrderService.getCustomersWithPendingOrdersCount(orders);
                final unpaidAmount = OrderService.getTotalUnpaidAmount(orders);
                final theme = Theme.of(context);

                return Column(
                  children: [
                    _buildSummaryCard(
                      context: context,
                      theme: theme,
                      icon: Icons.pending_actions,
                      value: pendingCount.toString(),
                      label: 'Pending Orders',
                      color: theme.colorScheme.error,
                      onTap: () {
                        context.read<MainShellState>().switchToOrdersTab(
                          filter: FilterPreset.allPending(),
                        );
                      },
                    ),
                    const SizedBox(height: AppConfig.spacing8),
                    _buildSummaryCard(
                      context: context,
                      theme: theme,
                      icon: Icons.people_outline,
                      value: customersWithPendingCount.toString(),
                      label: 'Customers with Pending Orders',
                      color: theme.colorScheme.tertiary,
                      onTap: () {
                        context.read<MainShellState>().switchToCustomersTab(
                          filter: CustomerFilterPreset.pending(),
                        );
                      },
                    ),
                    const SizedBox(height: AppConfig.spacing8),
                    _buildSummaryCard(
                      context: context,
                      theme: theme,
                      icon: Icons.currency_rupee,
                      value: unpaidAmount.toString(),
                      label: 'Unpaid Amount',
                      color: theme.colorScheme.error,
                      onTap: () {
                        context.read<MainShellState>().switchToOrdersTab(
                          filter: FilterPreset.unpaid(),
                        );
                      },
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
                  isCreateAction: true,
                  onTap: () {
                    Navigator.pushNamed(context, AppConstants.orderFormRoute);
                  },
                ),
                HomeActionTile(
                  icon: Icons.person_add,
                  title: 'Create Customer',
                  isCreateAction: true,
                  onTap: () {
                    Navigator.pushNamed(context, AppConstants.customerFormRoute);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(label),
          trailing: const Icon(Icons.chevron_right, size: 20),
          dense: true,
        ),
      ),
    );
  }
}

