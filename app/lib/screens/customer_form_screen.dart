import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../backend/backend.dart';
import '../domain/domain.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../presentation/widgets/sticky_bottom_action_bar.dart';

class CustomerFormScreen extends StatefulWidget {
  final Customer? customer;

  const CustomerFormScreen({
    super.key,
    this.customer,
  });

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  bool _importedFromContacts = false;

  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.customer!.name;
      _phoneController.text = widget.customer!.phoneNumber ?? '';
      _descriptionController.text = widget.customer!.description ?? '';
    }
    _nameController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
    if (_importedFromContacts) {
      setState(() {
        _importedFromContacts = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _phoneController.removeListener(_onFieldChanged);
    _descriptionController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _importFromContacts() async {
    if (!ContactsService.isContactsAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contacts are not available on this platform'),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final contactData = await ContactsService.pickContact();

      if (contactData != null && mounted) {
        setState(() {
          _nameController.text = contactData.name;
          _phoneController.text = contactData.phoneNumber;
          _importedFromContacts = true;
          _hasUnsavedChanges = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(milliseconds: 700),
            content: Text('Contact imported successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import contact: $e')),
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

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final state = context.read<CustomerState>();
      final repository = context.read<CustomerRepository>();

      final phoneText = _phoneController.text.trim();
      final descriptionText = _descriptionController.text.trim();

      final customer = Customer(
        id: _isEditing ? widget.customer!.id : const Uuid().v4(),
        name: _nameController.text.trim(),
        phoneNumber: phoneText.isEmpty ? null : phoneText,
        description: descriptionText.isEmpty ? null : descriptionText,
        created: _isEditing ? widget.customer!.created : DateTime.now(),
      );

      if (_isEditing) {
        await CustomerService.updateCustomer(state, repository, customer);
      } else {
        await CustomerService.addCustomer(state, repository, customer);

        if (!_importedFromContacts && phoneText.isNotEmpty) {
          try {
            await ContactsService.saveToContacts(
              _nameController.text.trim(),
              phoneText,
            );
          } catch (e) {
            // Silently fail - don't block customer save
          }
        }
      }

      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
        });

        if (_isEditing) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: Duration(milliseconds: 700),
              content: Text('Customer updated successfully'),
            ),
          );
        } else {
          Navigator.pop(context);
          Navigator.pushNamed(
            context,
            AppConstants.customerDetailRoute,
            arguments: customer,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: Duration(milliseconds: 700),
              content: Text('Customer added successfully'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save customer: $e')),
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
          title: Text(_isEditing ? 'Edit Customer' : 'Add Customer'),
        ),
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(AppConfig.spacing16),
                    children: [
            if (!_isEditing && ContactsService.isContactsAvailable) ...[
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _importFromContacts,
                icon: const Icon(Icons.contacts),
                label: const Text('Import from Contacts'),
              ),
              const SizedBox(height: AppConfig.spacing16),
            ],
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter customer name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: CustomerValidators.validateName,
              textInputAction: TextInputAction.next,
              enabled: !_isLoading,
            ),
            const SizedBox(height: AppConfig.spacing16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number (Optional)',
                hintText: 'Enter phone number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: CustomerValidators.validatePhoneNumber,
              textInputAction: TextInputAction.next,
              enabled: !_isLoading,
            ),
            const SizedBox(height: AppConfig.spacing16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Enter customer description',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: CustomerValidators.validateDescription,
              textInputAction: TextInputAction.newline,
              enabled: !_isLoading,
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
                onSave: _saveCustomer,
                saveLabel: _isEditing ? 'Update' : 'Save',
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

