import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../backend/repositories/sync_meta_repository.dart';
import '../services/sync/control_doc.dart';
import '../services/sync/device_identity.dart';
import '../services/sync/firestore_gateway.dart';
import '../services/sync/sync_config.dart';
import '../services/sync/sync_keys.dart';
import '../services/sync/sync_role.dart';
import 'auth_controller.dart';

/// Reactive sync state: current device role, writer name, and error.
///
/// Wired via [ChangeNotifierProxyProvider<AuthController, SyncState>] so it
/// re-evaluates whenever the auth uid changes.
///
/// Offline resilience: on startup we load the last-seen control doc from
/// sync_meta before waiting for Firestore, so an offline writer stays a
/// writer (Firestore's own offline cache also covers this, but the local
/// copy is a belt-and-suspenders fallback in case that cache is cleared).
class SyncState extends ChangeNotifier {
  final FirestoreGateway _gateway;
  final SyncMetaRepository _metaRepo;

  SyncRole _role = SyncRole.unconfigured;
  String? _writerDeviceName;
  String? _myDeviceId;
  int _myEpoch = 0;
  String? _lastError;

  StreamSubscription<ControlDoc?>? _controlSub;
  String? _currentUid;

  SyncRole get role => _role;

  /// True unless this device is an explicit reader. Unconfigured == full write
  /// access (legacy / flag-off behaviour). Defaults true so Flag OFF ⇒ no
  /// change in behaviour anywhere the app gates on canWrite.
  bool get canWrite => _role != SyncRole.reader;

  String? get writerDeviceName => _writerDeviceName;

  /// The epoch under which this device claimed writer. Used by the push pump
  /// fence check (Phase 3).
  int get myEpoch => _myEpoch;

  String? get myDeviceId => _myDeviceId;
  String? get lastError => _lastError;

  /// The signed-in uid this state is subscribed to (null when signed out). Used
  /// by the sync coordinator/pump to scope Firestore reads and writes.
  String? get currentUid => _currentUid;

  SyncState({
    required FirestoreGateway gateway,
    required SyncMetaRepository metaRepo,
  })  : _gateway = gateway,
        _metaRepo = metaRepo;

  // ── auth integration (called by ChangeNotifierProxyProvider) ─────────────

  void updateAuth(AuthController authController) {
    final uid = authController.uid;
    if (uid == _currentUid) return;
    _startSubscription(uid);
  }

  /// Re-evaluate the role against the current uid. Call after toggling
  /// [SyncConfig.enabled] at runtime (enable / disable in settings) so the
  /// control subscription starts or stops and the role recomputes immediately.
  Future<void> refresh() => _startSubscription(_currentUid);

  /// Tear down the live Firestore control listener and drop to `unconfigured`.
  /// Called at the very start of sign-out so the listener can't fire
  /// permission-denied while Firebase auth is being cleared. The role recomputes
  /// on the next [updateAuth] / [refresh] after a fresh sign-in.
  Future<void> stop() async {
    await _controlSub?.cancel();
    _controlSub = null;
    _setRole(SyncRole.unconfigured, null);
  }

  // ── subscription lifecycle ────────────────────────────────────────────────

  Future<void> _startSubscription(String? uid) async {
    await _controlSub?.cancel();
    _controlSub = null;
    _currentUid = uid;

    _myDeviceId ??= await DeviceIdentity.deviceId(_metaRepo);

    if (uid == null || !SyncConfig.enabled) {
      _setRole(SyncRole.unconfigured, null);
      return;
    }

    // Apply any cached control doc immediately so the device's role is known
    // before the first Firestore emission (important when offline at launch).
    final cached = await _loadCachedControl();
    if (cached != null) {
      _setRole(
        computeRole(
            enabled: SyncConfig.enabled,
            uid: uid,
            myDeviceId: _myDeviceId,
            control: cached),
        cached,
      );
    }

    _controlSub = _gateway.watchControl(uid).listen(
      (doc) => _onControlDoc(uid, doc),
      onError: (Object e) {
        _lastError = e.toString();
        notifyListeners();
      },
    );
  }

  void _onControlDoc(String uid, ControlDoc? doc) async {
    if (doc != null) {
      // Persist for offline resilience.
      await _metaRepo.set(SyncMetaKeys.cachedControl, jsonEncode(doc.toMap()));
      // Track epoch so the push pump can fence-check correctly (Phase 3).
      if (doc.writerDeviceId == _myDeviceId) {
        _myEpoch = doc.epoch;
        await _metaRepo.set(SyncMetaKeys.writerEpoch, doc.epoch.toString());
      }
    }
    _setRole(
      computeRole(
          enabled: SyncConfig.enabled,
          uid: uid,
          myDeviceId: _myDeviceId,
          control: doc),
      doc,
    );
  }

  void _setRole(SyncRole role, ControlDoc? doc) {
    _role = role;
    _writerDeviceName = doc?.writerDeviceName;
    notifyListeners();
  }

  Future<ControlDoc?> _loadCachedControl() async {
    final raw = await _metaRepo.get(SyncMetaKeys.cachedControl);
    if (raw == null) return null;
    try {
      return ControlDoc.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _controlSub?.cancel();
    super.dispose();
  }
}
