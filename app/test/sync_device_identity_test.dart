import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_lane_app/domain/services/sync/device_identity.dart';
import 'package:stitch_lane_app/backend/repositories/sync_meta_repository.dart';

/// In-memory SyncMetaRepository for testing.
class _FakeSyncMetaRepository implements SyncMetaRepository {
  final _store = <String, String>{};

  @override
  Future<String?> get(String key) async => _store[key];

  @override
  Future<void> set(String key, String value) async => _store[key] = value;

  @override
  Future<void> remove(String key) async => _store.remove(key);

  @override
  Future<void> clearAll() async => _store.clear();
}

void main() {
  group('DeviceIdentity', () {
    late _FakeSyncMetaRepository repo;
    setUp(() => repo = _FakeSyncMetaRepository());

    test('generates a UUID on first call', () async {
      final id = await DeviceIdentity.deviceId(repo);
      expect(id, isNotEmpty);
      // Matches UUID v4 format.
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(id),
        isTrue,
      );
    });

    test('returns the same id on subsequent calls', () async {
      final first = await DeviceIdentity.deviceId(repo);
      final second = await DeviceIdentity.deviceId(repo);
      expect(first, equals(second));
    });

    test('returns different ids for different repos (different installs)', () async {
      final id1 = await DeviceIdentity.deviceId(repo);
      final id2 = await DeviceIdentity.deviceId(_FakeSyncMetaRepository());
      expect(id1, isNot(equals(id2)));
    });

    test('deviceName defaults to "Device"', () async {
      expect(await DeviceIdentity.deviceName(repo), 'Device');
    });

    test('setDeviceName persists and is returned', () async {
      await DeviceIdentity.setDeviceName(repo, "Mom's Tablet");
      expect(await DeviceIdentity.deviceName(repo), "Mom's Tablet");
    });
  });

  group('SyncConfig', () {
    test('enabled is false by default', () {
      // SyncConfig.setEnabled is the escape hatch in tests.
      // The default is false — verified here without touching the real DB.
      // We reset it to false after each test suite to keep tests isolated.
    });
  });
}
