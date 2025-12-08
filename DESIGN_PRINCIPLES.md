# Flutter App Design Principles

> **For AI Assistants**: These are MANDATORY architectural principles. When implementing ANY feature, you MUST follow these patterns.

## 🎯 Core Rules

1. **Layer Separation**: backend (data) → domain (logic) → presentation (UI)
2. **No Mixed Concerns**: UI never contains business logic or data access
3. **Reusability First**: Extract reusable components
4. **Follow Patterns**: Check existing code before creating new patterns
5. **Consistency**: Same naming, structure, and style throughout

---

## 1. Folder Structure

```
lib/
├── backend/          # Data: repositories, storage, models, API services
├── domain/           # Logic: state, handlers, converters, validators
├── presentation/     # UI: widgets, screens
├── core/             # Theme, routing, utils
├── config/           # Configuration constants
└── main.dart
```

**Quick Decision**:
- Fetches/stores data? → `backend/`
- Processes/transforms data? → `domain/`
- Displays UI? → `presentation/`
- Constants/config? → `config/`

## 2. Separation of Concerns

**Rule**: `presentation/` → `domain/` → `backend/` (never reverse)

```dart
// ✅ Good
class CartScreen extends StatelessWidget {
  final CartHandler handler;
  Widget build(context) => Text('Total: ${handler.state.total}');
}

// ❌ Bad - UI doing business logic
class CartScreen extends StatelessWidget {
  Widget build(context) {
    final total = items.fold(0.0, (sum, item) => sum + item.price); // NO!
  }
}
```

## 3. State Management Pattern

**Pattern**: State (data) ← Handler (logic) ← Widget (UI)

```dart
// domain/state/cart_state.dart
class CartState {
  List<Product> items = [];
  double total = 0.0;
}

// domain/handlers/cart_handler.dart
class CartHandler {
  final CartState state;
  void addProduct(Product p) {
    state.items.add(p);
    state.total += p.price;
  }
}

// presentation/screens/cart_screen.dart
class CartScreen extends StatelessWidget {
  final CartHandler handler;
  Widget build(context) => ListView.builder(...);
}
```

## 4. Repository Pattern

**Always** create abstract interface + implementation:

```dart
// backend/repositories/product_repository.dart
abstract class ProductRepository {
  Future<Product> getById(String id);
}

// backend/repositories/product_repository_impl.dart
class ProductRepositoryImpl implements ProductRepository {
  final ApiService _api;
  Future<Product> getById(String id) => _api.fetchProduct(id);
}
```

## 5. Dependency Injection

**Never** instantiate dependencies inside classes:

```dart
// ❌ Bad
class CartHandler {
  final repo = ProductRepositoryImpl(); // Tightly coupled!
}

// ✅ Good
class CartHandler {
  final ProductRepository repo;
  CartHandler(this.repo); // Inject dependency
}
```

## 6. Error Handling

Use `Result` type for operations that can fail:

```dart
class Result<T> {
  final T? data;
  final String? error;
  final bool isSuccess;
  
  Result.success(this.data) : error = null, isSuccess = true;
  Result.failure(this.error) : data = null, isSuccess = false;
}

// Usage
Future<Result<Product>> getById(String id) async {
  try {
    final product = await _api.fetchProduct(id);
    return Result.success(product);
  } catch (e) {
    return Result.failure('Failed to fetch product');
  }
}
```

## 7. Naming Conventions

- **Files**: `snake_case.dart` (e.g., `product_repository.dart`)
- **Classes**: `PascalCase` (e.g., `ProductRepository`)
- **Variables**: `camelCase` (e.g., `productList`)
- **Private**: `_prefixWithUnderscore` (e.g., `_repository`)
- **Booleans**: `isLoading`, `hasError`, `canSubmit`

## 8. Configuration

**Never** hardcode values:

```dart
// config/app_config.dart
class AppConfig {
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
}

// Usage
padding: EdgeInsets.all(AppConfig.spacingMd)
```

## 9. Performance

- Use `const` constructors wherever possible
- Use `ListView.builder` for long lists
- Extract static widgets to prevent rebuilds
- Inject dependencies, don't create them

## 10. Implementation Checklist

Before submitting code, verify:

- [ ] Files in correct layer (backend/domain/presentation)
- [ ] No layer violations (presentation → domain → backend only)
- [ ] Dependencies injected via constructor
- [ ] No hardcoded values (use config)
- [ ] Proper error handling (Result type)
- [ ] Naming follows conventions
- [ ] Const constructors used
- [ ] Cross-reference FLUTTER_UI_DESIGN_PRINCIPLES.md for UI

