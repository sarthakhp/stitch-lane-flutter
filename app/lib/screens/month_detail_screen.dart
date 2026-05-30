import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/backend.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../domain/domain.dart';
import '../presentation/presentation.dart';

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

class MonthDetailScreen extends StatefulWidget {
  final int year;
  final int month;

  const MonthDetailScreen({
    super.key,
    required this.year,
    required this.month,
  });

  @override
  State<MonthDetailScreen> createState() => _MonthDetailScreenState();
}

class _MonthDetailScreenState extends State<MonthDetailScreen> {
  OrderStatusFilter _statusFilter = OrderStatusFilter.all;
  PaymentSortBy _sortBy = PaymentSortBy.date;
  SortDirection _sortDirection = SortDirection.descending;

  DateTime get _rangeStart => DateTime(widget.year, widget.month, 1);
  DateTime get _rangeEnd => DateTime(widget.year, widget.month + 1, 1);

  String get _monthLabel =>
      '${_monthNames[widget.month - 1]} ${widget.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text(_monthLabel)),
      body: Consumer2<OrderState, CustomerState>(
        builder: (context, orderState, customerState, _) {
          if (orderState.isLoading && orderState.orders.isEmpty) {
            return const LoadingWidget();
          }

          final orders = orderState.orders;
          final customers = customerState.customers;

          final kpis = BusinessAnalyticsService.kpisForRange(
            orders,
            customers,
            _rangeStart,
            _rangeEnd,
          );

          final records = BusinessAnalyticsService.paymentsInRange(
            orders,
            customers,
            _rangeStart,
            _rangeEnd,
            statusFilter: _statusFilter,
            sortBy: _sortBy,
            direction: _sortDirection,
          );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(AppConfig.spacing16),
                    sliver: SliverToBoxAdapter(
                      child: KpiGrid(kpis: kpis),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConfig.spacing16,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _buildControls(context),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppConfig.spacing12),
                  ),
                  if (records.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(context),
                    )
                  else
                    SliverList.separated(
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return PaymentRecordTile(
                          record: record,
                          onTap: () => _openOrder(context, record, customers),
                        );
                      },
                    ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppConfig.spacing24),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildStatusFilter()),
        const SizedBox(width: AppConfig.spacing12),
        _buildSortMenu(context),
      ],
    );
  }

  Widget _buildStatusFilter() {
    return Wrap(
      spacing: AppConfig.spacing8,
      children: [
        for (final filter in OrderStatusFilter.values)
          ChoiceChip(
            label: Text(_statusFilterLabel(filter)),
            selected: _statusFilter == filter,
            onSelected: (selected) {
              if (!selected) return;
              setState(() => _statusFilter = filter);
            },
          ),
      ],
    );
  }

  Widget _buildSortMenu(BuildContext context) {
    return PopupMenuButton<_SortChoice>(
      tooltip: 'Sort',
      icon: const Icon(Icons.sort),
      onSelected: (choice) {
        setState(() {
          _sortBy = choice.sortBy;
          _sortDirection = choice.direction;
        });
      },
      itemBuilder: (context) => [
        for (final choice in _SortChoice.all)
          CheckedPopupMenuItem(
            value: choice,
            checked: _sortBy == choice.sortBy &&
                _sortDirection == choice.direction,
            child: Text(choice.label),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppConfig.spacing24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppConfig.spacing12),
          Text(
            'No payments match these filters',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _openOrder(
    BuildContext context,
    PaymentRecord record,
    List<Customer> customers,
  ) {
    final customer = customers.firstWhere(
      (c) => c.id == record.order.customerId,
      orElse: () => Customer(
        id: record.order.customerId,
        name: record.customerName,
        created: DateTime.now(),
      ),
    );
    Navigator.pushNamed(
      context,
      AppConstants.orderDetailRoute,
      arguments: {'order': record.order, 'customer': customer},
    );
  }

  String _statusFilterLabel(OrderStatusFilter filter) {
    switch (filter) {
      case OrderStatusFilter.all:
        return 'All';
      case OrderStatusFilter.pending:
        return 'Pending';
      case OrderStatusFilter.ready:
        return 'Ready';
      case OrderStatusFilter.done:
        return 'Done';
    }
  }
}

class _SortChoice {
  final String label;
  final PaymentSortBy sortBy;
  final SortDirection direction;

  const _SortChoice(this.label, this.sortBy, this.direction);

  static const all = [
    _SortChoice('Date (newest first)', PaymentSortBy.date, SortDirection.descending),
    _SortChoice('Date (oldest first)', PaymentSortBy.date, SortDirection.ascending),
    _SortChoice('Amount (high to low)', PaymentSortBy.amount, SortDirection.descending),
    _SortChoice('Amount (low to high)', PaymentSortBy.amount, SortDirection.ascending),
    _SortChoice('Customer (A–Z)', PaymentSortBy.customerName, SortDirection.ascending),
    _SortChoice('Customer (Z–A)', PaymentSortBy.customerName, SortDirection.descending),
  ];
}
