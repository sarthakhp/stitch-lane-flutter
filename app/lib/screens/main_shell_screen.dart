import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/repositories/order_repository.dart';
import '../backend/repositories/customer_repository.dart';
import '../constants/app_constants.dart';
import '../domain/services/notification_router.dart';
import '../domain/services/order_service.dart';
import '../domain/services/customer_service.dart';
import '../domain/services/permission_service.dart';
import '../domain/state/order_state.dart';
import '../domain/state/customer_state.dart';
import '../domain/state/main_shell_state.dart';
import '../utils/startup_orchestrator.dart';
import '../utils/startup_tracker.dart';
import 'tabs/home_tab.dart';
import 'tabs/orders_tab.dart';
import 'tabs/customers_tab.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen>
    with WidgetsBindingObserver {
  final _ordersTabKey = GlobalKey<OrdersTabState>();
  final _customersTabKey = GlobalKey<CustomersTabState>();

  // Lazily mount Orders/Customers tabs on first navigation.
  // Home (index 0) is always considered mounted.
  final Set<int> _mountedTabs = {0};

  @override
  void initState() {
    super.initState();
    StartupTracker.instance.markOnce('main_shell_init_state');
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StartupTracker.instance.markOnce('main_shell_first_frame');
      _loadInitialData();
      _requestPermissions();
      _processNotificationsWhenReady();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _processNotificationsWhenReady();
    }
  }

  Future<void> _requestPermissions() async {
    await PermissionService.requestAllPermissions();
  }

  /// Waits for NotificationService to finish initializing (in background since
  /// startup), then processes any pending notification tap that launched the app.
  Future<void> _processNotificationsWhenReady() async {
    await StartupOrchestrator.instance.notificationsReady;
    if (!mounted) return;
    NotificationRouter.processPendingNotification(context);
  }

  Future<void> _loadInitialData() async {
    final orderState = context.read<OrderState>();
    final orderRepository = context.read<OrderRepository>();
    final customerState = context.read<CustomerState>();
    final customerRepository = context.read<CustomerRepository>();

    await Future.wait([
      if (orderState.orders.isEmpty)
        OrderService.loadOrders(orderState, orderRepository),
      if (customerState.customers.isEmpty)
        CustomerService.loadCustomers(customerState, customerRepository),
    ]);
    StartupTracker.instance.finish();
  }

  void _onDestinationSelected(int index) {
    if (_mountedTabs.add(index)) {
      // First visit to this tab — trigger a rebuild so the real widget mounts.
      setState(() {});
    }
    context.read<MainShellState>().switchToTab(index);
  }

  void _applyPendingFilters(MainShellState shellState) {
    final ordersTabState = _ordersTabKey.currentState;
    if (ordersTabState != null) {
      final ordersFilter = shellState.consumeOrdersFilter();
      if (ordersFilter != null) {
        ordersTabState.applyFilter(ordersFilter);
      }
    }

    final customersTabState = _customersTabKey.currentState;
    if (customersTabState != null) {
      final customersFilter = shellState.consumeCustomersFilter();
      if (customersFilter != null) {
        customersTabState.applyFilter(customersFilter);
      }
    }
  }

  Widget? _buildFloatingActionButton(int selectedIndex) {
    switch (selectedIndex) {
      case 1:
        return FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, AppConstants.orderCreatorRoute);
          },
          child: const Icon(Icons.add),
        );
      case 2:
        return FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, AppConstants.customerFormRoute);
          },
          child: const Icon(Icons.add),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shellState = context.watch<MainShellState>();
    final selectedIndex = shellState.selectedIndex;
    final screenWidth = MediaQuery.of(context).size.width;
    final useNavigationRail = screenWidth >= 600;

    // Ensure the currently-selected tab is mounted. This covers programmatic
    // switches via MainShellState.switchToOrdersTab / switchToCustomersTab that
    // don't go through _onDestinationSelected.
    _mountedTabs.add(selectedIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyPendingFilters(shellState);
    });

    final body = IndexedStack(
      index: selectedIndex,
      children: [
        const HomeTab(),
        _mountedTabs.contains(1)
            ? OrdersTab(key: _ordersTabKey)
            : const SizedBox.shrink(),
        _mountedTabs.contains(2)
            ? CustomersTab(key: _customersTabKey)
            : const SizedBox.shrink(),
      ],
    );

    Widget scaffold;
    if (useNavigationRail) {
      scaffold = Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              groupAlignment: 0.0,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment),
                  label: Text('Orders'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outlined),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Customers'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: body),
          ],
        ),
        floatingActionButton: _buildFloatingActionButton(selectedIndex),
      );
    } else {
      scaffold = Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outlined),
              selectedIcon: Icon(Icons.people),
              label: 'Customers',
            ),
          ],
        ),
        floatingActionButton: _buildFloatingActionButton(selectedIndex),
      );
    }

    return PopScope(
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selectedIndex != 0) {
          shellState.switchToHomeTab();
        }
      },
      child: scaffold,
    );
  }
}

