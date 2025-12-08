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


