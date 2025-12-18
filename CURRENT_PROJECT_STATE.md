# Current Project State

**Last Updated:** December 8, 2025
**Project:** Stitch Lane Flutter App
**Status:** ✅ Customer & Order Management Complete

Flutter app for managing customers and orders with offline-first persistence (Hive), Material 3 design, and clean architecture.

---

## 🏗️ Architecture

**Layers:** `backend/` (data) → `domain/` (business logic) → `screens/` + `presentation/` (UI)

**Key Principles:**
- Clean architecture with strict layer separation
- Provider state management (ChangeNotifier)
- Repository pattern for data access
- Material 3 design with 8-point grid (8, 16, 24, 32, 48)
- NO Flutter imports in domain layer

---

## 📦 Key Dependencies

- **hive** + **hive_flutter** - Local NoSQL database
- **provider** - State management
- **uuid** - ID generation
- **intl** - Date formatting
- **build_runner** + **hive_generator** - Code generation

---

## 🎯 Data Models

### Customer (Hive TypeId: 0)
- **Fields:** id, name, phoneNumber?, description?, created
- **Validation:** Name (2-100), Phone (10+ digits, optional), Description (max 500, optional)
- **Auto-set:** created = DateTime.now() on creation
- **Cascade Delete:** Deletes all customer's orders

### Order (Hive TypeId: 1)
- **Fields:** id, customerId, title, dueDate, description?, created, status
- **Validation:** Title (2-100), Description (max 500), Due date (no past for new)
- **Auto-set:** created = DateTime.now(), status = OrderStatus.pending on creation
- **Relationship:** Many orders → One customer
- **Status:** Enum (pending, done) - toggleable from detail screen

### OrderStatus (Hive TypeId: 2)
- **Enum Values:** pending, done
- **Default:** pending
- **Usage:** Order status tracking

---

## 📁 Key Files Reference

### When Adding New Features
- **Models:** `backend/models/` - Add Hive annotations, run build_runner
- **State:** `domain/state/` - ChangeNotifier pattern
- **Services:** `domain/services/` - Static methods coordinating state + repository
- **Validators:** `domain/validators/` - Pure validation functions
- **Repositories:** `backend/repositories/` - Interface + Hive implementation
- **Utils:** `utils/` - Reusable utilities (search, filters, helpers)

### Configuration
- `config/app_config.dart` - Spacing, validation limits, animations
- `config/routes.dart` - Route definitions
- `constants/app_constants.dart` - Box names, route paths

### Pattern Examples
- **Form with validation:** `screens/customer_form_screen.dart`
- **Form with date picker:** `screens/order_form_screen.dart`
- **Form with multi-line input:** Description fields use `textInputAction: TextInputAction.newline`
- **Detail screen (reactive):** `screens/customer_detail_screen.dart` (uses Consumer)
- **Detail screen with status toggle:** `screens/order_detail_screen.dart` (SegmentedButton)
- **List screen with search:** `screens/customers_list_screen.dart`
- **List screen with multiple states:** `screens/customers_list_screen.dart` (Consumer2 for customer + order data)
- **List screen with dual modes:** `screens/orders_list_screen.dart` (optional customer param for all-orders vs customer-specific)
- **List item with conditional styling:** `presentation/widgets/order_list_item.dart` (green for done)
- **List item with computed data:** `presentation/widgets/customer_list_item.dart` (pending order count)
- **List item with optional context:** `presentation/widgets/order_list_item.dart` (optional customerName)
- **Cascade delete:** `services/customer_service.dart`
- **Reusable search widget:** `presentation/widgets/search_bar_widget.dart`
- **Search/filter logic:** `utils/search_helper.dart`
- **Enum with Hive:** `backend/models/order_status.dart`

---

## 🔑 Important Implementation Details

### State Management Pattern
```dart
// State: ChangeNotifier with list, isLoading, error
// Service: Static methods coordinating state + repository
// Screen: Consumer<State> for reactive UI

// Example: Creating an order
await OrderService.createOrder(
  context.read<OrderState>(),
  context.read<OrderRepository>(),
  order,
);
```

### Routes & Navigation
- `/` → Home
- `/customers` → Customer List
- `/customer/detail` → Customer Detail (arg: Customer)
- `/customer/form` → Add/Edit Customer (arg: Customer?)
- `/orders` → All Orders List (no args - shows all orders)
- `/customer/orders` → Customer Orders List (arg: Customer - shows customer's orders)
- `/order/detail` → Order Detail (arg: {order, customer})
- `/order/form` → Add/Edit Order (arg: {customer, order?})

### Cascade Delete
When deleting a customer, `CustomerService.deleteCustomer()` first calls `OrderRepository.deleteOrdersByCustomerId()` to remove all orders.

### Reactive Detail Screens
Detail screens store only IDs and use `Consumer` to fetch latest data from state:
```dart
Consumer<CustomerState>(
  builder: (context, state, _) {
    final customer = state.customers.firstWhere((c) => c.id == customerId);
    // Build UI with latest customer data
  }
)
```

### Search Functionality
Both Customer and Order list screens have live search:
- **Customer Search:** Searches across name and phone number
- **Order Search:** Searches across title and description
- **Implementation:** `SearchBarWidget` in AppBar bottom + `SearchHelper` utility
- **Features:** Case-insensitive, live filtering, clear button, empty state handling

```dart
// Using SearchHelper
final filtered = SearchHelper.filterCustomers(customers, searchQuery);
final filtered = SearchHelper.filterOrders(orders, searchQuery);
```

### List Sorting
Both Customer and Order lists are sorted by creation date (newest first):
- **Sort Order:** Descending by `created` field (most recent at top)
- **Applied After:** Filtering/searching
- **Implementation:** In-memory sorting using `compareTo()`

```dart
// Sort by created date descending (newest first)
final filteredCustomers = List<Customer>.from(
  SearchHelper.filterCustomers(state.customers, query)
)..sort((a, b) => b.created.compareTo(a.created));
```

### Data Loading Strategy
All data is loaded once at app initialization for optimal performance:
- **Customer List Screen:** Loads both customers AND all orders in parallel using `Future.wait()`
- **Order List Screen:** Uses pre-loaded orders from OrderState, filters locally
- **Benefits:** Single source of truth, reactive updates, no redundant loading
- **Implementation:** `CustomersListScreen._loadData()` loads both states

```dart
// Load all data in parallel
await Future.wait([
  CustomerService.loadCustomers(customerState, customerRepository),
  OrderService.loadOrders(orderState, orderRepository),
]);
```

### Customer List with Pending Order Counts
Customer list displays pending order count for each customer with visual indicators:
- **Pending Count:** Shows number of orders with `status == OrderStatus.pending`
- **Visual Indicators:**
  - Has pending orders: Normal purple/blue avatar with person icon, shows "X pending"
  - No pending orders: Green avatar (`Colors.green.shade100`) with checkmark icon, shows "All done"
- **Reactive Updates:** Uses `Consumer2<CustomerState, OrderState>` to update when orders change
- **Calculation:** Uses `orderState.getPendingOrderCount(customerId)` method

```dart
// In CustomerListScreen
Consumer2<CustomerState, OrderState>(
  builder: (context, customerState, orderState, child) {
    // ...
    CustomerListItem(
      customer: customer,
      pendingOrderCount: orderState.getPendingOrderCount(customer.id),
      // ...
    )
  }
)
```

### Order Status Management
Orders have a status field (pending/done) with visual indicators:
- **Default Status:** All new orders are "Pending"
- **Toggle:** SegmentedButton in order detail screen switches between Pending/Done
- **Visual Indicators:**
  - Pending: Normal purple/blue avatar with assignment icon
  - Done: Green avatar (`Colors.green.shade100`) with checkmark icon
- **Persistence:** Status saved via `OrderService.updateOrder()`
- **Backward Compatible:** Existing orders automatically become "Pending"

```dart
// Toggle status
final updatedOrder = order.copyWith(
  status: order.status == OrderStatus.done
    ? OrderStatus.pending
    : OrderStatus.done
);
await OrderService.updateOrder(state, repository, updatedOrder);
```

### Orders List Screen - Dual Mode Operation
The `OrdersListScreen` supports two modes via optional `customer` parameter:

**All Orders Mode (customer: null):**
- Shows all orders from all customers
- AppBar title: "All Orders"
- Customer name displayed in each order item
- No FAB (adding orders requires customer context)
- Accessed from Home screen "Show Orders" tile

**Customer-Specific Mode (customer: provided):**
- Shows only that customer's orders
- AppBar title: "[Customer Name]'s Orders"
- No customer name in items (redundant)
- FAB visible for adding new orders
- Accessed from Customer detail or Customer list

```dart
// Dual mode implementation
class OrdersListScreen extends StatefulWidget {
  final Customer? customer; // Optional parameter

  const OrdersListScreen({super.key, this.customer});
}

// In build method
final displayOrders = widget.customer != null
    ? state.orders.where((order) => order.customerId == widget.customer!.id).toList()
    : state.orders; // Show all orders

// Conditional FAB
floatingActionButton: widget.customer != null
    ? FloatingActionButton(/* ... */)
    : null,

// OrderListItem with optional customer name
OrderListItem(
  order: order,
  customerName: widget.customer == null ? customer.name : null,
  onTap: () { /* ... */ },
)
```

---



## 🚀 Common Commands

```bash
cd app

# Run app
flutter run -d chrome  # or -d android

# Regenerate Hive adapters (after model changes)
flutter pub run build_runner build --delete-conflicting-outputs

# Build
flutter build web --release
flutter build apk --release
```

---



## 🔧 Troubleshooting

**Hive adapter errors:** Run `flutter pub run build_runner build --delete-conflicting-outputs`
**State not updating:** Ensure `notifyListeners()` is called in State classes
**Cascade delete not working:** Pass OrderState + OrderRepository to CustomerService.deleteCustomer()

---





## 🎨 Design Constants

**Spacing (8-point grid):** 8, 16, 24, 32, 48
**Date Format:** "MMM d, y" (lists), "MMMM d, y" (details)
**Theme:** Material 3, system light/dark mode
**All constants:** See `config/app_config.dart`

---

**End of Document**

