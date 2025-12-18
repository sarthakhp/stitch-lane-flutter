# Flutter App Design Principles

> **For AI Assistants**: These are MANDATORY architectural principles. When creating or modifying ANY code in this project, follow these rules. If the user's request conflicts with these principles, suggest the correct approach.

## 1. Modular Folder Structure

**Rule**: Always place files in the correct layer. Never mix concerns.

```
lib/
├── backend/          # Data layer (repositories, storage, models)
├── domain/           # Business logic (state, calculations, converters)
├── presentation/     # UI layer (widgets only)
├── config/           # Configuration constants
├── constants/        # App-wide constants
└── screens/          # Top-level screens
```

**AI Checklist**:
- ✅ New model/entity? → `backend/models/`
- ✅ New widget? → `presentation/widgets/`
- ✅ New screen? → `screens/`
- ✅ Business logic? → `domain/`
- ✅ Constants? → `config/` or `constants/`
## 2. Separation of Concerns

**Rule**: Each layer has a single responsibility. Never violate layer boundaries.

- **Domain layer** - Pure Dart logic with NO Flutter dependencies (`import 'package:flutter/...'` is forbidden)
- **Presentation layer** - ONLY UI widgets, no business logic, no calculations
- **Backend layer** - Persistence, API calls, data access

**Examples**:
- ❌ BAD: `presentation/widgets/cart_widget.dart` calculates total price
- ✅ GOOD: `domain/services/cart_service.dart` calculates, widget displays
- ❌ BAD: `domain/models/user.dart` imports `package:flutter/material.dart`
- ✅ GOOD: Domain uses pure Dart classes only

## 3. Barrel Exports

**Rule**: Create `index.dart` files in each major folder to simplify imports.

```dart
// domain/domain.dart
export 'models/model_a.dart';
export 'services/service_b.dart';
```

**AI Action**: When creating new files, update the relevant barrel export file.

## 4. Single Responsibility Widgets

**Rule**: Each widget does exactly ONE thing. If a widget is >150 lines, split it.

**Examples**:
- ❌ BAD: `ProductCard` handles display, cart logic, and navigation
- ✅ GOOD: `ProductCard` displays, `AddToCartButton` handles cart, `ProductTapHandler` navigates
- ❌ BAD: 300-line widget with nested builders
- ✅ GOOD: Extract sections into `_HeaderSection`, `_ContentSection`, `_FooterSection`

## 5. State Management Pattern

**Rule**: Separate state from UI. Use consistent state management approach.

- **State class** holds mutable data (e.g., `CartState`, `UserState`)
- **Handler/Service classes** encapsulate user interactions and business logic
- **Widgets** only read state and trigger handlers

```dart
// ✅ GOOD Pattern
class CartState extends ChangeNotifier {
  List<Item> items = [];
}

class CartService {
  void addItem(CartState state, Item item) {
    state.items.add(item);
    state.notifyListeners();
  }
}

// Widget just displays and calls service
Consumer<CartState>(
  builder: (context, state, _) => Text('${state.items.length}'),
)
```

## 6. Repository Pattern for Persistence

**Rule**: Never access storage/API directly from UI or domain. Always use repositories.

```dart
// ✅ GOOD: Abstract interface
abstract class UserRepository {
  Future<User?> getUser(String id);
  Future<void> saveUser(User user);
}

// Implementation in backend/
class LocalUserRepository implements UserRepository {
  final SharedPreferences prefs;
  // ... implementation
}
```

**AI Action**: When adding data persistence, create repository interface first, then implementation.

## 7. Reusable Widget Patterns

**Rule**: DRY (Don't Repeat Yourself). Extract common patterns.

- **Base classes** for similar widgets (e.g., `BaseCard`, `BaseButton`)
- **Composition over inheritance** - prefer wrapping over extending
- **Static factory methods** for common configurations

```dart
// ✅ GOOD: Reusable button with variants
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const AppButton.primary({required this.label, required this.onPressed})
      : isPrimary = true;

  const AppButton.secondary({required this.label, required this.onPressed})
      : isPrimary = false;
}
```

## 8. Configuration Externalization

**Rule**: No magic numbers or hardcoded values in widgets. Use config files.

```dart
// ✅ GOOD: config/app_config.dart
class AppConfig {
  static const double cardBorderRadius = 12.0;
  static const int maxCartItems = 50;
  static const Duration animationDuration = Duration(milliseconds: 300);
}

// Use in widgets
BorderRadius.circular(AppConfig.cardBorderRadius)
```

## 9. Platform-Aware Code

**Rule**: Use platform checks for platform-specific behavior, but prefer adaptive widgets.

```dart
// ✅ GOOD: Use adaptive widgets first
Icon(Icons.adaptive.share)

// ✅ GOOD: Platform checks when necessary
if (kIsWeb) {
  // Web-specific code
} else if (Platform.isIOS) {
  // iOS-specific code
}
```

---

## 10. Naming Conventions

**Rule**: Consistent naming makes code self-documenting.

- **Files**: `snake_case.dart` (e.g., `user_profile_screen.dart`)
- **Classes**: `PascalCase` (e.g., `UserProfileScreen`)
- **Variables/Functions**: `camelCase` (e.g., `getUserProfile()`)
- **Constants**: `lowerCamelCase` or `SCREAMING_SNAKE_CASE` for compile-time constants
- **Private members**: Prefix with `_` (e.g., `_internalMethod()`)

---

## 11. Error Handling

**Rule**: Always handle errors gracefully. Never let the app crash silently.

```dart
// ✅ GOOD: Proper error handling
try {
  final user = await userRepository.getUser(id);
  return user;
} catch (e) {
  logger.error('Failed to fetch user: $e');
  return null; // or throw custom exception
}
```

**AI Action**: Wrap all async operations in try-catch blocks.

---

## 12. Code Documentation

**Rule**: Code should be self-explanatory. Add comments ONLY for complex logic.

- ❌ BAD: `// This function adds two numbers`
- ✅ GOOD: `// Using binary search for O(log n) performance on sorted list`
- ✅ GOOD: Document public APIs with `///` doc comments
- ❌ BAD: Commenting what the code does (code should be readable)
- ✅ GOOD: Commenting WHY the code does it (business logic, edge cases)

---

## AI Implementation Checklist

Before submitting code, verify:

1. ✅ File is in the correct folder (backend/domain/presentation)
2. ✅ No Flutter imports in domain layer
3. ✅ No business logic in presentation layer
4. ✅ Widget is <150 lines (split if larger)
5. ✅ Uses config constants (no magic numbers)
6. ✅ Follows naming conventions
7. ✅ Has error handling for async operations
8. ✅ Updated barrel exports if new file created
9. ✅ Uses repository pattern for data access
10. ✅ State management follows project pattern
11. ✅ Reuses existing widgets/patterns where possible
12. ✅ Platform-aware code uses adaptive widgets first

**If you violate any principle, explicitly state why and get user approval.**

