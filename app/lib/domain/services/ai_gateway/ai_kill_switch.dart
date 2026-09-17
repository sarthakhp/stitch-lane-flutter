import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../utils/app_logger.dart';

/// Remote, instant "stop all AI calls" switch — a stopgap for the period
/// before the wallet/billing system exists, when AI cost is unmetered per
/// user. Backed by a single Firestore doc so flipping it takes effect on
/// every installed app within a session, with no store release needed.
///
/// Fails open: if the doc can't be read (offline, permission issue, doc not
/// yet created), AI stays enabled. This is a cost-safety lever, not the
/// primary correctness mechanism — an outage here should not break the
/// app's core AI features for everyone.
class AiKillSwitch {
  AiKillSwitch._();

  static const _collection = 'app_config';
  static const _doc = 'global';
  static const _field = 'aiEnabled';

  static bool _enabled = true;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _subscription;

  static bool get enabled => _enabled;

  /// Call once after Firebase is ready. Starts a live listener so a remote
  /// toggle is picked up immediately, not just at next app launch.
  static void listen() {
    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection(_collection)
        .doc(_doc)
        .snapshots()
        .listen(
      (snapshot) {
        final value = snapshot.data()?[_field];
        _enabled = value is bool ? value : true;
        if (!_enabled) {
          AppLogger.warning('AiKillSwitch: AI features remotely disabled');
        }
      },
      onError: (e) {
        AppLogger.warning('AiKillSwitch: listener error, defaulting to enabled: $e');
        _enabled = true;
      },
    );
  }

  /// Test-only escape hatch.
  static void setEnabledForTesting(bool value) => _enabled = value;
}
