import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stitch_lane_app/domain/services/sync/media_cache.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('media_cache_test');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  File finalFile(String name) => File(p.join(dir.path, name));
  File scratchFile(String name) =>
      File('${p.join(dir.path, name)}${MediaCache.scratchSuffix}');

  test('writes bytes atomically and leaves no scratch on success', () async {
    final result = await MediaCache.fetch('a.jpg', dir, (name, target) async {
      await target.writeAsBytes([1, 2, 3]);
      return true;
    });

    expect(result, isNotNull);
    expect(await finalFile('a.jpg').readAsBytes(), [1, 2, 3]);
    expect(await scratchFile('a.jpg').exists(), isFalse,
        reason: 'scratch must be renamed away, not left behind');
  });

  test('failed download leaves NO partial file at the final path', () async {
    final result = await MediaCache.fetch('b.jpg', dir, (name, target) async {
      // Simulate a partial write that then fails — must not surface as a good
      // file at the final path.
      await target.writeAsBytes([9, 9]);
      return false;
    });

    expect(result, isNull);
    expect(await finalFile('b.jpg').exists(), isFalse);
    expect(await scratchFile('b.jpg').exists(), isFalse);
  });

  test('downloader throwing is swallowed and cleans up scratch', () async {
    final result = await MediaCache.fetch('c.jpg', dir, (name, target) async {
      await target.writeAsBytes([5]);
      throw Exception('network died mid-write');
    });

    expect(result, isNull);
    expect(await finalFile('c.jpg').exists(), isFalse);
    expect(await scratchFile('c.jpg').exists(), isFalse);
  });

  test('NEVER overwrites/destroys an existing complete file on failure',
      () async {
    // A good file already on disk (e.g. previously downloaded).
    await finalFile('keep.jpg').writeAsBytes([7, 7, 7]);

    final result = await MediaCache.fetch('keep.jpg', dir, (name, target) async {
      await target.writeAsBytes([0]); // writes to scratch only
      return false; // fails — must not touch the existing final file
    });

    expect(result, isNull);
    expect(await finalFile('keep.jpg').readAsBytes(), [7, 7, 7],
        reason: 'existing media must be left intact');
  });

  test('concurrent fetches for the same file share one download', () async {
    var calls = 0;
    Future<File?> start() => MediaCache.fetch('d.jpg', dir, (name, target) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await target.writeAsBytes([1]);
          return true;
        });

    final results = await Future.wait([start(), start(), start()]);

    expect(calls, 1, reason: 'in-flight dedup must collapse to one download');
    expect(results.every((f) => f != null), isTrue);
  });

  test('cleanScratch removes .part files but never real media', () async {
    await finalFile('real.jpg').writeAsBytes([1]);
    await scratchFile('stale.jpg').writeAsBytes([2]);

    await MediaCache.cleanScratch(dir);

    expect(await finalFile('real.jpg').exists(), isTrue);
    expect(await scratchFile('stale.jpg').exists(), isFalse);
  });
}
