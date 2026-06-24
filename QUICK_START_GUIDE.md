# StitchGenie - Quick Start Guide

## Wireless ADB Setup (Android)

Connect your phone once via USB, then switch to wireless:

```bash
# 1. Verify phone is connected via USB (must show "device", not "unauthorized")
adb devices

# 2. Switch to TCP/IP mode
adb tcpip 5555

# 3. Get phone's WiFi IP
adb shell ip addr show wlan0 | grep 'inet '

# 4. Connect wirelessly (replace IP with yours)
adb connect 192.168.29.151:5555

# 5. Unplug USB cable. Verify wireless connection:
adb devices
```

**Reconnecting** (if connection drops, e.g. after phone sleep):
```bash
adb connect 192.168.29.151:5555
```

**Prerequisites**: USB debugging AND wireless debugging must be enabled in Developer Options.

## Android Emulator (Mac, no Android Studio)

AVD installed: **Pixel_7_API36** (Android 16, Google Play, arm64)

```bash
# Launch emulator
emulator -avd Pixel_7_API36

# List available AVDs
avdmanager list avd

# Create a new AVD (if needed)
sdkmanager "system-images;android-36;google_apis_playstore;arm64-v8a"
echo no | avdmanager create avd -n "MyAVD" -k "system-images;android-36;google_apis_playstore;arm64-v8a" -d "pixel_7"

# Delete an AVD + free its system image
avdmanager delete avd -n "MyAVD"
sdkmanager --uninstall "system-images;android-36;google_apis_playstore;arm64-v8a"
```

**Note:** `ANDROID_HOME` = `~/Library/Android/sdk`. The SDK cmdline-tools are prepended in `~/.zshrc` so they take priority over any Homebrew-installed SDK tools.

## Run the App

```bash
cd app
flutter run               # auto-picks connected device
flutter run -d android    # explicit Android target
flutter run --release     # release build (no hot reload)
```

---

## 📋 Overview
This guide provides a quick reference for the customer management feature.

## 🎯 Feature Summary
- **Home Screen**: Navigation tile to customers
- **Customers List**: View all customers with add/edit/delete actions
- **Customer Detail**: View full customer information
- **Add/Edit Form**: Create and update customers
- **Data Persistence**: Works on Android and Web

## 🏗️ Architecture Stack

### Database
- **Hive** - Cross-platform NoSQL database (Android, iOS, Web)

### State Management
- **Provider** - ChangeNotifier pattern for state management

### Navigation
- **Named Routes** - Type-safe navigation with route arguments

## 📁 Key Files to Create

### Configuration (2 files)
```
app/lib/config/app_config.dart
app/lib/config/routes.dart
app/lib/constants/app_constants.dart
```

### Backend Layer (5 files)
```
app/lib/backend/models/customer.dart
app/lib/backend/models/index.dart
app/lib/backend/database/database_service.dart
app/lib/backend/repositories/customer_repository.dart
app/lib/backend/repositories/hive_customer_repository.dart
app/lib/backend/backend.dart
```

### Domain Layer (5 files)
```
app/lib/domain/state/customer_state.dart
app/lib/domain/services/customer_service.dart
app/lib/domain/validators/customer_validators.dart
app/lib/domain/domain.dart
```

### Presentation Layer (6 files)
```
app/lib/presentation/widgets/customer_list_item.dart
app/lib/presentation/widgets/empty_customers_state.dart
app/lib/presentation/widgets/loading_widget.dart
app/lib/presentation/widgets/error_widget.dart
app/lib/presentation/presentation.dart
```

### Screens (4 files - 1 update, 3 new)
```
app/lib/screens/home_screen.dart (UPDATE)
app/lib/screens/customers_list_screen.dart (NEW)
app/lib/screens/customer_detail_screen.dart (NEW)
app/lib/screens/customer_form_screen.dart (NEW)
```

**Total: 22 files (21 new + 1 update)**

## 🔧 Dependencies to Add

```yaml
dependencies:
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  uuid: ^4.0.0
  provider: ^6.1.0
```

## 🚀 Implementation Commands

```bash
# Navigate to app directory
cd app

# Add dependencies
flutter pub add hive hive_flutter uuid provider

# Get dependencies
flutter pub get

# Run on Android
flutter run -d android

# Run on Web
flutter run -d chrome

# Analyze code
flutter analyze

# Build for web
flutter build web --release
```

## ✅ Design Principles Checklist

- [ ] Files in correct folders (backend/domain/presentation/screens)
- [ ] No Flutter imports in domain layer
- [ ] No business logic in presentation widgets
- [ ] Widgets under 150 lines
- [ ] Config constants used (no magic numbers)
- [ ] Repository pattern for data access
- [ ] Barrel exports created
- [ ] Material 3 design with seeded ColorScheme
- [ ] 8-point grid spacing (8, 16, 24, 32, 48)
- [ ] Error handling with try-catch
- [ ] Loading states for async operations

## 📊 Data Flow

```
UI (Screens/Widgets)
    ↓ reads state
CustomerState (ChangeNotifier)
    ↑ updates
CustomerService (Business Logic)
    ↓ calls
CustomerRepository (Interface)
    ↓ implements
HiveCustomerRepository
    ↓ uses
Hive Database
```

## 🎨 Material 3 Design Elements

- **ColorScheme**: `ColorScheme.fromSeed(seedColor: Colors.blue)`
- **Spacing**: 8, 16, 24, 32, 48 (8-point grid)
- **Components**: ListTile, Card, FAB, AppBar, TextFormField
- **Icons**: Material Icons (adaptive where possible)

## 🔍 Testing Checklist

### Functional Tests
- [ ] Add new customer
- [ ] View customer list
- [ ] View customer details
- [ ] Edit existing customer
- [ ] Delete customer
- [ ] Form validation (required fields)
- [ ] Empty state display
- [ ] Navigation flow

### Platform Tests
- [ ] Android: Data persists after app restart
- [ ] Web: Data persists after page refresh
- [ ] Android: All screens render correctly
- [ ] Web: All screens render correctly

### Code Quality
- [ ] `flutter analyze` passes with no issues
- [ ] All design principles followed
- [ ] No hardcoded values (use config)
- [ ] Error handling implemented
- [ ] Loading states implemented

## 📝 Notes

- Customer model uses UUID for unique IDs
- Phone number validation can be customized
- Description field is optional
- Delete action requires confirmation
- All async operations have error handling
- Loading indicators shown during operations

## 🎓 Next Steps After Implementation

1. Run the app on both platforms
2. Test all CRUD operations
3. Verify data persistence
4. Check Material 3 design compliance
5. Run `flutter analyze`
6. Review code against design principles

---

For detailed implementation steps, see `CUSTOMER_MANAGEMENT_IMPLEMENTATION_PLAN.md`

