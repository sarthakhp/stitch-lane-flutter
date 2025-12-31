import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../backend/models/order.dart';
import '../../backend/models/payment_entry.dart';
import '../../config/app_config.dart';
import 'confirmation_dialog.dart';

class PaymentsSection extends StatefulWidget {
  final Order order;
  final ValueChanged<Order> onOrderUpdated;

  const PaymentsSection({
    super.key,
    required this.order,
    required this.onOrderUpdated,
  });

  @override
  State<PaymentsSection> createState() => _PaymentsSectionState();
}

class _PaymentsSectionState extends State<PaymentsSection> {
  String? _editingPaymentId;
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y').format(date);
  }

  int _calculateTotalPaid() {
    return widget.order.payments.fold(0, (sum, p) => sum + p.amount);
  }

  int _getRemainingAmount() {
    final remaining = widget.order.value - _calculateTotalPaid();
    return remaining > 0 ? remaining : 0;
  }

  void _addNewPayment() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final newPayment = PaymentEntry(
      id: const Uuid().v4(),
      date: today,
      amount: _getRemainingAmount(),
    );

    final updatedPayments = [...widget.order.payments, newPayment];
    final totalPaid = updatedPayments.fold(0, (sum, p) => sum + p.amount);
    final isPaid = totalPaid >= widget.order.value;

    widget.onOrderUpdated(widget.order.copyWith(
      payments: updatedPayments,
      totalPaidAmount: totalPaid,
      isPaid: isPaid,
    ));
  }

  Future<void> _deletePayment(PaymentEntry payment) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete Payment',
      content: 'Are you sure you want to delete this payment of ₹${payment.amount}?',
    );

    if (!confirmed || !mounted) return;

    final updatedPayments = widget.order.payments.where((p) => p.id != payment.id).toList();
    final totalPaid = updatedPayments.fold(0, (sum, p) => sum + p.amount);
    final isPaid = totalPaid >= widget.order.value;

    widget.onOrderUpdated(widget.order.copyWith(
      payments: updatedPayments,
      totalPaidAmount: totalPaid,
      isPaid: isPaid,
    ));
  }

  Future<void> _editDate(PaymentEntry payment) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final newDate = await showDatePicker(
      context: context,
      initialDate: payment.date,
      firstDate: DateTime(2000),
      lastDate: today,
    );

    if (newDate == null || !mounted) return;

    _updatePayment(payment.copyWith(date: newDate));
  }

  void _startEditingAmount(PaymentEntry payment) {
    setState(() {
      _editingPaymentId = payment.id;
      _amountController.text = payment.amount.toString();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _amountFocusNode.requestFocus();
      _amountController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _amountController.text.length,
      );
    });
  }

  void _finishEditingAmount(PaymentEntry payment) {
    final newAmount = int.tryParse(_amountController.text) ?? payment.amount;
    setState(() {
      _editingPaymentId = null;
    });
    if (newAmount != payment.amount && newAmount >= 0) {
      _updatePayment(payment.copyWith(amount: newAmount));
    }
  }

  void _updatePayment(PaymentEntry updatedPayment) {
    final updatedPayments = widget.order.payments.map((p) {
      return p.id == updatedPayment.id ? updatedPayment : p;
    }).toList();
    final totalPaid = updatedPayments.fold(0, (sum, p) => sum + p.amount);
    final isPaid = totalPaid >= widget.order.value;

    widget.onOrderUpdated(widget.order.copyWith(
      payments: updatedPayments,
      totalPaidAmount: totalPaid,
      isPaid: isPaid,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalPaid = _calculateTotalPaid();
    final remaining = widget.order.value - totalPaid;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, colorScheme, totalPaid, remaining),
            if (widget.order.payments.isNotEmpty) ...[
              const SizedBox(height: AppConfig.spacing12),
              _buildPaymentsList(context, colorScheme),
            ],
            const SizedBox(height: AppConfig.spacing12),
            _buildAddButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme,
    int totalPaid,
    int remaining,
  ) {
    return Row(
      children: [
        Icon(Icons.payments, color: colorScheme.primary),
        const SizedBox(width: AppConfig.spacing16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payments',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: AppConfig.spacing4),
              Text(
                '₹$totalPaid paid${remaining > 0 ? ' • ₹$remaining remaining' : ''}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: remaining > 0 ? colorScheme.error : colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentsList(BuildContext context, ColorScheme colorScheme) {
    return Column(
      children: widget.order.payments.map((payment) {
        return _buildPaymentRow(context, colorScheme, payment);
      }).toList(),
    );
  }

  Widget _buildPaymentRow(
    BuildContext context,
    ColorScheme colorScheme,
    PaymentEntry payment,
  ) {
    final isEditing = _editingPaymentId == payment.id;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConfig.spacing4),
      child: Row(
        children: [
          InkWell(
            onTap: () => _editDate(payment),
            borderRadius: BorderRadius.circular(AppConfig.spacing4),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConfig.spacing8,
                vertical: AppConfig.spacing4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppConfig.spacing4),
                  Text(
                    _formatDate(payment.date),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppConfig.spacing8),
          Expanded(
            child: isEditing
                ? _buildAmountEditor(payment)
                : _buildAmountDisplay(context, colorScheme, payment),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: colorScheme.error,
              size: 20,
            ),
            onPressed: () => _deletePayment(payment),
            tooltip: 'Delete payment',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildAmountDisplay(
    BuildContext context,
    ColorScheme colorScheme,
    PaymentEntry payment,
  ) {
    return InkWell(
      onTap: () => _startEditingAmount(payment),
      borderRadius: BorderRadius.circular(AppConfig.spacing4),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConfig.spacing8,
          vertical: AppConfig.spacing4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₹${payment.amount}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppConfig.spacing4),
            Icon(
              Icons.edit,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountEditor(PaymentEntry payment) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 100,
          child: TextField(
            controller: _amountController,
            focusNode: _amountFocusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              prefixText: '₹',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppConfig.spacing8,
                vertical: AppConfig.spacing8,
              ),
            ),
            onSubmitted: (_) => _finishEditingAmount(payment),
          ),
        ),
        const SizedBox(width: AppConfig.spacing4),
        IconButton(
          icon: Icon(
            Icons.check_circle,
            color: Theme.of(context).colorScheme.primary,
          ),
          onPressed: () => _finishEditingAmount(payment),
          tooltip: 'Confirm',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _addNewPayment,
        icon: const Icon(Icons.add),
        label: const Text('Add Payment'),
      ),
    );
  }
}

