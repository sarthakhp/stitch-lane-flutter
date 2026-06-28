import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stitch_lane_app/backend/database/sqlite_database.dart';
import 'package:stitch_lane_app/backend/repositories/sqlite_sync_meta_repository.dart';
import 'package:stitch_lane_app/domain/services/sync/control_doc.dart';
import 'package:stitch_lane_app/domain/services/sync/media_resolver.dart';
import 'package:stitch_lane_app/domain/services/sync/sync_keys.dart';
import 'package:stitch_lane_app/domain/services/sync/sync_media_policy.dart';

void main() {
  group('MediaResolver', () {
    late Directory tempImages;
    late int downloadCalls;

    setUp(() {
      tempImages = Directory.systemTemp.createTempSync('media_resolver_imgs_');
      downloadCalls = 0;
      MediaResolver.imagesDir = () async => tempImages;
    });

    tearDown(() {
      MediaResolver.imageDownloader = (name, target) async => false;
      tempImages.deleteSync(recursive: true);
    });

    test('resolves a directly-existing stored path without touching Drive',
        () async {
      final f = File(p.join(tempImages.path, 'a.jpg'))..writeAsBytesSync([1]);
      MediaResolver.imageDownloader = (name, target) async {
        downloadCalls++;
        return false;
      };

      final resolved = await MediaResolver.resolveImage(f.path);

      expect(resolved?.path, f.path);
      expect(downloadCalls, 0);
    });

    test('resolves a foreign path to the local basename when present',
        () async {
      // Cached locally under the basename from a prior view.
      File(p.join(tempImages.path, 'shared.jpg')).writeAsBytesSync([2]);
      MediaResolver.imageDownloader = (name, target) async {
        downloadCalls++;
        return false;
      };

      final resolved =
          await MediaResolver.resolveImage('/writer/device/images/shared.jpg');

      expect(resolved?.path, p.join(tempImages.path, 'shared.jpg'));
      expect(downloadCalls, 0);
    });

    test('lazy-downloads by basename when not cached locally', () async {
      MediaResolver.imageDownloader = (name, target) async {
        downloadCalls++;
        expect(name, 'cold.jpg');
        await target.writeAsBytes([3]);
        return true;
      };

      final resolved =
          await MediaResolver.resolveImage('/writer/device/images/cold.jpg');

      expect(downloadCalls, 1);
      expect(resolved, isNotNull);
      expect(resolved!.path, p.join(tempImages.path, 'cold.jpg'));
      expect(await resolved.exists(), isTrue);
    });

    test('returns null when the file is not on Drive (graceful unavailable)',
        () async {
      MediaResolver.imageDownloader = (name, target) async => false;

      final resolved =
          await MediaResolver.resolveImage('/writer/device/images/missing.jpg');

      expect(resolved, isNull);
    });

    test('returns null for an empty ref', () async {
      expect(await MediaResolver.resolveImage(''), isNull);
    });
  });

  group('SyncMediaPolicy.canManageDriveMedia', () {
    late SqliteSyncMetaRepository meta;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      SqliteDatabase.databaseNameForTesting = 'test_sync_media.db';
    });

    setUp(() async {
      await SqliteDatabase.deleteDb();
      meta = SqliteSyncMetaRepository();
    });

    tearDown(() async {
      await SqliteDatabase.deleteDb();
    });

    test('sync disabled → allowed (legacy / sole-owner behaviour)', () async {
      expect(await SyncMediaPolicy.canManageDriveMedia(meta: meta), isTrue);
    });

    test('writer device → allowed', () async {
      await meta.set(SyncMetaKeys.syncEnabled, '1');
      await meta.set(SyncMetaKeys.deviceId, 'dev-A');
      await meta.set(
        SyncMetaKeys.cachedControl,
        _controlJson(writerDeviceId: 'dev-A'),
      );
      expect(await SyncMediaPolicy.canManageDriveMedia(meta: meta), isTrue);
    });

    test('reader device → denied (never prunes Drive)', () async {
      await meta.set(SyncMetaKeys.syncEnabled, '1');
      await meta.set(SyncMetaKeys.deviceId, 'dev-B');
      await meta.set(
        SyncMetaKeys.cachedControl,
        _controlJson(writerDeviceId: 'dev-A'),
      );
      expect(await SyncMediaPolicy.canManageDriveMedia(meta: meta), isFalse);
    });

    test('enabled but no control cached → denied (safe default)', () async {
      await meta.set(SyncMetaKeys.syncEnabled, '1');
      await meta.set(SyncMetaKeys.deviceId, 'dev-B');
      expect(await SyncMediaPolicy.canManageDriveMedia(meta: meta), isFalse);
    });
  });
}

String _controlJson({required String writerDeviceId}) {
  // Mirror exactly what SyncState caches: jsonEncode(ControlDoc.toMap()).
  final doc = ControlDoc(
    writerDeviceId: writerDeviceId,
    writerDeviceName: 'Tablet',
    epoch: 1,
  );
  return jsonEncode(doc.toMap());
}
