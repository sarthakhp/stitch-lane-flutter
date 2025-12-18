import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'auth_service.dart';
import '../../utils/app_logger.dart';

class DriveService {
  static const String appFolderName = 'Stitch Lane';
  static const String backupFileName = 'stitch_lane_backup.json';

  static Future<drive.DriveApi> _getDriveApi() async {
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
    final driveApi = await _getDriveApi();
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
    final driveApi = await _getDriveApi();
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
      final driveApi = await _getDriveApi();
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
      return BackupInfo(
        lastModified: file.modifiedTime ?? DateTime.now(),
        size: int.tryParse(file.size ?? '0') ?? 0,
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

