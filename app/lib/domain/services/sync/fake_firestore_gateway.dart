import 'dart:async';

import 'control_doc.dart';
import 'doc_change.dart';
import 'firestore_gateway.dart';

/// In-memory [FirestoreGateway] for unit tests. No live Firestore needed.
///
/// Streams emit immediately when data changes via [seedEntity] / [upsert] /
/// [delete]. Use [snapshotOf] / [controlOf] to inspect state in assertions.
class FakeFirestoreGateway implements FirestoreGateway {
  // uid → collection → id → data
  final _store = <String, Map<String, Map<String, Map<String, dynamic>>>>{};
  final _controls = <String, ControlDoc?>{};

  final _controlStreams = <String, StreamController<ControlDoc?>>{};
  // uid_collection → stream controller
  final _collectionStreams = <String, StreamController<List<DocChange>>>{};

  // ── test helpers ─────────────────────────────────────────────────────────

  /// Pre-populate an entity doc without triggering stream listeners.
  void seedEntity(
      String uid, String collection, String id, Map<String, dynamic> data) {
    _collection(uid, collection)[id] = Map.of(data);
  }

  /// Pre-populate the control doc without triggering stream listeners.
  void seedControl(String uid, ControlDoc doc) {
    _controls[uid] = doc;
  }

  Map<String, Map<String, dynamic>> snapshotOf(
          String uid, String collection) =>
      Map.unmodifiable(_collection(uid, collection));

  ControlDoc? controlOf(String uid) => _controls[uid];

  // ── FirestoreGateway ─────────────────────────────────────────────────────

  @override
  Future<ControlDoc?> readControl(String uid) async => _controls[uid];

  @override
  Stream<ControlDoc?> watchControl(String uid) {
    final ctrl = _controlStreams.putIfAbsent(
        uid, () => StreamController<ControlDoc?>.broadcast());
    // Emit current value to new subscriber immediately.
    scheduleMicrotask(() => ctrl.add(_controls[uid]));
    return ctrl.stream;
  }

  @override
  Future<void> runControlTransaction(
    String uid,
    ControlDoc? Function(ControlDoc? current) update,
  ) async {
    final current = _controls[uid];
    final updated = update(current);
    if (updated == null) return;
    _controls[uid] = updated;
    _controlStreams[uid]?.add(updated);
  }

  @override
  Future<void> upsert(
    String uid,
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    final col = _collection(uid, collection);
    final isNew = !col.containsKey(id);
    col[id] = Map.of(data);
    _emitChange(uid, collection, [
      DocChange(
        kind: isNew ? DocChangeKind.added : DocChangeKind.modified,
        id: id,
        data: col[id],
      ),
    ]);
  }

  @override
  Future<void> delete(String uid, String collection, String id) async {
    final col = _collection(uid, collection);
    if (!col.containsKey(id)) return;
    col.remove(id);
    _emitChange(uid, collection, [
      DocChange(kind: DocChangeKind.removed, id: id),
    ]);
  }

  @override
  Future<void> upsertBatch(
    String uid,
    String collection,
    List<(String, Map<String, dynamic>)> docs,
  ) async {
    final col = _collection(uid, collection);
    final changes = <DocChange>[];
    for (final (id, data) in docs) {
      final isNew = !col.containsKey(id);
      col[id] = Map.of(data);
      changes.add(DocChange(
        kind: isNew ? DocChangeKind.added : DocChangeKind.modified,
        id: id,
        data: col[id],
      ));
    }
    if (changes.isNotEmpty) _emitChange(uid, collection, changes);
  }

  @override
  Stream<List<DocChange>> watchCollection(String uid, String collection) {
    final key = '${uid}_$collection';
    final ctrl = _collectionStreams.putIfAbsent(
        key, () => StreamController<List<DocChange>>.broadcast());
    // Emit the full initial snapshot as 'added' events.
    scheduleMicrotask(() {
      final initial = _collection(uid, collection)
          .entries
          .map((e) =>
              DocChange(kind: DocChangeKind.added, id: e.key, data: e.value))
          .toList();
      ctrl.add(initial);
    });
    return ctrl.stream;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAll(
      String uid, String collection) async {
    return _collection(uid, collection)
        .entries
        .map((e) => {'id': e.key, ...e.value})
        .toList();
  }

  // ── internals ─────────────────────────────────────────────────────────────

  Map<String, Map<String, dynamic>> _collection(
      String uid, String collection) {
    return _store
        .putIfAbsent(uid, () => {})
        .putIfAbsent(collection, () => {});
  }

  void _emitChange(String uid, String collection, List<DocChange> changes) {
    final key = '${uid}_$collection';
    _collectionStreams[key]?.add(changes);
  }
}
