import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_logger.dart';
import '../services/permissions/app_permission.dart';
import '../services/permissions/app_permission_status.dart';
import '../services/permissions/permission_service.dart';

/// Owns runtime-permission state for the whole app.
///
/// Responsibilities:
///   1. Cache the current status of each [AppPermission] so the UI can read
///      it synchronously (banner show/hide).
///   2. Persist a "we've shown the first-time explainer once" flag, so that
///      flag survives app restarts and the explainer never appears twice.
///   3. Provide the only [requestAll] / [openSystemSettings] / [refresh]
///      entry points the UI should call.
///
/// Does NOT show dialogs. UI flow (explainer → request) is orchestrated by
/// [PermissionPromptCoordinator] — keeping this controller free of
/// `BuildContext` makes it trivial to unit-test.
class PermissionController extends ChangeNotifier {
  static const _firstTimePromptKey = 'permissions_first_time_prompt_done';

  bool _initialised = false;
  bool _hasCompletedFirstTimePrompt = false;
  Map<AppPermission, AppPermissionStatus> _statuses = {
    for (final p in AppPermission.values) p: AppPermissionStatus.unknown,
  };

  bool get initialised => _initialised;
  bool get hasCompletedFirstTimePrompt => _hasCompletedFirstTimePrompt;
  Map<AppPermission, AppPermissionStatus> get statuses =>
      Map.unmodifiable(_statuses);

  /// Permissions Android won't let us re-prompt for. Recovery for these is
  /// the system-settings page.
  List<AppPermission> get permanentlyDenied => AppPermission.values
      .where((p) => _statuses[p]?.permanentlyDenied ?? false)
      .toList(growable: false);

  /// Permissions that aren't currently granted (denied, restricted, or
  /// permanently denied). What the banner reflects.
  List<AppPermission> get missing => AppPermission.values
      .where((p) => !(_statuses[p]?.granted ?? false))
      .toList(growable: false);

  bool get hasAnyMissing => missing.isNotEmpty;
  bool get anyPermanentlyDenied => permanentlyDenied.isNotEmpty;

  /// Idempotent. Loads the persisted prompt flag and queries current Android
  /// statuses. Call once after Firebase/app init, then again on app resume
  /// via [refresh].
  Future<void> init() async {
    if (_initialised) return;
    final prefs = await SharedPreferences.getInstance();
    _hasCompletedFirstTimePrompt = prefs.getBool(_firstTimePromptKey) ?? false;
    await _refresh(notify: false);
    _initialised = true;
    notifyListeners();
  }

  /// Re-query Android for current statuses. Call on app resume — the user
  /// might have toggled permissions in system settings while we were
  /// backgrounded.
  Future<void> refresh() => _refresh(notify: true);

  Future<void> _refresh({required bool notify}) async {
    _statuses = await PermissionService.queryAll();
    if (notify) notifyListeners();
  }

  /// Fire native dialogs for not-yet-granted permissions; refresh state.
  /// Safe to call even when nothing is missing (it's a no-op then).
  Future<void> requestAll() async {
    _statuses = await PermissionService.requestAll();
    notifyListeners();
  }

  /// Open Android's app-settings page. Use this when [anyPermanentlyDenied]
  /// is true — calling [requestAll] in that state is silently a no-op.
  Future<void> openSystemSettings() async {
    await PermissionService.openSystemSettings();
    // Don't refresh here — the user is now off-app. The lifecycle resume
    // handler picks it up when they come back.
  }

  /// Persist "we've shown the explainer once". Idempotent.
  Future<void> markFirstTimePromptCompleted() async {
    if (_hasCompletedFirstTimePrompt) return;
    _hasCompletedFirstTimePrompt = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_firstTimePromptKey, true);
    } catch (e) {
      AppLogger.warning('Failed to persist first-time prompt flag: $e');
    }
  }
}
