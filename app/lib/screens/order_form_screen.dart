import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../backend/backend.dart';
import '../domain/domain.dart';
import '../config/app_config.dart';
import '../presentation/widgets/sticky_bottom_action_bar.dart';

class OrderFormScreen extends StatefulWidget {
  final Order? order;
  final Customer? customer;

  const OrderFormScreen({
    super.key,
    this.order,
    this.customer,
  });

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _valueController = TextEditingController();
  DateTime? _selectedDueDate;
  bool _isLoading = false;
  bool _isPaid = false;
  Customer? _selectedCustomer;
  bool _hasAttemptedSubmit = false;
  bool _hasUnsavedChanges = false;

  bool get _isEditing => widget.order != null;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.customer;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCustomersIfNeeded();
    });
    if (_isEditing) {
      _titleController.text = widget.order!.title ?? '';
      _descriptionController.text = widget.order!.description ?? '';
      _valueController.text = widget.order!.value.toString();
      _isPaid = widget.order!.isPaid;
      _selectedDueDate = widget.order!.dueDate;
    } else {
      _valueController.text = '0';
      _isPaid = false;
      _selectedDueDate = DateTime.now();
    }
    _titleController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _valueController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _loadCustomersIfNeeded() async {
    final customerState = context.read<CustomerState>();
    if (customerState.customers.isEmpty) {
      final customerRepository = context.read<CustomerRepository>();
      await CustomerService.loadCustomers(customerState, customerRepository);
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onFieldChanged);
    _descriptionController.removeListener(_onFieldChanged);
    _valueController.removeListener(_onFieldChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges || _isLoading) {
      return true;
    }

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Do you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y').format(date);
  }

  Future<void> _selectDueDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDueDate ?? now;
    final firstDate = _isEditing ? DateTime(2000) : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _saveOrder() async {
    setState(() {
      _hasAttemptedSubmit = true;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    if (_selectedDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a due date')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final state = context.read<OrderState>();
      final repository = context.read<OrderRepository>();

      final titleText = _titleController.text.trim();
      final descriptionText = _descriptionController.text.trim();
      final valueInt = int.parse(_valueController.text.trim());

      final order = Order(
        id: _isEditing ? widget.order!.id : const Uuid().v4(),
        customerId: _selectedCustomer!.id,
        title: titleText.isEmpty ? null : titleText,
        dueDate: _selectedDueDate!,
        description: descriptionText.isEmpty ? null : descriptionText,
        created: _isEditing ? widget.order!.created : DateTime.now(),
        status: _isEditing ? widget.order!.status : OrderStatus.pending,
        value: valueInt,
        isPaid: _isPaid,
      );

      if (_isEditing) {
        await OrderService.updateOrder(state, repository, order);
      } else {
        await OrderService.addOrder(state, repository, order);
      }

      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 800),
            content: Text(
              _isEditing
                  ? 'Order updated successfully'
                  : 'Order added successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save order: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        FocusManager.instance.primaryFocus?.unfocus();
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Order' : 'Add Order'),
        ),
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Consumer<CustomerState>(
            builder: (context, customerState, child) {
              return Column(
                children: [
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(AppConfig.spacing16),
                        children: [
                DropdownMenu<Customer>(
                  width: MediaQuery.of(context).size.width - (AppConfig.spacing16 * 2),
                  enabled: !_isEditing && !_isLoading,
                  label: const Text('Customer'),
                  hintText: 'Search and select customer...',
                  enableFilter: true,
                  enableSearch: true,
                  requestFocusOnTap: true,
                  leadingIcon: const Icon(Icons.person),
                  initialSelection: _selectedCustomer,
                  errorText: _hasAttemptedSubmit && _selectedCustomer == null
                      ? 'Please select a customer'
                      : null,
                  onSelected: (Customer? customer) {
                    setState(() {
                      _selectedCustomer = customer;
                      _hasUnsavedChanges = true;
                    });
                  },
                  dropdownMenuEntries: customerState.customers.map((customer) {
                    return DropdownMenuEntry<Customer>(
                      value: customer,
                      label: customer.name,
                      labelWidget: ListTile(
                        title: Text(customer.name),
                        subtitle: customer.phoneNumber != null
                            ? Text(customer.phoneNumber!)
                            : const Text('No phone'),
                        dense: true,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppConfig.spacing16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title (Optional)',
                    hintText: 'Enter order title',
                    prefixIcon: Icon(Icons.assignment),
                    border: OutlineInputBorder(),
                  ),
                  validator: OrderValidators.validateTitle,
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading,
                ),
            const SizedBox(height: AppConfig.spacing16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Enter order description',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
              validator: OrderValidators.validateDescription,
              maxLines: 3,
              textInputAction: TextInputAction.newline,
              enabled: !_isLoading,
            ),
            const SizedBox(height: AppConfig.spacing16),
            TextFormField(
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'Order Value',
                hintText: 'Enter order value',
                prefixIcon: Icon(Icons.currency_rupee),
                border: OutlineInputBorder(),
                helperText: 'Enter positive, negative, or zero value',
              ),
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: false),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a value';
                }
                final intValue = int.tryParse(value.trim());
                if (intValue == null) {
                  return 'Please enter a valid integer';
                }
                return null;
              },
              textInputAction: TextInputAction.next,
              enabled: !_isLoading,
            ),
            const SizedBox(height: AppConfig.spacing16),
            InkWell(
              onTap: _isLoading ? null : _selectDueDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Due Date',
                  hintText: 'Select due date',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: const OutlineInputBorder(),
                  errorText: _selectedDueDate == null && _formKey.currentState?.validate() == false
                      ? 'Due date is required'
                      : null,
                ),
                child: Text(
                  _selectedDueDate != null
                      ? _formatDate(_selectedDueDate!)
                      : 'Tap to select date',
                  style: _selectedDueDate != null
                      ? Theme.of(context).textTheme.bodyLarge
                      : Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                ),
              ),
            ),
            const SizedBox(height: AppConfig.spacing16),
            Card(
              child: SwitchListTile(
                title: const Text('Payment Status'),
                subtitle: Text(_isPaid ? 'Paid' : 'Not Paid'),
                value: _isPaid,
                onChanged: _isLoading ? null : (value) {
                  setState(() {
                    _isPaid = value;
                    _hasUnsavedChanges = true;
                  });
                },
                secondary: Icon(
                  _isPaid ? Icons.check_circle : Icons.pending,
                  color: _isPaid
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ],
                      ),
                    ),
                  ),
                  StickyBottomActionBar(
                    onCancel: () async {
                      final shouldPop = await _onWillPop();
                      if (shouldPop && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    onSave: _saveOrder,
                    saveLabel: _isEditing ? 'Update' : 'Save',
                    isLoading: _isLoading,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

