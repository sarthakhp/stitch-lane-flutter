# Order Management - Quick Start Guide

**Feature:** Order Management with Customer-Order Relationship  
**Estimated Time:** ~5-6 hours  
**Dependencies:** Customer Management (already implemented)

---

## 📋 Feature Summary

Add order management functionality where each customer can have multiple orders. Orders include a title and due date, with full CRUD operations and cascade delete when customers are removed.

---

## 🏗️ Architecture Stack

- **Database:** Hive (NoSQL, cross-platform)
- **State Management:** Provider (ChangeNotifier pattern)
- **Architecture:** Clean Architecture (Backend → Domain → Presentation → Screens)
- **Design:** Material 3 with 8-point grid spacing
- **Platforms:** Android & Web

---

## 📁 Files to Create (17 new files)

### Configuration (2 files to modify)
```
app/lib/config/app_config.dart (modify)
app/lib/constants/app_constants.dart (modify)
```

### Backend Layer (5 new files, 3 to modify)
```
app/lib/backend/models/order.dart
app/lib/backend/models/order.g.dart (generated)
app/lib/backend/repositories/order_repository.dart
app/lib/backend/repositories/hive_order_repository.dart
app/lib/backend/models/index.dart (modify)
app/lib/backend/database/database_service.dart (modify)
app/lib/backend/backend.dart (modify)
```

### Domain Layer (3 new files, 2 to modify)
```
app/lib/domain/state/order_state.dart
app/lib/domain/services/order_service.dart
app/lib/domain/validators/order_validators.dart
app/lib/domain/services/customer_service.dart (modify)
app/lib/domain/domain.dart (modify)
```

### Presentation Layer (2 new files, 1 to modify)
```
app/lib/presentation/widgets/order_list_item.dart
app/lib/presentation/widgets/empty_orders_state.dart
app/lib/presentation/presentation.dart (modify)
```

### Screens (3 new files, 1 to modify)
```
app/lib/screens/orders_list_screen.dart
app/lib/screens/order_detail_screen.dart
app/lib/screens/order_form_screen.dart
app/lib/screens/customer_detail_screen.dart (modify)
```

### Main App (2 files to modify)
```
app/lib/config/routes.dart (modify)
app/lib/main.dart (modify)
```

---

## 🚀 Implementation Commands

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

## 📊 Implementation Order

Follow this sequence to ensure dependencies are met:

1. **Setup and Configuration** (Task 1)
   - Update app_config.dart with validation constants
   - Update app_constants.dart with database and route names

2. **Create Data Models** (Task 2)
   - Create Order model with Hive annotations
   - Generate Hive adapter
   - Update models barrel export

3. **Implement Database Layer** (Task 3)
   - Update database_service.dart
   - Create OrderRepository interface
   - Create HiveOrderRepository implementation
   - Update backend barrel export

4. **Create Domain Layer** (Task 4)
   - Create OrderState (ChangeNotifier)
   - Create OrderService (CRUD methods)
   - Create OrderValidators (pure Dart)
   - Update domain barrel export

5. **Build UI Components** (Task 5)
   - Create OrderListItem widget
   - Create EmptyOrdersState widget
   - Update presentation barrel export

6. **Enhance Customer Detail Screen** (Task 6)
   - Add Orders button with count badge
   - Add navigation to orders list

7. **Create Orders List Screen** (Task 7)
   - Build screen with list, FAB, pull-to-refresh

8. **Create Order Detail Screen** (Task 8)
   - Build detail view with Edit/Delete actions

9. **Create Add/Edit Order Screen** (Task 9)
   - Build form with title and date picker

10. **Wire Up Navigation and State** (Task 10)
    - Update routes.dart
    - Update main.dart with providers

11. **Handle Customer-Order Relationship** (Task 11)
    - Implement cascade delete logic
    - Update customer_service.dart

12. **Testing and Verification** (Task 12)
    - Test on Android and Web
    - Run flutter analyze
    - Verify all requirements

---

## 🎯 Key Implementation Details

### Order Model (Hive TypeId: 1)
```dart
@HiveType(typeId: 1)
class Order {
  @HiveField(0) final String id;
  @HiveField(1) final String customerId;
  @HiveField(2) final String title;
  @HiveField(3) final DateTime dueDate;
  
  // Constructor, toJson, fromJson, copyWith, equals, hashCode
}
```

### Validation Rules
- **Title:** Required, 2-100 characters
- **Due Date:** Required, cannot be in past for new orders

### Routes
- `/customer/orders` - Orders List Screen (requires Customer argument)
- `/order/detail` - Order Detail Screen (requires Order + Customer arguments)
- `/order/form` - Order Form Screen (requires Customer, optional Order)

### Cascade Delete Strategy
When deleting a customer:
1. Call `orderRepository.deleteOrdersByCustomerId(customerId)`
2. Then delete the customer
3. This prevents orphaned orders

---

## ✅ Design Principles Checklist

- [ ] Clean architecture (backend → domain → presentation → screens)
- [ ] NO Flutter imports in domain layer (except foundation)
- [ ] Repository pattern for data access
- [ ] Provider for state management
- [ ] Material 3 design with seeded ColorScheme
- [ ] 8-point grid spacing (8, 16, 24, 32, 48)
- [ ] No magic numbers (use AppConfig constants)
- [ ] Widgets under 150 lines
- [ ] Error handling with try-catch
- [ ] Loading states for async operations
- [ ] Confirmation dialogs for destructive actions
- [ ] Barrel exports for modules

---

## 🧪 Testing Checklist

### Functional Testing
- [ ] Create new order for a customer
- [ ] View order details
- [ ] Edit existing order
- [ ] Delete order with confirmation
- [ ] View customer's orders list
- [ ] Empty state when no orders
- [ ] Pull-to-refresh orders list
- [ ] Navigate between screens
- [ ] Form validation (title, due date)
- [ ] Date picker functionality
- [ ] Cascade delete (delete customer with orders)

### Platform Testing
- [ ] Test on Android
- [ ] Test on Web
- [ ] Data persists after app restart
- [ ] Responsive layout on different screen sizes

### Code Quality
- [ ] `flutter analyze` passes with no issues
- [ ] All design principles followed
- [ ] Consistent code style
- [ ] Proper error handling
- [ ] Loading states implemented

---

## 🎨 UI Components to Reuse

From existing Customer Management:
- `LoadingWidget` - For loading states
- `ErrorDisplayWidget` - For error messages with retry
- Same Card/ListTile patterns
- Same form validation patterns
- Same confirmation dialog patterns

---

## ⚠️ Common Pitfalls to Avoid

1. **Hive TypeId Conflict** - Use typeId: 1 for Order (Customer uses 0)
2. **Forgot to Register Adapter** - Must register OrderAdapter in database_service.dart
3. **Flutter Imports in Domain** - Only foundation.dart allowed for ChangeNotifier
4. **Missing notifyListeners()** - Always call after state changes
5. **Date Validation** - Allow past dates for edits, not for new orders
6. **Navigation Arguments** - Use Map for multiple arguments
7. **Cascade Delete** - Always delete orders before customer
8. **Build Runner** - Run after creating Order model

---

## 📚 Reference Files

When implementing, refer to these existing files:
- `app/lib/backend/models/customer.dart` - Model pattern
- `app/lib/backend/repositories/hive_customer_repository.dart` - Repository pattern
- `app/lib/domain/state/customer_state.dart` - State pattern
- `app/lib/domain/services/customer_service.dart` - Service pattern
- `app/lib/screens/customer_form_screen.dart` - Form pattern
- `DESIGN_PRINCIPLES.md` - Architecture rules

---

**Ready to implement? Start with Task 1!**

