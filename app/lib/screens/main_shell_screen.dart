import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/repositories/order_repository.dart';
import '../backend/repositories/customer_repository.dart';
import '../constants/app_constants.dart';
import '../domain/services/order_service.dart';
import '../domain/services/customer_service.dart';
import '../domain/services/permission_service.dart';
import '../domain/state/order_state.dart';
import '../domain/state/customer_state.dart';
import '../main.dart' show processPendingNotification;
import 'tabs/home_tab.dart';
import 'tabs/orders_tab.dart';
import 'tabs/customers_tab.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      _requestPermissions();
      processPendingNotification();
    });
  }

  Future<void> _requestPermissions() async {
    await PermissionService.requestAllPermissions();
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
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget? _buildFloatingActionButton() {
    switch (_selectedIndex) {
      case 1:
        return FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, AppConstants.orderFormRoute);
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
    final screenWidth = MediaQuery.of(context).size.width;
    final useNavigationRail = screenWidth >= 600;

    final body = IndexedStack(
      index: _selectedIndex,
      children: const [
        HomeTab(),
        OrdersTab(),
        CustomersTab(),
      ],
    );

    if (useNavigationRail) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              labelType: NavigationRailLabelType.all,
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
        floatingActionButton: _buildFloatingActionButton(),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
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
      floatingActionButton: _buildFloatingActionButton(),
    );
  }
}

