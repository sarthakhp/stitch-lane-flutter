import 'dart:io';

import 'package:path/path.dart' as p;

import '../audio_backup_recorder.dart';
import '../drive_service.dart';
import '../image_storage_service.dart';
import 'media_cache.dart';

/// Downloads the Drive media file named [fileName] into [target]. Returns true
/// on success. Implementations MUST be safe when offline / signed out (return
/// false, never throw).
typedef MediaDownloader = Future<bool> Function(String fileName, File target);

/// Resolves a stored media reference to a readable local file.
///
/// Media refs are device-absolute paths whose **basename is the stable
/// cross-device identity** (it is the Drive file name). On the writer / a
/// single device the stored path resolves directly. On a reader the path is
/// foreign, so we resolve by basename into this device's media directory and
/// lazy-download from Drive on first view. A failure (offline, not on Drive)
/// returns null, and the caller shows its existing "unavailable" affordance.
///
/// The directory providers and downloaders are static seams so tests can point
/// them at temp dirs / fakes without a live Drive or path_provider.
class MediaResolver {
  MediaResolver._();

  static Future<Directory> Function() imagesDir =
      ImageStorageService.imagesDirectory;
  static Future<Directory> Function() audioDir =
      AudioBackupRecorder.backupsDirectory;
  static MediaDownloader imageDownloader = _downloadImageFromDrive;
  static MediaDownloader audioDownloader = _downloadAudioFromDrive;

  static Future<File?> resolveImage(String storedPath) =>
      _resolve(storedPath, imagesDir, imageDownloader);

  static Future<File?> resolveAudio(String storedPath) =>
      _resolve(storedPath, audioDir, audioDownloader);

  static Future<File?> _resolve(
    String storedPath,
    Future<Directory> Function() dirProvider,
    MediaDownloader downloader,
  ) async {
    if (storedPath.isEmpty) return null;

    // 1) Stored path resolves directly (writer / single device). Fast path:
    //    no directory lookup, no Drive — identical to today's behaviour.
    final direct = File(storedPath);
    if (await direct.exists()) return direct;

    // 2) Already cached in this device's media dir by basename.
    final name = p.basename(storedPath);
    final dir = await dirProvider();
    final local = File(p.join(dir.path, name));
    if (await local.exists()) return local;

    // 3) Cold media: lazy-download by basename from Drive. Goes through
    //    MediaCache for an atomic (temp + rename) write and so an on-view fetch
    //    shares a single download with the background hydration sweep.
    return MediaCache.fetch(name, dir, downloader);
  }

  static Future<bool> _downloadImageFromDrive(
      String fileName, File target) async {
    final driveApi = await DriveService.getDriveApi();
    final files = await DriveServiceImageOperations.listImagesInFolder(driveApi);
    final id = _idForName(files, fileName);
    if (id == null) return false;
    final bytes = await DriveServiceImageOperations.downloadImage(driveApi, id);
    if (bytes == null) return false;
    await target.writeAsBytes(bytes);
    return true;
  }

  static Future<bool> _downloadAudioFromDrive(
      String fileName, File target) async {
    final driveApi = await DriveService.getDriveApi();
    final files = await DriveServiceAudioOperations.listAudiosInFolder(driveApi);
    final id = _idForName(files, fileName);
    if (id == null) return false;
    final bytes = await DriveServiceAudioOperations.downloadAudio(driveApi, id);
    if (bytes == null) return false;
    await target.writeAsBytes(bytes);
    return true;
  }

  static String? _idForName(
      List<Map<String, dynamic>> files, String fileName) {
    for (final f in files) {
      if (f['name'] == fileName) return f['id'] as String?;
    }
    return null;
  }
}
