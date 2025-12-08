# Customer Management Feature - Implementation Plan

## Overview
This plan outlines the step-by-step implementation of a customer management feature following the project's design principles and Material 3 guidelines.

---

## Task 1: Setup and Configuration

### Subtasks:
1. **Add Dependencies to pubspec.yaml**
   - Add `hive` and `hive_flutter` for cross-platform database (works on Android, iOS, and Web)
   - Add `uuid` for generating unique customer IDs
   - Add `provider` for state management

2. **Create Configuration Constants**
   - File: `app/lib/config/app_config.dart`
   - Define spacing constants (8, 16, 24, 32, 48)
   - Define animation durations
   - Define form validation rules

3. **Create App Constants**
   - File: `app/lib/constants/app_constants.dart`
   - Define database box names
   - Define route names for navigation

### Files to Create:
- `app/lib/config/app_config.dart`
- `app/lib/constants/app_constants.dart`

### Dependencies to Add:
```yaml
hive: ^2.2.3
hive_flutter: ^1.1.0
uuid: ^4.0.0
provider: ^6.1.0
```

---

## Task 2: Create Data Models

### Subtasks:
1. **Create Customer Model**
   - File: `app/lib/backend/models/customer.dart`
   - Fields: `id` (String), `name` (String), `phoneNumber` (String), `description` (String?)
   - Implement `toJson()` and `fromJson()` methods
   - Implement `copyWith()` method for immutability
   - Add Hive type adapter annotations

2. **Create Barrel Export**
   - File: `app/lib/backend/models/index.dart`
   - Export customer model

### Files to Create:
- `app/lib/backend/models/customer.dart`
- `app/lib/backend/models/index.dart`

---

## Task 3: Implement Database Layer

### Subtasks:
1. **Create Database Service**
   - File: `app/lib/backend/database/database_service.dart`
   - Initialize Hive
   - Register adapters
   - Open boxes
   - Platform-agnostic implementation

2. **Create Customer Repository Interface**
   - File: `app/lib/backend/repositories/customer_repository.dart`
   - Define abstract interface with methods:
     - `Future<List<Customer>> getAllCustomers()`
     - `Future<Customer?> getCustomerById(String id)`
     - `Future<void> addCustomer(Customer customer)`
     - `Future<void> updateCustomer(Customer customer)`
     - `Future<void> deleteCustomer(String id)`

3. **Create Hive Customer Repository Implementation**
   - File: `app/lib/backend/repositories/hive_customer_repository.dart`
   - Implement CustomerRepository interface
   - Use Hive box for storage
   - Add error handling with try-catch blocks

4. **Create Barrel Export**
   - File: `app/lib/backend/backend.dart`
   - Export models, repositories, database service

### Files to Create:
- `app/lib/backend/database/database_service.dart`
- `app/lib/backend/repositories/customer_repository.dart`
- `app/lib/backend/repositories/hive_customer_repository.dart`
- `app/lib/backend/backend.dart`

---

## Task 4: Create Domain Layer

### Subtasks:
1. **Create Customer State**
   - File: `app/lib/domain/state/customer_state.dart`
   - Extend ChangeNotifier
   - Fields: `List<Customer> customers`, `bool isLoading`, `String? error`
   - NO Flutter imports (pure Dart only)

2. **Create Customer Service**
   - File: `app/lib/domain/services/customer_service.dart`
   - Methods for CRUD operations that update state:
     - `loadCustomers(CustomerState state, CustomerRepository repo)`
     - `addCustomer(CustomerState state, CustomerRepository repo, Customer customer)`
     - `updateCustomer(CustomerState state, CustomerRepository repo, Customer customer)`
     - `deleteCustomer(CustomerState state, CustomerRepository repo, String id)`
   - Handle loading states and errors
   - NO Flutter imports

3. **Create Form Validators**
   - File: `app/lib/domain/validators/customer_validators.dart`
   - `validateName(String? value)` - required, min 2 characters
   - `validatePhoneNumber(String? value)` - required, valid format
   - Pure Dart functions

4. **Create Barrel Export**
   - File: `app/lib/domain/domain.dart`
   - Export state, services, validators

### Files to Create:
- `app/lib/domain/state/customer_state.dart`
- `app/lib/domain/services/customer_service.dart`
- `app/lib/domain/validators/customer_validators.dart`
- `app/lib/domain/domain.dart`

---

## Task 5: Build UI Components

### Subtasks:
1. **Create Customer List Item Widget**
   - File: `app/lib/presentation/widgets/customer_list_item.dart`
   - Display: name, phone preview
   - Action buttons: View, Edit, Delete icons
   - Use Material 3 ListTile
   - Keep under 150 lines

2. **Create Empty State Widget**
   - File: `app/lib/presentation/widgets/empty_customers_state.dart`
   - Display when no customers exist
   - Show icon and message
   - Use theme colors

3. **Create Loading Widget**
   - File: `app/lib/presentation/widgets/loading_widget.dart`
   - Centered CircularProgressIndicator
   - Reusable across screens

4. **Create Error Widget**
   - File: `app/lib/presentation/widgets/error_widget.dart`
   - Display error message
   - Retry button option

5. **Create Barrel Export**
   - File: `app/lib/presentation/presentation.dart`
   - Export all widgets

### Files to Create:
- `app/lib/presentation/widgets/customer_list_item.dart`
- `app/lib/presentation/widgets/empty_customers_state.dart`
- `app/lib/presentation/widgets/loading_widget.dart`
- `app/lib/presentation/widgets/error_widget.dart`
- `app/lib/presentation/presentation.dart`

---

## Task 6: Implement Home Screen Navigation

