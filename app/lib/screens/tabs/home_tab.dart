import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../constants/app_constants.dart';
import '../../domain/services/order_service.dart';
import '../../domain/state/auth_state.dart';
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
              } else if (value == 'backup') {
                Navigator.pushNamed(context, AppConstants.backupSettingsRoute);
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
              const PopupMenuItem<String>(
                value: 'backup',
                child: ListTile(
                  leading: Icon(Icons.cloud_sync),
                  title: Text('Backup & Restore'),
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
            WelcomeHero(
              userName: context.watch<AuthState>().userName,
            ),
            const SizedBox(height: AppConfig.spacing16),
            Consumer<OrderState>(
              builder: (context, orderState, child) {
                final orders = orderState.orders;
                final pendingCount = OrderService.getPendingOrdersCount(orders);
                final customersWithPendingCount =
                    OrderService.getCustomersWithPendingOrdersCount(orders);
                final unpaidAmount = OrderService.getTotalUnpaidAmount(orders);
                final colorScheme = Theme.of(context).colorScheme;

                return Column(
                  children: [
                    SummaryCard(
                      icon: Icons.pending_actions,
                      value: pendingCount.toString(),
                      label: 'Pending Orders',
                      containerColor: colorScheme.errorContainer,
                      contentColor: colorScheme.onErrorContainer,
                      onTap: () {
                        context.read<MainShellState>().switchToOrdersTab(
                          filter: FilterPreset.allPending(),
                        );
                      },
                    ),
                    const SizedBox(height: AppConfig.spacing8),
                    SummaryCard(
                      icon: Icons.people_outline,
                      value: customersWithPendingCount.toString(),
                      label: 'Customers with Pending Orders',
                      containerColor: colorScheme.tertiaryContainer,
                      contentColor: colorScheme.onTertiaryContainer,
                      onTap: () {
                        context.read<MainShellState>().switchToCustomersTab(
                          filter: CustomerFilterPreset.pending(),
                        );
                      },
                    ),
                    const SizedBox(height: AppConfig.spacing8),
                    SummaryCard(
                      icon: Icons.currency_rupee,
                      value: '₹$unpaidAmount',
                      label: 'Unpaid Amount',
                      containerColor: colorScheme.secondaryContainer,
                      contentColor: colorScheme.onSecondaryContainer,
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
            Builder(
              builder: (context) {
                final colorScheme = Theme.of(context).colorScheme;
                return GridView.count(
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
                      containerColor: colorScheme.primaryContainer,
                      contentColor: colorScheme.onPrimaryContainer,
                      onTap: () {
                        Navigator.pushNamed(context, AppConstants.orderFormRoute);
                      },
                    ),
                    HomeActionTile(
                      icon: Icons.person_add,
                      title: 'Create Customer',
                      containerColor: colorScheme.secondaryContainer,
                      contentColor: colorScheme.onSecondaryContainer,
                      onTap: () {
                        Navigator.pushNamed(context, AppConstants.customerFormRoute);
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

