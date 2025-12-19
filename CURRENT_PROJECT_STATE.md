# Current Project State

**Last Updated:** December 18, 2025
**Status:** ✅ Customer & Order Management + Authentication + Google Drive Backup

---

## 🏗️ Architecture

- **Layers:** `backend/` → `domain/` → `screens/` + `presentation/`
- **State:** Provider (ChangeNotifier)
- **Data:** Hive (local NoSQL)
- **Design:** Material 3, 8-point grid (8, 16, 24, 32, 48)

---

## 📦 Tech Stack

- **Database:** hive + hive_flutter
- **State:** provider
- **Auth:** firebase_auth + google_sign_in
- **Backup:** googleapis (Drive API)
- **Communication:** url_launcher (WhatsApp, phone calls)
- **Utils:** uuid, intl, build_runner

---

## 🎯 Data Models (Hive)

| Model | TypeId | Key Fields | Notes |
|-------|--------|------------|-------|
| Customer | 0 | id, name, phone?, description?, created | Cascade deletes orders |
| Order | 1 | id, customerId, title, dueDate, description?, status, created | Status: pending/ready/done |
| OrderStatus | 2 | pending, ready, done | Enum |
| AppSettings | 3 | dueDateWarningThreshold | Stored as 'app_settings' |

---

## 📁 Project Structure

```
backend/
  ├── models/          # Hive models with @HiveType
  ├── repositories/    # Interface + Hive implementation
  └── database/        # DatabaseService (Hive init)

domain/
  ├── state/           # ChangeNotifier states
  ├── services/        # Business logic (static methods)
  └── validators/      # Pure validation functions

screens/               # Full-page screens
presentation/
  └── widgets/         # Reusable widgets

config/                # App configuration
constants/             # App constants
utils/                 # Helper utilities
```

---

## 🔑 Key Services & States

| Service | Purpose | Key Methods |
|---------|---------|-------------|
| **AuthService** | Firebase + Google Sign-In | `signInWithGoogle()`, `signOut()` |
| **BackupService** | Backup/restore logic | `createBackup()`, `restoreBackup()`, `getBackupMetadata()` |
| **DriveService** | Google Drive API | `uploadBackup()`, `downloadBackup()`, `getBackupInfo()` |
| **CustomerService** | Customer CRUD | `loadCustomers()`, `createCustomer()`, `deleteCustomer()` |
| **OrderService** | Order CRUD | `loadOrders()`, `createOrder()`, `updateOrder()` |
| **SettingsService** | Settings management | `loadSettings()`, `saveSettings()` |

**States:** AuthState, BackupState, CustomerState, OrderState, SettingsState (all ChangeNotifier)

---

## 🔐 Authentication & Backup

### Authentication
- **Provider:** Firebase Auth + Google Sign-In (with Drive scope)
- **Persistence:** LOCAL (web), automatic (mobile)
- **Flow:** Google popup → Firebase credential → Home
- **Mobile:** Silent sign-in on app start (automatic Drive access restoration)
- **Web Limitation:** GoogleSignIn session lost on reload (use "Sign in to Google Drive" button)
- **Sign Out:** Clears auth + all Hive data + all states
- **Auth Gate:** `AppInitializer` listens to Firebase auth state

### Google Drive Backup
- **Location:** appDataFolder (hidden, app-specific)
- **File:** Single JSON (overridden on each backup)
- **Contents:** Customers, Orders, Settings + metadata
- **Backup:** Serialize Hive → Upload to Drive
- **Restore:** Download → Show confirmation → Clear Hive → Deserialize → Reload states

---

## 🎨 Key Features

### Customer Management
- CRUD operations with validation
- Cascade delete (deletes all customer's orders)
- Search by name/phone
- Pending order count display
- Visual indicators (green checkmark when all done)
- Quick actions: WhatsApp chat & phone call (when phone number present)

### Order Management
- CRUD operations with validation
- Status toggle (pending → ready → done)
- Due date tracking (warnings only for pending orders)
- Search by title/description
- Dual mode list (all orders / customer-specific)
- Filter by status (all/pending/ready/unpaid)

### Settings
- Due date warning threshold configuration
- Google Drive backup/restore with progress
- Sign out with confirmation

### UI Patterns
- **Reactive:** Detail screens use Consumer to fetch latest data by ID
- **Search:** Live filtering with SearchBarWidget + SearchHelper
- **Sorting:** All lists sorted by created date (newest first)
- **Loading:** Parallel data loading with Future.wait()
- **Dialogs:** Reusable ConfirmationDialog and LoadingDialog

---



## 🚀 Commands

```bash
cd app
flutter run -d chrome                                              # Run
flutter pub run build_runner build --delete-conflicting-outputs    # Regenerate Hive
flutter build web --release                                        # Build
```

---

## 🔧 Setup & Troubleshooting

**Setup:**
- Firebase: Add config to `web/index.html`, `android/app/`, `ios/Runner/`
- Google: Add client ID to `web/index.html` and `config/auth_config.dart`

**Common Issues:**
- Hive errors → Run build_runner
- State not updating → Check `notifyListeners()`
- Web Drive lost → Click "Sign in to Google Drive" (web limitation)
- Backup fails → Verify Drive permission granted

---

**End of Document**

