import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/backend.dart';
import '../domain/domain.dart';
import '../constants/app_constants.dart';
import '../presentation/presentation.dart';
import '../presentation/widgets/rich_description_input_field.dart';
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
  final _valueController = TextEditingController();
  final _descriptionKey = GlobalKey<RichDescriptionInputFieldState>();
  late final OrderFormController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OrderFormController(
      existingOrder: widget.order,
      initialCustomer: widget.customer,
    );
    _initializeTextControllers();
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCustomersIfNeeded();
    });
  }

  void _initializeTextControllers() {
    _titleController.text = _controller.title;
    _valueController.text = _controller.valueText;
  }

  void _onControllerChanged() {
    if (_valueController.text != _controller.valueText) {
      _valueController.text = _controller.valueText;
    }
    setState(() {});
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
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _titleController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_controller.hasUnsavedChanges || _controller.isLoading) {
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

  Future<void> _saveOrder() async {
    _controller.setHasAttemptedSubmit(true);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final validationError = _controller.validateForSave();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    _controller.setLoading(true);

    try {
      final state = context.read<OrderState>();
      final repository = context.read<OrderRepository>();
      final order = _controller.buildOrder();

      if (_controller.isEditing) {
        await OrderService.updateOrder(state, repository, order);
      } else {
        await OrderService.addOrder(state, repository, order);
      }

      if (mounted) {
        _controller.clearUnsavedChanges();

        if (_controller.isEditing) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacementNamed(
            context,
            AppConstants.orderDetailRoute,
            arguments: {'order': order, 'customer': _controller.selectedCustomer},
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 800),
            content: Text(
              _controller.isEditing
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
        _controller.setLoading(false);
      }
    }
  }

  Future<void> _handleCreateNewCustomer(CustomerState customerState) async {
    FocusScope.of(context).unfocus();
    final previousCount = customerState.customers.length;
    await Navigator.pushNamed(context, AppConstants.customerFormRoute);
    if (mounted && customerState.customers.length > previousCount) {
      final newCustomer = customerState.customers.last;
      _controller.setSelectedCustomer(newCustomer);
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
        appBar: CustomAppBar(
          title: Text(_controller.isEditing ? 'Edit Order' : 'Add Order'),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Consumer<CustomerState>(
            builder: (context, customerState, child) {
              return Column(
                children: [
                  Expanded(
                    child: OrderFormBody(
                      controller: _controller,
                      formKey: _formKey,
                      titleController: _titleController,
                      valueController: _valueController,
                      descriptionKey: _descriptionKey,
                      customers: customerState.customers,
                      onCreateNewCustomer: () => _handleCreateNewCustomer(customerState),
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
                    saveLabel: _controller.isEditing ? 'Update' : 'Save',
                    isLoading: _controller.isLoading,
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
