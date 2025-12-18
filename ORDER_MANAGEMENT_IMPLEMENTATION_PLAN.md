# Order Management Feature - Implementation Plan

**Created:** December 7, 2025  
**Feature:** Order Management with Customer-Order Relationship  
**Estimated Time:** ~5-6 hours

---

## 📋 Overview

This plan details the implementation of an Order Management feature that integrates with the existing Customer Management system. Orders are linked to customers via a one-to-many relationship (each customer can have multiple orders).

---

## 🎯 Feature Requirements Summary

1. **Order Data Model** - id, customerId, title, dueDate with Hive persistence
2. **Customer-Order Relationship** - One-to-many with cascade delete handling
3. **Customer Detail Enhancement** - Add Orders button with count badge
4. **Orders List Screen** - Display customer's orders with CRUD actions
5. **Order Detail Screen** - View full order information
6. **Add/Edit Order Screen** - Form with title and due date validation
7. **Backend Layer** - Repository pattern with Hive persistence
8. **Domain Layer** - State management and business logic
9. **Presentation Layer** - Reusable UI components
10. **Navigation** - Route configuration and state integration
11. **Configuration** - Constants for validation and database
12. **State Management** - Provider integration in main.dart

---

## 📁 Files to Create/Modify

### New Files (17 files)

**Configuration (0 new, 2 modified)**
- Modify: `app/lib/config/app_config.dart`
- Modify: `app/lib/constants/app_constants.dart`

**Backend Layer (5 new, 2 modified)**
- Create: `app/lib/backend/models/order.dart`
- Create: `app/lib/backend/models/order.g.dart` (generated)
- Create: `app/lib/backend/repositories/order_repository.dart`
- Create: `app/lib/backend/repositories/hive_order_repository.dart`
- Modify: `app/lib/backend/models/index.dart`
- Modify: `app/lib/backend/database/database_service.dart`
- Modify: `app/lib/backend/backend.dart`

**Domain Layer (3 new, 2 modified)**
- Create: `app/lib/domain/state/order_state.dart`
- Create: `app/lib/domain/services/order_service.dart`
- Create: `app/lib/domain/validators/order_validators.dart`
- Modify: `app/lib/domain/services/customer_service.dart`
- Modify: `app/lib/domain/domain.dart`

**Presentation Layer (2 new, 1 modified)**
- Create: `app/lib/presentation/widgets/order_list_item.dart`
- Create: `app/lib/presentation/widgets/empty_orders_state.dart`
- Modify: `app/lib/presentation/presentation.dart`

**Screens (3 new, 1 modified)**
- Create: `app/lib/screens/orders_list_screen.dart`
- Create: `app/lib/screens/order_detail_screen.dart`
- Create: `app/lib/screens/order_form_screen.dart`
- Modify: `app/lib/screens/customer_detail_screen.dart`

**Main App (2 modified)**
- Modify: `app/lib/config/routes.dart`
- Modify: `app/lib/main.dart`

---

## 🔢 Implementation Tasks (12 Main Tasks, 35 Subtasks)

### Task 1: Setup and Configuration (2 subtasks)

**1.1 Update app_config.dart**
- Add validation constants:
  ```dart
  static const int minTitleLength = 2;
  static const int maxTitleLength = 100;
  ```

**1.2 Update app_constants.dart**
- Add database box name:
  ```dart
  static const String ordersBoxName = 'orders_box';
  ```
- Add route constants:
  ```dart
  static const String ordersListRoute = '/customer/orders';
  static const String orderDetailRoute = '/order/detail';
  static const String orderFormRoute = '/order/form';
  ```

---

### Task 2: Create Data Models (3 subtasks)

**2.1 Create order.dart model**
- File: `app/lib/backend/models/order.dart`
- Define Order class with Hive annotations:
  ```dart
  @HiveType(typeId: 1)
  class Order {
    @HiveField(0) final String id;
    @HiveField(1) final String customerId;
    @HiveField(2) final String title;
    @HiveField(3) final DateTime dueDate;
  ```
- Include: toJson/fromJson, copyWith, equals, hashCode
- Follow same pattern as Customer model

**2.2 Generate Hive adapter**
- Run: `flutter pub run build_runner build --delete-conflicting-outputs`
- Generates: `app/lib/backend/models/order.g.dart`

**2.3 Update models barrel export**
- File: `app/lib/backend/models/index.dart`
- Add: `export 'order.dart';`

---

### Task 3: Implement Database Layer (4 subtasks)

**3.1 Update database_service.dart**
- File: `app/lib/backend/database/database_service.dart`
- Register OrderAdapter in initialize():
  ```dart
  Hive.registerAdapter(OrderAdapter());
  await Hive.openBox<Order>(AppConstants.ordersBoxName);
  ```
- Add getOrdersBox() method

**3.2 Create order_repository.dart interface**
- File: `app/lib/backend/repositories/order_repository.dart`
- Define abstract methods:
  - `Future<List<Order>> getAllOrders()`
  - `Future<List<Order>> getOrdersByCustomerId(String customerId)`
  - `Future<Order?> getOrderById(String id)`
  - `Future<void> addOrder(Order order)`
  - `Future<void> updateOrder(Order order)`
  - `Future<void> deleteOrder(String id)`
  - `Future<void> deleteOrdersByCustomerId(String customerId)`

**3.3 Create hive_order_repository.dart**
- File: `app/lib/backend/repositories/hive_order_repository.dart`
- Implement OrderRepository using Hive
- Add error handling with try-catch blocks
- Use DatabaseService.getOrdersBox()

**3.4 Update backend barrel export**
- File: `app/lib/backend/backend.dart`
- Add exports:
  ```dart
  export 'models/order.dart';
  export 'repositories/order_repository.dart';
  export 'repositories/hive_order_repository.dart';
  ```

---

### Task 4: Create Domain Layer (4 subtasks)

**4.1 Create order_state.dart**
- File: `app/lib/domain/state/order_state.dart`
- Extend ChangeNotifier
- Fields: `List<Order> orders`, `bool isLoading`, `String? error`
- Methods: setOrders, setLoading, setError, addOrder, updateOrder, removeOrder, clearError
- NO Flutter imports (except foundation for ChangeNotifier)

**4.2 Create order_service.dart**
- File: `app/lib/domain/services/order_service.dart`
- Static methods:
  - `loadOrders(OrderState, OrderRepository)`
  - `loadOrdersByCustomerId(OrderState, OrderRepository, String customerId)`
  - `addOrder(OrderState, OrderRepository, Order)`
  - `updateOrder(OrderState, OrderRepository, Order)`
  - `deleteOrder(OrderState, OrderRepository, String id)`
- NO Flutter imports

**4.3 Create order_validators.dart**
- File: `app/lib/domain/validators/order_validators.dart`
- Pure Dart validation functions:
  - `validateTitle(String? value)` - Required, 2-100 chars
  - `validateDueDate(DateTime? value, {bool isEdit = false})` - Required, not in past for new orders

**4.4 Update domain barrel export**
- File: `app/lib/domain/domain.dart`
- Add exports for OrderState, OrderService, OrderValidators

---

### Task 5: Build UI Components (3 subtasks)

**5.1 Create order_list_item.dart**
- File: `app/lib/presentation/widgets/order_list_item.dart`
- Display order title and due date
- Format date consistently (e.g., "Dec 7, 2025")
- Include View, Edit, Delete action buttons
- Use Card with ListTile
- Follow Material 3 design with AppConfig spacing

**5.2 Create empty_orders_state.dart**
- File: `app/lib/presentation/widgets/empty_orders_state.dart`
- Display when customer has no orders
- Use assignment_outlined icon
- Message: "No orders yet"
- Follow same pattern as EmptyCustomersState

**5.3 Update presentation barrel export**
- File: `app/lib/presentation/presentation.dart`
- Add exports for OrderListItem, EmptyOrdersState

---

### Task 6: Enhance Customer Detail Screen (1 subtask)

**6.1 Update customer_detail_screen.dart**
- File: `app/lib/screens/customer_detail_screen.dart`
- Add Orders button/tile after customer info
- Display order count badge (e.g., "Orders (5)")
- Load order count using OrderService
- Navigate to OrdersListScreen with customer argument
- Use Card with InkWell for tap handling
- Follow Material 3 design with proper spacing

---

### Task 7: Create Orders List Screen (1 subtask)

**7.1 Create orders_list_screen.dart**
- File: `app/lib/screens/orders_list_screen.dart`
- Accept Customer as required parameter
- Use Consumer<OrderState> for state management
- Load orders in initState using addPostFrameCallback
- Filter orders by customerId
- Display ListView.builder with OrderListItem widgets
- Add FloatingActionButton for adding new orders
- Include RefreshIndicator for pull-to-refresh
- Show LoadingWidget, ErrorDisplayWidget, or EmptyOrdersState based on state
- Handle delete with confirmation dialog
- Navigate to detail and form screens

---

### Task 8: Create Order Detail Screen (1 subtask)

**8.1 Create order_detail_screen.dart**
- File: `app/lib/screens/order_detail_screen.dart`
- Accept Order and Customer as required parameters
- Display order title, due date, customer name in separate Cards
- Format date consistently
- Add Edit and Delete actions in AppBar
- Show delete confirmation dialog
- Navigate to OrderFormScreen for editing
- Navigate back to OrdersListScreen after deletion

---

### Task 9: Create Add/Edit Order Screen (1 subtask)

**9.1 Create order_form_screen.dart**
- File: `app/lib/screens/order_form_screen.dart`
- Accept Customer (required) and Order (optional for edit) as parameters
- Use Form with GlobalKey<FormState>
- TextFormField for title with validation
- Date picker for due date selection
- Detect edit mode based on widget.order != null
- Save/Cancel buttons with proper spacing
- Show loading state during save (CircularProgressIndicator in button)
- Create new Order with UUID or update existing
- Call OrderService.addOrder or updateOrder
- Show success/error SnackBar
- Navigate back on success

---

### Task 10: Wire Up Navigation and State (3 subtasks)

**10.1 Update app_constants.dart with routes**
- Already covered in Task 1.2

**10.2 Update routes.dart**
- File: `app/lib/config/routes.dart`
- Add route handlers in generateRoute():
  ```dart
  case AppConstants.ordersListRoute:
    final customer = settings.arguments as Customer?;
    return MaterialPageRoute(
      builder: (_) => OrdersListScreen(customer: customer),
    );

  case AppConstants.orderDetailRoute:
    final args = settings.arguments as Map<String, dynamic>?;
    final order = args?['order'] as Order?;
    final customer = args?['customer'] as Customer?;
    return MaterialPageRoute(
      builder: (_) => OrderDetailScreen(order: order, customer: customer),
    );

  case AppConstants.orderFormRoute:
    final args = settings.arguments as Map<String, dynamic>?;
    final customer = args?['customer'] as Customer;
    final order = args?['order'] as Order?;
    return MaterialPageRoute(
      builder: (_) => OrderFormScreen(customer: customer, order: order),
    );
  ```

**10.3 Update main.dart**
- File: `app/lib/main.dart`
- Add to MultiProvider:
  ```dart
  ChangeNotifierProvider(create: (_) => OrderState()),
  Provider<OrderRepository>(
    create: (_) => HiveOrderRepository(),
  ),
  ```

---

### Task 11: Handle Customer-Order Relationship (2 subtasks)

**11.1 Implement cascade delete logic**
- Decide on strategy: cascade delete or prevent deletion
- Recommended: Cascade delete (delete all orders when customer is deleted)

**11.2 Update customer_service.dart**
- File: `app/lib/domain/services/customer_service.dart`
- Modify deleteCustomer method:
  - Accept OrderRepository as parameter
  - Call `orderRepository.deleteOrdersByCustomerId(customerId)` before deleting customer
  - Or check if customer has orders and show error message

---

### Task 12: Testing and Verification (4 subtasks)

**12.1 Test on Android**
- Run: `flutter run -d android`
- Test all CRUD operations for orders
- Test customer-order relationship (cascade delete)
- Test navigation between screens
- Test data persistence (restart app)
- Test form validation
- Test date picker functionality

**12.2 Test on Web**
- Run: `flutter run -d chrome`
- Test all CRUD operations for orders
- Test customer-order relationship
- Test navigation and data persistence
- Test responsive layout

**12.3 Run code quality checks**
- Run: `flutter analyze`
- Verify no issues found
- Check design principles compliance

**12.4 Verify feature requirements**
- ✅ Order data model with Hive persistence
- ✅ Customer-order relationship with cascade delete
- ✅ Customer detail screen with Orders button
- ✅ Orders list screen with CRUD actions
- ✅ Order detail screen
- ✅ Add/Edit order form with validation
- ✅ Backend layer with repository pattern
- ✅ Domain layer with state management
- ✅ Presentation layer with reusable widgets
- ✅ Navigation and routes configured
- ✅ Configuration constants added
- ✅ State management integrated

---

## 🏗️ Architecture Decisions

### Customer-Order Relationship
- **Strategy:** Cascade Delete
- **Rationale:** When a customer is deleted, their orders become orphaned and meaningless. Cascade delete maintains data integrity.
- **Implementation:** Call `deleteOrdersByCustomerId()` before deleting customer

### Date Handling
- **Storage:** DateTime object in Hive
- **Display:** Formatted string (e.g., "Dec 7, 2025" or "2025-12-07")
- **Validation:** Cannot be in the past for new orders (can be in past for edits)
- **Picker:** Material DatePicker with initialDate = DateTime.now()

### State Management
- **Pattern:** Same as Customer (Provider + ChangeNotifier)
- **Scope:** OrderState provided at app level in main.dart
- **Loading:** Separate loading state for each screen's operations

---

## 📊 Data Flow

```
User Action → Screen → Service → Repository → Hive Database
                ↓         ↓
              State ← notifyListeners()
                ↓
            Consumer rebuilds UI
```

---

## 🎨 UI/UX Considerations

### Date Display Format
- Use `DateFormat` from `intl` package (if needed)
- Or use simple formatting: `"${date.month}/${date.day}/${date.year}"`
- Consistent format across all screens

### Order Count Badge
- Display in Customer Detail Screen
- Format: "Orders (5)" or "Orders" with badge widget
- Update dynamically when orders change

### Empty State
- Friendly message: "No orders yet"
- Icon: assignment_outlined
- Encourage action: "Tap + to add an order"

### Loading States
- Show CircularProgressIndicator during async operations
- Disable buttons during save operations
- Use RefreshIndicator for pull-to-refresh

---

## ⚠️ Important Notes

1. **Hive TypeId:** Use typeId: 1 for Order (Customer uses 0)
2. **Date Validation:** Allow past dates for edits, but not for new orders
3. **Cascade Delete:** Always delete orders before deleting customer
4. **Error Handling:** Wrap all database operations in try-catch
5. **Navigation Arguments:** Use Map for multiple arguments (order + customer)
6. **State Updates:** Always call notifyListeners() after state changes
7. **Form Validation:** Validate on save, not on every keystroke
8. **Date Picker:** Use showDatePicker() from Material library

---

## 🚀 Quick Start Commands

```bash
# Navigate to app directory
cd app

# Generate Hive adapters (after creating Order model)
flutter pub run build_runner build --delete-conflicting-outputs

# Run on Web
flutter run -d chrome

# Run on Android
flutter run -d android

# Analyze code
flutter analyze

# Build for web
flutter build web --release
```

---

## ✅ Checklist Before Starting

- [ ] Read DESIGN_PRINCIPLES.md
- [ ] Review existing Customer implementation
- [ ] Understand Hive adapter generation process
- [ ] Understand Provider state management pattern
- [ ] Review Material 3 design guidelines
- [ ] Understand 8-point grid spacing system

---

**End of Implementation Plan**

