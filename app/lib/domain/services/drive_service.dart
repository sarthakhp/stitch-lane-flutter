import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'drive_auth_service.dart';
import 'backup_guard.dart';
import '../../utils/app_logger.dart';
import '../../constants/app_constants.dart';

class DriveService {
  static const String appFolderName = AppConstants.appName;
  static const String backupFileName = 'stitch_genie_backup.json';
  static const String _legacyBackupFileName = 'stitch_lane_backup.json';
  static const String imagesFolderName = 'images';
  static const String audiosFolderName = 'audios';

  /// Whether Google Drive is usable right now. All Drive-auth logic lives in
  /// [DriveAuthService], kept separate from the app session — see that class.
  static Future<bool> isSignedIn() => DriveAuthService.isConnected();

  /// Authenticated Drive client. Delegates to [DriveAuthService], which throws
  /// [DriveAuthException] when an interactive reconnect is required.
  static Future<drive.DriveApi> getDriveApi() => DriveAuthService.getDriveApi();

  static Future<String?> _getAppDataFolderId(drive.DriveApi driveApi) async {
    return 'appDataFolder';
  }

  static Future<String?> _findBackupFile(drive.DriveApi driveApi, String folderId) async {
    for (final fileName in [backupFileName, _legacyBackupFileName]) {
      final fileList = await driveApi.files.list(
        q: "name='$fileName' and '$folderId' in parents and trashed=false",
        spaces: 'appDataFolder',
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        if (fileName == _legacyBackupFileName) {
          AppLogger.info('Found legacy backup file, will migrate to new name on next backup');
        }
        return fileList.files!.first.id;
      }
    }

    return null;
  }

  static Future<void> uploadBackup(String jsonData) async {
    // Last line of defense: never overwrite the cloud backup with an empty
    // dataset (0 customers AND 0 orders), e.g. a backup firing right after a
    // fresh sign-in before any data exists. The runners check this up front for
    // good UX; this guard catches any caller — including future ones — that
    // reaches the actual irreversible overwrite. See [BackupGuard].
    if (BackupGuard.isEmptyBackupJson(jsonData)) {
      AppLogger.warning(
        'Refusing to upload an empty backup (0 customers, 0 orders) — '
        'existing Drive backup left untouched.',
      );
      throw const EmptyBackupException();
    }

    AppLogger.info('Starting backup upload...');
    final driveApi = await getDriveApi();
    final folderId = await _getAppDataFolderId(driveApi);

    if (folderId == null) {
      throw Exception('Failed to access app data folder');
    }

    AppLogger.info('Checking for existing backup file...');
    final existingFileId = await _findBackupFile(driveApi, folderId);

    final bytes = utf8.encode(jsonData);
    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
    );

    if (existingFileId != null) {
      AppLogger.info('Updating existing backup file...');
      await driveApi.files.update(
        drive.File(),
        existingFileId,
        uploadMedia: media,
      );
      AppLogger.info('Backup file updated successfully');
    } else {
      AppLogger.info('Creating new backup file...');
      final file = drive.File()
        ..name = backupFileName
        ..parents = [folderId];

      await driveApi.files.create(
        file,
        uploadMedia: media,
      );
      AppLogger.info('Backup file created successfully');
    }
  }

  static Future<String?> downloadBackup() async {
    final driveApi = await getDriveApi();
    final folderId = await _getAppDataFolderId(driveApi);

    if (folderId == null) {
      throw Exception('Failed to access app data folder');
    }

    final fileId = await _findBackupFile(driveApi, folderId);

    if (fileId == null) {
      return null;
    }

    final response = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final dataBytes = <int>[];
    await for (var chunk in response.stream) {
      dataBytes.addAll(chunk);
    }

    return utf8.decode(dataBytes);
  }

  static Future<BackupInfo?> getBackupInfo() async {
    try {
      final driveApi = await getDriveApi();
      final folderId = await _getAppDataFolderId(driveApi);

      if (folderId == null) {
        return null;
      }

      drive.File? file;
      for (final fileName in [backupFileName, _legacyBackupFileName]) {
        final fileList = await driveApi.files.list(
          q: "name='$fileName' and '$folderId' in parents and trashed=false",
          spaces: 'appDataFolder',
          $fields: 'files(id, name, size, modifiedTime)',
        );
        if (fileList.files != null && fileList.files!.isNotEmpty) {
          file = fileList.files!.first;
          break;
        }
      }

      if (file == null) {
        return null;
      }
      final backupSize = int.tryParse(file.size ?? '0') ?? 0;

      final images = await DriveServiceImageOperations.listImagesInFolder(driveApi);
      final imagesSize = images.fold<int>(
        0,
        (sum, img) => sum + (int.tryParse(img['size']?.toString() ?? '0') ?? 0),
      );

      final audios = await DriveServiceAudioOperations.listAudiosInFolder(driveApi);
      final audiosSize = audios.fold<int>(
        0,
        (sum, audio) => sum + (int.tryParse(audio['size']?.toString() ?? '0') ?? 0),
      );

      return BackupInfo(
        lastModified: file.modifiedTime ?? DateTime.now(),
        size: backupSize + imagesSize + audiosSize,
      );
    } catch (e) {
      return null;
    }
  }
}

class BackupInfo {
  final DateTime lastModified;
  final int size;

  BackupInfo({
    required this.lastModified,
    required this.size,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

extension DriveServiceImageOperations on DriveService {
  static Future<String?> _getImagesFolderId(drive.DriveApi driveApi) async {
    final folderId = await DriveService._getAppDataFolderId(driveApi);
    if (folderId == null) return null;

    final fileList = await driveApi.files.list(
      q: "name='${DriveService.imagesFolderName}' and '$folderId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false",
      spaces: 'appDataFolder',
      $fields: 'files(id, name)',
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first.id;
    }

    final folderMetadata = drive.File()
      ..name = DriveService.imagesFolderName
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = [folderId];

    final folder = await driveApi.files.create(
      folderMetadata,
      $fields: 'id',
    );

    AppLogger.info('Created images folder: ${folder.id}');
    return folder.id;
  }

  static Future<List<Map<String, dynamic>>> listImagesInFolder(drive.DriveApi driveApi) async {
    final imagesFolderId = await _getImagesFolderId(driveApi);
    if (imagesFolderId == null) return [];

    final results = <Map<String, dynamic>>[];
    String? pageToken;

    do {
      final fileList = await driveApi.files.list(
        q: "'$imagesFolderId' in parents and trashed=false",
        spaces: 'appDataFolder',
        $fields: 'nextPageToken, files(id, name, size, modifiedTime)',
        pageSize: 1000,
        pageToken: pageToken,
      );

      if (fileList.files != null) {
        results.addAll(fileList.files!.map((file) => {
          'id': file.id,
          'name': file.name,
          'size': file.size,
          'modifiedTime': file.modifiedTime,
        }));
      }

      pageToken = fileList.nextPageToken;
    } while (pageToken != null);

    return results;
  }

  static Future<void> uploadImage(drive.DriveApi driveApi, String fileName, List<int> imageBytes) async {
    final imagesFolderId = await _getImagesFolderId(driveApi);
    if (imagesFolderId == null) {
      throw Exception('Failed to access images folder');
    }

    final fileList = await driveApi.files.list(
      q: "name='$fileName' and '$imagesFolderId' in parents and trashed=false",
      spaces: 'appDataFolder',
      $fields: 'files(id)',
    );

    final media = drive.Media(
      Stream.value(imageBytes),
      imageBytes.length,
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      await driveApi.files.update(
        drive.File(),
        fileList.files!.first.id!,
        uploadMedia: media,
      );
      AppLogger.info('Updated existing image: $fileName');
    } else {
      final fileMetadata = drive.File()
        ..name = fileName
        ..parents = [imagesFolderId];

      await driveApi.files.create(
        fileMetadata,
        uploadMedia: media,
      );
      AppLogger.info('Uploaded new image: $fileName');
    }
  }

  static Future<List<int>?> downloadImage(drive.DriveApi driveApi, String fileId) async {
    try {
      final media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> dataStore = [];
      await for (var data in media.stream) {
        dataStore.addAll(data);
      }

      return dataStore;
    } catch (e) {
      AppLogger.error('Failed to download image', e);
      return null;
    }
  }

  static Future<void> deleteImageFromDrive(drive.DriveApi driveApi, String fileId) async {
    try {
      await driveApi.files.delete(fileId);
      AppLogger.info('Deleted image from Drive: $fileId');
    } catch (e) {
      AppLogger.error('Failed to delete image from Drive', e);
      rethrow;
    }
  }
}

extension DriveServiceAudioOperations on DriveService {
  static Future<String?> _getAudiosFolderId(drive.DriveApi driveApi) async {
    final folderId = await DriveService._getAppDataFolderId(driveApi);
    if (folderId == null) return null;

    final fileList = await driveApi.files.list(
      q: "name='${DriveService.audiosFolderName}' and '$folderId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false",
      spaces: 'appDataFolder',
      $fields: 'files(id, name)',
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first.id;
    }

    final folderMetadata = drive.File()
      ..name = DriveService.audiosFolderName
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = [folderId];

    final folder = await driveApi.files.create(
      folderMetadata,
      $fields: 'id',
    );

    AppLogger.info('Created audios folder: ${folder.id}');
    return folder.id;
  }

  static Future<List<Map<String, dynamic>>> listAudiosInFolder(drive.DriveApi driveApi) async {
    final audiosFolderId = await _getAudiosFolderId(driveApi);
    if (audiosFolderId == null) return [];

    final results = <Map<String, dynamic>>[];
    String? pageToken;

    do {
      final fileList = await driveApi.files.list(
        q: "'$audiosFolderId' in parents and trashed=false",
        spaces: 'appDataFolder',
        $fields: 'nextPageToken, files(id, name, size, modifiedTime)',
        pageSize: 1000,
        pageToken: pageToken,
      );

      if (fileList.files != null) {
        results.addAll(fileList.files!.map((file) => {
          'id': file.id,
          'name': file.name,
          'size': file.size,
          'modifiedTime': file.modifiedTime,
        }));
      }

      pageToken = fileList.nextPageToken;
    } while (pageToken != null);

    return results;
  }

  static Future<void> uploadAudio(drive.DriveApi driveApi, String fileName, List<int> audioBytes) async {
    final audiosFolderId = await _getAudiosFolderId(driveApi);
    if (audiosFolderId == null) {
      throw Exception('Failed to access audios folder');
    }

    final fileList = await driveApi.files.list(
      q: "name='$fileName' and '$audiosFolderId' in parents and trashed=false",
      spaces: 'appDataFolder',
      $fields: 'files(id)',
    );

    final media = drive.Media(
      Stream.value(audioBytes),
      audioBytes.length,
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      await driveApi.files.update(
        drive.File(),
        fileList.files!.first.id!,
        uploadMedia: media,
      );
      AppLogger.info('Updated existing audio: $fileName');
    } else {
      final fileMetadata = drive.File()
        ..name = fileName
        ..parents = [audiosFolderId];

      await driveApi.files.create(
        fileMetadata,
        uploadMedia: media,
      );
      AppLogger.info('Uploaded new audio: $fileName');
    }
  }

  static Future<List<int>?> downloadAudio(drive.DriveApi driveApi, String fileId) async {
    try {
      final media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> dataStore = [];
      await for (var data in media.stream) {
        dataStore.addAll(data);
      }

      return dataStore;
    } catch (e) {
      AppLogger.error('Failed to download audio', e);
      return null;
    }
  }

  static Future<void> deleteAudioFromDrive(drive.DriveApi driveApi, String fileId) async {
    try {
      await driveApi.files.delete(fileId);
      AppLogger.info('Deleted audio from Drive: $fileId');
    } catch (e) {
      AppLogger.error('Failed to delete audio from Drive', e);
      rethrow;
    }
  }
}
