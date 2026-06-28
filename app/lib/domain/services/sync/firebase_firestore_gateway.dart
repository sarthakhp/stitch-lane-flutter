import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'control_doc.dart';
import 'doc_change.dart';
import 'firestore_gateway.dart';

class FirebaseFirestoreGateway implements FirestoreGateway {
  // Held lazily: this gateway is constructed eagerly at app start (the
  // SyncCoordinator provider is `lazy: false`), but Firebase.initializeApp()
  // runs afterwards in the startup orchestrator. Touching
  // FirebaseFirestore.instance in the constructor would throw [core/no-app].
  // We resolve the instance on first real use instead — by then Firebase is up
  // (all gateway calls happen post-sign-in). Tests inject [db] directly.
  final FirebaseFirestore? _injected;
  FirebaseFirestore? _resolved;

  FirebaseFirestoreGateway({FirebaseFirestore? db}) : _injected = db;

  FirebaseFirestore get _db =>
      _injected ?? (_resolved ??= FirebaseFirestore.instance);

  // ── path helpers ─────────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _controlRef(String uid) =>
      _db.doc('users/$uid/meta/control');

  DocumentReference<Map<String, dynamic>> _entityRef(
          String uid, String collection, String id) =>
      _db.doc('users/$uid/$collection/$id');

  CollectionReference<Map<String, dynamic>> _entityCollection(
          String uid, String collection) =>
      _db.collection('users/$uid/$collection');

  // ── control doc ──────────────────────────────────────────────────────────

  @override
  Future<ControlDoc?> readControl(String uid) async {
    final snap = await _controlRef(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return ControlDoc.fromMap(_sanitize(snap.data()!));
  }

  @override
  Stream<ControlDoc?> watchControl(String uid) {
    return _controlRef(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return ControlDoc.fromMap(_sanitize(snap.data()!));
    });
  }

  @override
  Future<void> runControlTransaction(
    String uid,
    ControlDoc? Function(ControlDoc? current) update,
  ) async {
    final ref = _controlRef(uid);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final current = (snap.exists && snap.data() != null)
          ? ControlDoc.fromMap(_sanitize(snap.data()!))
          : null;
      final updated = update(current);
      if (updated == null) return;
      final map = updated.toMap();
      map['updatedAt'] = FieldValue.serverTimestamp();
      if (current == null) map['claimedAt'] = FieldValue.serverTimestamp();
      txn.set(ref, map);
    });
  }

  // ── entities ─────────────────────────────────────────────────────────────

  @override
  Future<void> upsert(
    String uid,
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    await _entityRef(uid, collection, id).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> delete(String uid, String collection, String id) async {
    await _entityRef(uid, collection, id).delete();
  }

  @override
  Future<void> upsertBatch(
    String uid,
    String collection,
    List<(String, Map<String, dynamic>)> docs,
  ) async {
    const batchSize = 500;
    for (var i = 0; i < docs.length; i += batchSize) {
      final chunk = docs.sublist(i, min(i + batchSize, docs.length));
      final batch = _db.batch();
      for (final (id, data) in chunk) {
        batch.set(_entityRef(uid, collection, id), {
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  @override
  Stream<List<DocChange>> watchCollection(String uid, String collection) {
    return _entityCollection(uid, collection).snapshots().map((snap) {
      return snap.docChanges.map((change) {
        final kind = switch (change.type) {
          DocumentChangeType.added => DocChangeKind.added,
          DocumentChangeType.modified => DocChangeKind.modified,
          DocumentChangeType.removed => DocChangeKind.removed,
        };
        return DocChange(
          kind: kind,
          id: change.doc.id,
          data: change.doc.exists ? _sanitize(change.doc.data()!) : null,
        );
      }).toList();
    });
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAll(
      String uid, String collection) async {
    final snap = await _entityCollection(uid, collection).get();
    return snap.docs.map((doc) => _sanitize(doc.data())).toList();
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  /// Recursively converts Firestore [Timestamp]s to ISO-8601 strings so that
  /// entity models' fromJson never see Firestore-specific types.
  static Map<String, dynamic> _sanitize(Map<String, dynamic> data) {
    return data.map((k, v) => MapEntry(k, _sanitizeValue(v)));
  }

  static dynamic _sanitizeValue(dynamic v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is Map<String, dynamic>) return _sanitize(v);
    if (v is List) return v.map(_sanitizeValue).toList();
    return v;
  }
}
