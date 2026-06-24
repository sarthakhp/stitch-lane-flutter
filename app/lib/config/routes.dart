import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/backup_restore_check_screen.dart';
import '../screens/customers_list_screen.dart';
import '../screens/customer_detail_screen.dart';
import '../screens/customer_form_screen.dart';
import '../screens/orders_list_screen.dart';
import '../screens/order_detail_screen.dart';
import '../screens/order_creator_screen.dart';
import '../screens/order_form_screen.dart';
import '../screens/measurements_list_screen.dart';
import '../screens/measurement_detail_screen.dart';
import '../screens/measurement_form_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/notification_settings_screen.dart';
import '../screens/measurement_fields_screen.dart';
import '../screens/customer_recordings_screen.dart';
import '../screens/backup_settings_screen.dart';
import '../screens/ai_usage_screen.dart';
import '../screens/developer_screen.dart';
	import '../screens/business_analysis_screen.dart';
import '../screens/month_detail_screen.dart';
import '../screens/ai_assistant_screen.dart';
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
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => BackupRestoreCheckScreen(
            hasBackup: args?['hasBackup'] as bool?,
            errorMessage: args?['errorMessage'] as String?,
            alreadyChecked: args?['alreadyChecked'] as bool? ?? false,
          ),
        );

      // NOTE: there is intentionally no pushable route for the home shell.
      // The shell lives as the auth gate's body (AppRoot), so it is always the
      // single root route. Pushing a second MainShellScreen here would stack a
      // duplicate shell and leave the home tab with a stray back arrow — to
      // return home, pop to the first route instead (see WidgetLaunchCoordinator
      // / sign-out flows).

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
            initialDescription: args?['initialDescription'] as String?,
          ),
        );

      case AppConstants.orderCreatorRoute:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => OrderCreatorScreen(
            initialCustomer: args?['customer'] as Customer?,
            autoStartVoice: args?['autoStartVoice'] as bool? ?? false,
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

      case AppConstants.profileRoute:
        return MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
        );

      case AppConstants.notificationSettingsRoute:
        return MaterialPageRoute(
          builder: (_) => const NotificationSettingsScreen(),
        );

      case AppConstants.measurementFieldsRoute:
        return MaterialPageRoute(
          builder: (_) => const MeasurementFieldsScreen(),
        );

      case AppConstants.customerRecordingsRoute:
        final customer = settings.arguments as Customer?;
        if (customer == null) {
          return _errorRoute('Customer data is required');
        }
        return MaterialPageRoute(
          builder: (_) => CustomerRecordingsScreen(customer: customer),
        );

      case AppConstants.backupSettingsRoute:
        return MaterialPageRoute(
          builder: (_) => const BackupSettingsScreen(),
        );

      case AppConstants.developerRoute:
        return MaterialPageRoute(
          builder: (_) => const DeveloperScreen(),
        );

      case AppConstants.aiUsageRoute:
        return MaterialPageRoute(
          builder: (_) => const AiUsageScreen(),
        );

	      case AppConstants.businessAnalysisRoute:
	        return MaterialPageRoute(
	          builder: (_) => const BusinessAnalysisScreen(),
	        );

      case AppConstants.monthDetailRoute:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args == null || args['year'] == null || args['month'] == null) {
          return _errorRoute('Year and month are required');
        }
        return MaterialPageRoute(
          builder: (_) => MonthDetailScreen(
            year: args['year'] as int,
            month: args['month'] as int,
          ),
        );

      case AppConstants.aiAssistantRoute:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => AiAssistantScreen(
            autoStartVoice: args?['autoStartVoice'] as bool? ?? false,
          ),
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

