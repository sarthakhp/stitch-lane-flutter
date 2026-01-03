import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../backend/backend.dart';
import '../domain/domain.dart';
import '../presentation/presentation.dart';

class BusinessAnalysisScreen extends StatelessWidget {
  const BusinessAnalysisScreen({super.key});

  int _getPaidTotalInRange(
    List<Order> orders,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    return orders.fold(0, (sum, order) {
      final paidInRange = order.payments.fold(0, (paymentSum, payment) {
        if (!payment.date.isBefore(rangeStart) &&
            payment.date.isBefore(rangeEnd)) {
          return paymentSum + payment.amount;
        }
        return paymentSum;
      });

      return sum + paidInRange;
    });
  }

  String _getMonthYearLabel(int year, int month) {
    const monthNames = [
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

    return '${monthNames[month - 1]} $year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Business Analysis'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Consumer<OrderState>(
          builder: (context, orderState, child) {
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

            final now = DateTime.now();
            final firstDayThisMonth = DateTime(now.year, now.month, 1);
            final firstDayNextMonth = DateTime(now.year, now.month + 1, 1);
            final firstDayLastMonth = DateTime(now.year, now.month - 1, 1);

            final totalPaidThisMonth = _getPaidTotalInRange(
              orderState.orders,
              firstDayThisMonth,
              firstDayNextMonth,
            );

            final totalPaidLastMonth = _getPaidTotalInRange(
              orderState.orders,
              firstDayLastMonth,
              firstDayThisMonth,
            );

            final thisMonthLabel = _getMonthYearLabel(
              firstDayThisMonth.year,
              firstDayThisMonth.month,
            );

            final lastMonthLabel = _getMonthYearLabel(
              firstDayLastMonth.year,
              firstDayLastMonth.month,
            );

            final colorScheme = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConfig.spacing24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This month ($thisMonthLabel)',
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppConfig.spacing8),
                        Text(
                          '\u20b9$totalPaidThisMonth',
                          style: textTheme.displaySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppConfig.spacing24),
                        const Divider(),
                        const SizedBox(height: AppConfig.spacing24),
                        Text(
                          'Last month ($lastMonthLabel)',
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppConfig.spacing8),
                        Text(
                          '\u20b9$totalPaidLastMonth',
                          style: textTheme.displaySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
