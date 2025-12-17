import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/customers_list_screen.dart';
import '../screens/customer_detail_screen.dart';
import '../screens/customer_form_screen.dart';
import '../screens/orders_list_screen.dart';
import '../screens/order_detail_screen.dart';
import '../screens/order_form_screen.dart';
import '../screens/settings_screen.dart';
import '../backend/backend.dart';
import '../constants/app_constants.dart';

class AppRoutes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppConstants.loginRoute:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );

      case AppConstants.homeRoute:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        );

      case AppConstants.customersListRoute:
        return MaterialPageRoute(
          builder: (_) => const CustomersListScreen(),
        );

      case AppConstants.customerDetailRoute:
        final customer = settings.arguments as Customer?;
        if (customer == null) {
          return _errorRoute('Customer data is required');
        }
        return MaterialPageRoute(
          builder: (_) => CustomerDetailScreen(customer: customer),
        );

      case AppConstants.customerFormRoute:
        final customer = settings.arguments as Customer?;
        return MaterialPageRoute(
          builder: (_) => CustomerFormScreen(customer: customer),
        );

      case AppConstants.ordersListRoute:
        final customer = settings.arguments as Customer?;
        if (customer == null) {
          return _errorRoute('Customer data is required');
        }
        return MaterialPageRoute(
          builder: (_) => OrdersListScreen(customer: customer),
        );

      case AppConstants.allOrdersListRoute:
        return MaterialPageRoute(
          builder: (_) => const OrdersListScreen(customer: null),
        );

      case AppConstants.orderDetailRoute:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args == null || args['order'] == null || args['customer'] == null) {
          return _errorRoute('Order and customer data are required');
        }
        return MaterialPageRoute(
          builder: (_) => OrderDetailScreen(
            order: args['order'] as Order,
            customer: args['customer'] as Customer,
          ),
        );

      case AppConstants.orderFormRoute:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => OrderFormScreen(
            customer: args?['customer'] as Customer?,
            order: args?['order'] as Order?,
          ),
        );

      case AppConstants.settingsRoute:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        );

      default:
        return _errorRoute('Route not found: ${settings.name}');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Text(message),
        ),
      ),
    );
  }
}

