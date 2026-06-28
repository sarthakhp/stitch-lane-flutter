import 'control_doc.dart';

enum SyncRole { writer, reader, unconfigured }

/// Pure function — no side effects, fully unit-testable.
///
/// Rules:
/// - Flag off or no uid → unconfigured (app behaves exactly as today).
/// - No control doc (fresh account, never claimed) → unconfigured.
/// - Control doc names this device → writer.
/// - Control doc names another device → reader.
SyncRole computeRole({
  required bool enabled,
  required String? uid,
  required String? myDeviceId,
  required ControlDoc? control,
}) {
  if (!enabled || uid == null || myDeviceId == null) return SyncRole.unconfigured;
  if (control == null) return SyncRole.unconfigured;
  if (control.writerDeviceId == myDeviceId) return SyncRole.writer;
  return SyncRole.reader;
}
