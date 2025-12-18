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

### Subtasks:
1. **Update Home Screen**
   - File: `app/lib/screens/home_screen.dart`
   - Add "Show Customers" navigation tile using Card or ListTile
   - Use Material 3 design with proper spacing (16-24px padding)
   - Add navigation to CustomersListScreen on tap
   - Use Icons.people or Icons.contacts for the tile icon

### Files to Modify:
- `app/lib/screens/home_screen.dart`

---

## Task 7: Create Customers List Screen

### Subtasks:
1. **Create Customers List Screen**
   - File: `app/lib/screens/customers_list_screen.dart`
   - Scaffold with AppBar titled "Customers"
   - Consumer widget to listen to CustomerState
   - Display loading, error, or list based on state
   - ListView.builder for customer list items
   - FloatingActionButton to navigate to Add Customer screen
   - Handle empty state with EmptyCustomersState widget
   - Pull-to-refresh functionality
   - Keep under 150 lines (split into sections if needed)

### Files to Create:
- `app/lib/screens/customers_list_screen.dart`

---

## Task 8: Create Customer Detail Screen

### Subtasks:
1. **Create Customer Detail Screen**
   - File: `app/lib/screens/customer_detail_screen.dart`
   - Accept Customer object as parameter
   - Scaffold with AppBar showing customer name
   - Display full customer information in Cards:
     - Name (with icon)
     - Phone Number (with icon and tap-to-call functionality)
     - Description (with icon, handle null/empty)
   - AppBar actions: Edit and Delete IconButtons
   - Confirmation dialog for delete action
   - Navigate back after delete
   - Use Material 3 spacing (16-24px)

### Files to Create:
- `app/lib/screens/customer_detail_screen.dart`

---

## Task 9: Create Add/Edit Customer Screen

### Subtasks:
1. **Create Customer Form Screen**
   - File: `app/lib/screens/customer_form_screen.dart`
   - Accept optional Customer parameter (null for add, Customer for edit)
   - Scaffold with AppBar titled "Add Customer" or "Edit Customer"
   - Form with GlobalKey for validation
   - TextFormFields for:
     - Name (required, with validator)
     - Phone Number (required, with validator, keyboard type: phone)
     - Description (optional, multiline)
   - Save button (validates and saves)
   - Cancel button (pops navigation)
   - Use domain validators for validation
   - Show loading indicator during save
   - Handle errors with SnackBar
   - Navigate back on success

### Files to Create:
- `app/lib/screens/customer_form_screen.dart`

---

## Task 10: Wire Up Navigation and State

### Subtasks:
1. **Update main.dart**
   - Initialize Hive in main() before runApp()
   - Wrap MaterialApp with MultiProvider
   - Provide CustomerState with ChangeNotifierProvider
   - Provide CustomerRepository instance
   - Load initial customers on app start

2. **Create Route Configuration**
   - File: `app/lib/config/routes.dart`
   - Define named routes for all screens
   - Create route generator function
   - Handle route arguments

3. **Update MaterialApp**
   - Add routes configuration
   - Set initial route
   - Add onGenerateRoute for dynamic routing

### Files to Modify:
- `app/lib/main.dart`

### Files to Create:
- `app/lib/config/routes.dart`

---

## Task 11: Testing and Verification

### Subtasks:
1. **Test on Android**
   - Run `flutter run -d android`
   - Test all CRUD operations
   - Verify data persistence (close and reopen app)
   - Test navigation flow
   - Verify Material 3 design

2. **Test on Web**
   - Run `flutter run -d chrome`
   - Test all CRUD operations
   - Verify data persistence (refresh page)
   - Test navigation flow
   - Verify responsive design

3. **Code Quality Checks**
   - Run `flutter analyze` - ensure no issues
   - Verify all files follow design principles:
     - Correct folder structure
     - No Flutter imports in domain layer
     - No business logic in presentation layer
     - Widgets under 150 lines
     - Config constants used (no magic numbers)
     - Repository pattern for data access
     - Barrel exports created

4. **Feature Verification Checklist**
   - [ ] Home screen has "Show Customers" navigation tile
   - [ ] Customers list displays all customers
   - [ ] FAB adds new customer
   - [ ] List items show name and phone preview
   - [ ] List items have View, Edit, Delete actions
   - [ ] Tapping customer navigates to detail screen
   - [ ] Empty state displays when no customers
   - [ ] Detail screen shows full customer info
   - [ ] Detail screen has Edit and Delete buttons
   - [ ] Form validates required fields
   - [ ] Form saves customer data
   - [ ] Data persists on Android
   - [ ] Data persists on Web
   - [ ] Loading states display correctly
   - [ ] Error handling works properly
   - [ ] Material 3 design applied throughout
   - [ ] 8-point grid spacing used

---

## Implementation Order Summary

1. **Setup** → Add dependencies, create config files
2. **Backend** → Models → Database → Repositories
3. **Domain** → State → Services → Validators
4. **Presentation** → Reusable widgets
5. **Screens** → Home → List → Detail → Form
6. **Integration** → Navigation → State management
7. **Testing** → Android → Web → Verification

---

## Key Architecture Decisions

### Database Choice: Hive
- **Why**: Cross-platform (Android, iOS, Web)
- **Why**: NoSQL key-value store, simple to use
- **Why**: No native dependencies, pure Dart
- **Why**: Fast and lightweight

### State Management: Provider + ChangeNotifier
- **Why**: Simple and follows Flutter best practices
- **Why**: Aligns with design principles (separate state from UI)
- **Why**: Easy to test and maintain

### Navigation: Named Routes
- **Why**: Clean separation of concerns
- **Why**: Easy to manage and scale
- **Why**: Type-safe with route arguments

---

## File Structure After Implementation

```
app/lib/
├── main.dart
├── backend/
│   ├── backend.dart (barrel export)
│   ├── models/
│   │   ├── index.dart
│   │   └── customer.dart
│   ├── database/
│   │   └── database_service.dart
│   └── repositories/
│       ├── customer_repository.dart
│       └── hive_customer_repository.dart
├── domain/
│   ├── domain.dart (barrel export)
│   ├── state/
│   │   └── customer_state.dart
│   ├── services/
│   │   └── customer_service.dart
│   └── validators/
│       └── customer_validators.dart
├── presentation/
│   ├── presentation.dart (barrel export)
│   └── widgets/
│       ├── customer_list_item.dart
│       ├── empty_customers_state.dart
│       ├── loading_widget.dart
│       └── error_widget.dart
├── screens/
│   ├── home_screen.dart (updated)
│   ├── customers_list_screen.dart
│   ├── customer_detail_screen.dart
│   └── customer_form_screen.dart
├── config/
│   ├── app_config.dart
│   └── routes.dart
└── constants/
    └── app_constants.dart
```

---

## Estimated Implementation Time

- Task 1: Setup and Configuration - 15 minutes
- Task 2: Create Data Models - 20 minutes
- Task 3: Implement Database Layer - 30 minutes
- Task 4: Create Domain Layer - 30 minutes
- Task 5: Build UI Components - 40 minutes
- Task 6: Implement Home Screen Navigation - 10 minutes
- Task 7: Create Customers List Screen - 30 minutes
- Task 8: Create Customer Detail Screen - 25 minutes
- Task 9: Create Add/Edit Customer Screen - 35 minutes
- Task 10: Wire Up Navigation and State - 25 minutes
- Task 11: Testing and Verification - 30 minutes

**Total: ~4.5 hours**

---

## Notes

- All async operations wrapped in try-catch blocks
- Loading states shown during async operations
- Errors displayed to user with SnackBars
- Confirmation dialogs for destructive actions (delete)
- Form validation before saving
- Data persistence verified on both platforms
- Material 3 design with seeded ColorScheme
- 8-point grid spacing throughout
- No test files created (as per requirements)


