import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../backend/backend.dart';
import '../domain/domain.dart';
import '../presentation/presentation.dart';

const _monthsToShow = 6;

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class BusinessAnalysisScreen extends StatelessWidget {
  const BusinessAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: Text('Business Analysis')),
      body: Consumer<OrderState>(
        builder: (context, orderState, _) {
          if (orderState.isLoading && orderState.orders.isEmpty) {
            return const LoadingWidget();
          }

          if (orderState.error != null && orderState.orders.isEmpty) {
            return ErrorDisplayWidget(
              message: orderState.error!,
              onRetry: () {
                final repository = context.read<OrderRepository>();
                OrderService.loadOrders(orderState, repository);
              },
            );
          }

          final orders = orderState.orders;
          final outstanding = BusinessAnalyticsService.outstanding(orders);
          final months = BusinessAnalyticsService.monthlyTotals(
            orders,
            monthsBack: _monthsToShow,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppConfig.spacing16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutstandingCard(summary: outstanding),
                    const SizedBox(height: AppConfig.spacing16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppConfig.spacing8,
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < months.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              MonthTile(
                                label: _labelFor(i, months[i]),
                                summary: months[i],
                                onTap: () => _openMonth(context, months[i]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _labelFor(int index, MonthSummary summary) {
    final label = '${_monthNames[summary.month - 1]} ${summary.year}';
    return index == 0 ? 'This month ($label)' : label;
  }

  void _openMonth(BuildContext context, MonthSummary summary) {
    Navigator.pushNamed(
      context,
      AppConstants.monthDetailRoute,
      arguments: {
        'year': summary.year,
        'month': summary.month,
      },
    );
  }
}
