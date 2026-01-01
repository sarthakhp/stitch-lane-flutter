import 'package:flutter/material.dart';
import '../../../backend/models/customer.dart';
import '../../../config/app_config.dart';
import '../../../domain/state/order_form_controller.dart';
import '../customer_autocomplete_field.dart';
import '../extracted_values_widget.dart';
import '../order_images_section.dart';
import '../rich_description_input_field.dart';
import 'order_due_date_field.dart';
import 'order_title_field.dart';
import 'order_value_field.dart';

class OrderFormBody extends StatelessWidget {
  final OrderFormController controller;
  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController valueController;
  final GlobalKey<RichDescriptionInputFieldState> descriptionKey;
  final List<Customer> customers;
  final VoidCallback onCreateNewCustomer;

  const OrderFormBody({
    super.key,
    required this.controller,
    required this.formKey,
    required this.titleController,
    required this.valueController,
    required this.descriptionKey,
    required this.customers,
    required this.onCreateNewCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        children: [
          _buildCustomerField(),
          const SizedBox(height: AppConfig.spacing16),
          OrderTitleField(
            controller: titleController,
            enabled: !controller.isLoading,
            onChanged: () => controller.setTitle(titleController.text),
          ),
          const SizedBox(height: AppConfig.spacing16),
          _buildDescriptionField(),
          const SizedBox(height: AppConfig.spacing16),
          _buildExtractedValues(),
          OrderValueField(
            controller: valueController,
            enabled: !controller.isLoading,
            onChanged: () => controller.setValueText(valueController.text),
          ),
          const SizedBox(height: AppConfig.spacing16),
          OrderDueDateField(
            selectedDate: controller.dueDate,
            enabled: !controller.isLoading,
            isEditing: controller.isEditing,
            showError: controller.hasAttemptedSubmit && controller.dueDate == null,
            onDateSelected: controller.setDueDate,
          ),
          const SizedBox(height: AppConfig.spacing16),
          _buildImagesSection(),
        ],
      ),
    );
  }

  Widget _buildCustomerField() {
    return CustomerAutocompleteField(
      customers: customers,
      selectedCustomer: controller.selectedCustomer,
      enabled: !controller.isEditing && !controller.isLoading,
      hasError: controller.hasAttemptedSubmit && controller.selectedCustomer == null,
      onCustomerSelected: controller.setSelectedCustomer,
      onCustomerCleared: () => controller.setSelectedCustomer(null),
      onCreateNewCustomer: onCreateNewCustomer,
    );
  }

  Widget _buildDescriptionField() {
    return RichDescriptionInputField(
      key: descriptionKey,
      initialValue: controller.description,
      labelText: 'Description (Optional)',
      hintText: 'Enter order description',
      enabled: !controller.isLoading,
      onChanged: controller.setDescription,
    );
  }

  Widget _buildExtractedValues() {
    if (controller.extractedValues.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        ExtractedValuesWidget(
          values: controller.extractedValues,
          onApply: controller.applyExtractedTotal,
        ),
        const SizedBox(height: AppConfig.spacing16),
      ],
    );
  }

  Widget _buildImagesSection() {
    return OrderImagesSection(
      imagePaths: controller.imagePaths,
      onImagesChanged: controller.setImagePaths,
    );
  }
}

