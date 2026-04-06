import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../backend/backend.dart';
import '../../../config/app_config.dart';
import '../../../domain/services/ai_chat_models.dart';

class AiComponentCard extends StatefulWidget {
  final UiComponent component;
  final VoidCallback onTap;

  const AiComponentCard({super.key, required this.component, required this.onTap});

  @override
  State<AiComponentCard> createState() => _AiComponentCardState();
}

class _AiComponentCardState extends State<AiComponentCard> {
  String? _title;
  final _details = <String>[];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (widget.component.type == 'customer') {
        await _loadCustomerData();
      } else {
        await _loadOrderData();
      }
    } catch (_) {
      // Silently fail — card just won't show
    }
  }

  Future<void> _loadCustomerData() async {
    final customerRepo = context.read<CustomerRepository>();
    final orderRepo = context.read<OrderRepository>();
    final customer = await customerRepo.getCustomerById(widget.component.id);
    if (customer == null || !mounted) return;

    final orders = await orderRepo.getOrdersByCustomerId(customer.id);
    final pending = orders.where((o) => o.status == OrderStatus.pending).length;
    final ready = orders.where((o) => o.status == OrderStatus.ready).length;
    final unpaid = orders
        .where((o) => !o.isPaid)
        .fold<int>(0, (sum, o) => sum + o.value - o.totalPaidAmount);

    setState(() {
      _title = customer.name;
      if (pending > 0) _details.add('$pending pending');
      if (ready > 0) _details.add('$ready ready');
      if (unpaid > 0) _details.add('₹$unpaid unpaid');
      _loaded = true;
    });
  }

  Future<void> _loadOrderData() async {
    final orderRepo = context.read<OrderRepository>();
    final customerRepo = context.read<CustomerRepository>();
    final order = await orderRepo.getOrderById(widget.component.id);
    if (order == null || !mounted) return;

    final customer = await customerRepo.getCustomerById(order.customerId);
    final dueDateStr = '${order.dueDate.day}/${order.dueDate.month}/${order.dueDate.year}';

    setState(() {
      _title = customer?.name ?? 'Order';
      if (order.title != null && order.title!.trim().isNotEmpty) {
        _details.add(order.title!);
      }
      _details.add('₹${order.value}');
      _details.add('Due $dueDateStr');
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCustomer = widget.component.type == 'customer';

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(AppConfig.spacing12),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCustomer ? Icons.person : Icons.receipt_long,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const Spacer(),
                Icon(
                  Icons.open_in_new,
                  size: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: AppConfig.spacing8),
            Text(
              _title ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            for (final detail in _details)
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
