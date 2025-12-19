import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'auth_service.dart';
import '../../utils/app_logger.dart';

class DriveService {
  static const String appFolderName = 'Stitch Lane';
  static const String backupFileName = 'stitch_lane_backup.json';
  static const String imagesFolderName = 'images';
  static const String audiosFolderName = 'audios';

  static Future<drive.DriveApi> getDriveApi() async {
    try {
      AppLogger.info('Attempting to get Drive API access...');

      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        AppLogger.warning('No Firebase user, cannot access Drive');
        throw Exception('User not authenticated');
      }

      final googleSignIn = AuthService.googleSignIn;
      var account = googleSignIn.currentUser;

      if (account == null) {
        AppLogger.warning('No GoogleSignIn user, requesting sign-in...');
        throw Exception('Drive access requires re-authentication. Please sign out and sign in again to enable backup/restore.');
      }

      AppLogger.info('Signed in as: ${account.email}');
      final authClient = await googleSignIn.authenticatedClient();
      if (authClient == null) {
        AppLogger.warning('Failed to get authenticated client');
        throw Exception('Drive access expired. Please sign out and sign in again to enable backup/restore.');
      }

      AppLogger.info('Successfully obtained Drive API access');
      return drive.DriveApi(authClient);
    } catch (e) {
      AppLogger.error('Drive API error', e);
      if (e.toString().contains('popup_failed_to_open')) {
        throw Exception('Please allow popups for this site and try again. Check your browser settings.');
      }
      rethrow;
    }
  }

  static Future<String?> _getAppDataFolderId(drive.DriveApi driveApi) async {
    return 'appDataFolder';
  }

  static Future<String?> _findBackupFile(drive.DriveApi driveApi, String folderId) async {
    final fileList = await driveApi.files.list(
      q: "name='$backupFileName' and '$folderId' in parents and trashed=false",
      spaces: 'appDataFolder',
      $fields: 'files(id, name)',
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first.id;
    }

    return null;
  }

  static Future<void> uploadBackup(String jsonData) async {
    AppLogger.info('Starting backup upload...');
    final driveApi = await getDriveApi();
    final folderId = await _getAppDataFolderId(driveApi);

    if (folderId == null) {
      throw Exception('Failed to access app data folder');
    }

    AppLogger.info('Checking for existing backup file...');
    final existingFileId = await _findBackupFile(driveApi, folderId);

    final media = drive.Media(
      Stream.value(utf8.encode(jsonData)),
      jsonData.length,
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

      final fileList = await driveApi.files.list(
        q: "name='$backupFileName' and '$folderId' in parents and trashed=false",
        spaces: 'appDataFolder',
        $fields: 'files(id, name, size, modifiedTime)',
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        return null;
      }

      final file = fileList.files!.first;
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

    final fileList = await driveApi.files.list(
      q: "'$imagesFolderId' in parents and trashed=false",
      spaces: 'appDataFolder',
      $fields: 'files(id, name, size, modifiedTime)',
    );

    if (fileList.files == null || fileList.files!.isEmpty) {
      return [];
    }

    return fileList.files!.map((file) => {
      'id': file.id,
      'name': file.name,
      'size': file.size,
      'modifiedTime': file.modifiedTime,
    }).toList();
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

    final fileList = await driveApi.files.list(
      q: "'$audiosFolderId' in parents and trashed=false",
      spaces: 'appDataFolder',
      $fields: 'files(id, name, size, modifiedTime)',
    );

    if (fileList.files == null || fileList.files!.isEmpty) {
      return [];
    }

    return fileList.files!.map((file) => {
      'id': file.id,
      'name': file.name,
      'size': file.size,
      'modifiedTime': file.modifiedTime,
    }).toList();
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
