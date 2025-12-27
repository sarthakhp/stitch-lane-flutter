import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/backup_restore_check_screen.dart';
import '../screens/home_screen.dart';
import '../screens/customers_list_screen.dart';
import '../screens/customer_detail_screen.dart';
import '../screens/customer_form_screen.dart';
import '../screens/orders_list_screen.dart';
import '../screens/order_detail_screen.dart';
import '../screens/order_form_screen.dart';
import '../screens/measurements_list_screen.dart';
import '../screens/measurement_detail_screen.dart';
import '../screens/measurement_form_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/notification_settings_screen.dart';
import '../backend/backend.dart';
import '../constants/app_constants.dart';

class AppRoutes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppConstants.loginRoute:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );

      case AppConstants.backupRestoreCheckRoute:
        return MaterialPageRoute(
          builder: (_) => const BackupRestoreCheckScreen(),
        );

      case AppConstants.homeRoute:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        );

      case AppConstants.customersListRoute:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => CustomersListScreen(
            initialFilterPreset: args?['initialFilterPreset'],
            autoFocusSearch: args?['autoFocusSearch'] ?? false,
          ),
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
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => OrdersListScreen(
            customer: null,
            initialFilterPreset: args?['initialFilterPreset'],
          ),
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

      case AppConstants.measurementsListRoute:
        final customer = settings.arguments as Customer?;
        if (customer == null) {
          return _errorRoute('Customer data is required');
        }
        return MaterialPageRoute(
          builder: (_) => MeasurementsListScreen(customer: customer),
        );

      case AppConstants.measurementDetailRoute:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args == null || args['measurement'] == null || args['customer'] == null) {
          return _errorRoute('Measurement and customer data are required');
        }
        return MaterialPageRoute(
          builder: (_) => MeasurementDetailScreen(
            measurement: args['measurement'] as Measurement,
            customer: args['customer'] as Customer,
          ),
        );

      case AppConstants.measurementFormRoute:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args == null || args['customer'] == null) {
          return _errorRoute('Customer data is required');
        }
        return MaterialPageRoute(
          builder: (_) => MeasurementFormScreen(
            customer: args['customer'] as Customer,
            measurement: args['measurement'] as Measurement?,
          ),
        );

      case AppConstants.settingsRoute:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        );

      case AppConstants.notificationSettingsRoute:
        return MaterialPageRoute(
          builder: (_) => const NotificationSettingsScreen(),
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

