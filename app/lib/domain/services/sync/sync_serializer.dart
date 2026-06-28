import '../../../backend/models/customer.dart';
import '../../../backend/models/measurement.dart';
import '../../../backend/models/order.dart';

/// Turns a domain model into the Firestore document body the writer publishes.
///
/// The body is the model's own `toJson()` (the same shape the backup pipeline
/// already round-trips) plus a tiny envelope. Readers map the body back via
/// `Model.fromJson`, which tolerates unknown fields, so the envelope is free to
/// grow without breaking older readers.
class SyncSerializer {
  SyncSerializer._();

  /// Bumped only on a breaking change to the on-the-wire shape. Lets a future
  /// reader branch on the producer's version instead of guessing.
  static const int schemaVersion = 1;

  static const String schemaField = '_schemaVersion';

  /// Builds the document body for [model]. Throws if [model] is not a synced
  /// entity type — a programming error, never a runtime input.
  static Map<String, dynamic> docFor(Object model) {
    final Map<String, dynamic> body;
    if (model is Customer) {
      body = model.toJson();
    } else if (model is Order) {
      body = model.toJson();
    } else if (model is Measurement) {
      body = model.toJson();
    } else {
      throw ArgumentError('Unsupported sync model: ${model.runtimeType}');
    }
    return {...body, schemaField: schemaVersion};
  }
}
