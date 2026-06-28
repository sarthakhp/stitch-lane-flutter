import 'control_doc.dart';
import 'doc_change.dart';

/// The single seam between sync logic and the Firestore SDK.
/// All other sync files depend on this interface — never on cloud_firestore directly.
/// Use [FakeFirestoreGateway] in tests.
abstract class FirestoreGateway {
  // ── control doc ──────────────────────────────────────────────────────────

  Future<ControlDoc?> readControl(String uid);

  Stream<ControlDoc?> watchControl(String uid);

  /// Runs a Firestore transaction on the control doc.
  /// [update] receives the current doc (null if none) and returns the new doc
  /// to write. Returning null is a no-op (nothing is written).
  /// The implementation adds a server-timestamp `updatedAt` on every write.
  Future<void> runControlTransaction(
    String uid,
    ControlDoc? Function(ControlDoc? current) update,
  );

  // ── entities ─────────────────────────────────────────────────────────────

  Future<void> upsert(
    String uid,
    String collection,
    String id,
    Map<String, dynamic> data,
  );

  Future<void> delete(String uid, String collection, String id);

  /// Batch-upserts up to 500 docs per call; the implementation chunks
  /// automatically for larger lists.
  Future<void> upsertBatch(
    String uid,
    String collection,
    List<(String id, Map<String, dynamic> data)> docs,
  );

  /// Live stream of document changes for a collection.
  /// The first emission is the full initial snapshot as [DocChangeKind.added].
  Stream<List<DocChange>> watchCollection(String uid, String collection);

  /// One-shot fetch of all (non-deleted) documents in a collection.
  Future<List<Map<String, dynamic>>> fetchAll(String uid, String collection);
}
