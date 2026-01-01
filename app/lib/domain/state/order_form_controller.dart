import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../backend/models/customer.dart';
import '../../backend/models/order.dart';
import '../../backend/models/order_status.dart';
import '../../backend/models/payment_entry.dart';
import '../services/money_extractor.dart';

class OrderFormController extends ChangeNotifier {
  final Order? existingOrder;
  final Customer? initialCustomer;

  String _title = '';
  String _description = '';
  String _valueText = '';
  DateTime? _dueDate;
  Customer? _selectedCustomer;
  List<String> _imagePaths = [];
  List<PaymentEntry> _payments = [];
  int _totalPaidAmount = 0;
  bool _isPaid = false;
  DateTime? _paymentDate;
  bool _isLoading = false;
  bool _hasAttemptedSubmit = false;
  bool _hasUnsavedChanges = false;
  List<double> _extractedValues = [];

  OrderFormController({this.existingOrder, this.initialCustomer}) {
    _initializeFromOrder();
  }

  bool get isEditing => existingOrder != null;
  String get title => _title;
  String get description => _description;
  String get valueText => _valueText;
  DateTime? get dueDate => _dueDate;
  Customer? get selectedCustomer => _selectedCustomer;
  List<String> get imagePaths => List.unmodifiable(_imagePaths);
  List<PaymentEntry> get payments => List.unmodifiable(_payments);
  int get totalPaidAmount => _totalPaidAmount;
  bool get isPaid => _isPaid;
  DateTime? get paymentDate => _paymentDate;
  bool get isLoading => _isLoading;
  bool get hasAttemptedSubmit => _hasAttemptedSubmit;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  List<double> get extractedValues => List.unmodifiable(_extractedValues);

  void _initializeFromOrder() {
    _selectedCustomer = initialCustomer;
    
    if (existingOrder != null) {
      _title = existingOrder!.title ?? '';
      _description = existingOrder!.description ?? '';
      _valueText = existingOrder!.value.toString();
      _dueDate = existingOrder!.dueDate;
      _imagePaths = List.from(existingOrder!.imagePaths);
      _payments = List.from(existingOrder!.payments);
      _totalPaidAmount = existingOrder!.totalPaidAmount;
      _isPaid = existingOrder!.isPaid;
      _paymentDate = existingOrder!.paymentDate;
      _extractedValues = MoneyExtractor.extractValues(_description);
    }
  }

  void setTitle(String value) {
    if (_title != value) {
      _title = value;
      _markChanged();
    }
  }

  void setDescription(String value) {
    if (_description != value) {
      _description = value;
      _extractedValues = MoneyExtractor.extractValues(value);
      _markChanged();
    }
  }

  void setValueText(String value) {
    if (_valueText != value) {
      _valueText = value;
      _markChanged();
    }
  }

  void setDueDate(DateTime? value) {
    if (_dueDate != value) {
      _dueDate = value;
      _markChanged();
    }
  }

  void setSelectedCustomer(Customer? value) {
    if (_selectedCustomer != value) {
      _selectedCustomer = value;
      _markChanged();
    }
  }

  void setImagePaths(List<String> value) {
    _imagePaths = List.from(value);
    _markChanged();
  }

  void applyExtractedTotal() {
    final total = MoneyExtractor.calculateTotal(_extractedValues);
    _valueText = total.toInt().toString();
    notifyListeners();
  }

  void updatePayments(Order updatedOrder) {
    _payments = List.from(updatedOrder.payments);
    _totalPaidAmount = updatedOrder.totalPaidAmount;
    _isPaid = updatedOrder.isPaid;
    _paymentDate = updatedOrder.paymentDate;
    _markChanged();
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setHasAttemptedSubmit(bool value) {
    _hasAttemptedSubmit = value;
    notifyListeners();
  }

  void clearUnsavedChanges() {
    _hasUnsavedChanges = false;
  }

  void _markChanged() {
    if (!_hasUnsavedChanges) {
      _hasUnsavedChanges = true;
    }
    notifyListeners();
  }

  int? get parsedValue => int.tryParse(_valueText.trim());

  bool get isCustomerValid => _selectedCustomer != null;
  bool get isDueDateValid => _dueDate != null;
  bool get isValueValid => _valueText.trim().isNotEmpty && parsedValue != null;

  String? validateForSave() {
    if (!isCustomerValid) return 'Please select a customer';
    if (!isDueDateValid) return 'Please select a due date';
    if (!isValueValid) return 'Please enter order value';
    return null;
  }

  Order buildOrder() {
    final titleText = _title.trim();
    final descriptionText = _description.trim();
    final valueInt = parsedValue ?? 0;

    return Order(
      id: isEditing ? existingOrder!.id : const Uuid().v4(),
      customerId: _selectedCustomer!.id,
      title: titleText.isEmpty ? null : titleText,
      dueDate: _dueDate!,
      description: descriptionText.isEmpty ? null : descriptionText,
      created: isEditing ? existingOrder!.created : DateTime.now(),
      status: isEditing ? existingOrder!.status : OrderStatus.pending,
      value: valueInt,
      isPaid: _isPaid,
      paymentDate: _paymentDate,
      imagePaths: _imagePaths,
      payments: _payments,
      totalPaidAmount: _totalPaidAmount,
    );
  }

  Order buildCurrentOrder() {
    final valueInt = parsedValue ?? 0;
    return Order(
      id: existingOrder?.id ?? '',
      customerId: _selectedCustomer?.id ?? '',
      title: _title.trim().isEmpty ? null : _title.trim(),
      dueDate: _dueDate ?? DateTime.now(),
      description: _description.trim().isEmpty ? null : _description.trim(),
      created: existingOrder?.created ?? DateTime.now(),
      status: existingOrder?.status ?? OrderStatus.pending,
      value: valueInt,
      isPaid: _isPaid,
      paymentDate: _paymentDate,
      imagePaths: _imagePaths,
      payments: _payments,
      totalPaidAmount: _totalPaidAmount,
    );
  }
}

