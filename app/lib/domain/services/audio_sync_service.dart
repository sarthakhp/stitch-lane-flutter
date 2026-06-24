import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import '../../backend/repositories/repository_factory.dart';
import '../../utils/app_logger.dart';
import 'audio_backup_recorder.dart';
import 'drive_service.dart';

class AudioSyncService {
  static Future<void> syncAudiosToDrive({
    void Function(int current, int total, String message)? onProgress,
  }) async {
    try {
      AppLogger.info('Starting audio sync to Drive');

      final driveApi = await DriveService.getDriveApi();
      final localAudioPaths = await _getAllAudioPaths();
      AppLogger.info('Found ${localAudioPaths.length} local audio files');

      final driveAudios = await DriveServiceAudioOperations.listAudiosInFolder(driveApi);
      final driveAudioNames = driveAudios.map((audio) => audio['name'] as String).toSet();
      AppLogger.info('Found ${driveAudioNames.length} audio files in Drive');

      final localAudioNames = localAudioPaths
          .map((path) => _getFileNameFromPath(path))
          .toSet();

      final audiosToUpload = localAudioNames.difference(driveAudioNames).toList();
      final total = audiosToUpload.length;
      AppLogger.info('Audio files to upload: $total');

      for (int i = 0; i < total; i++) {
        final audioName = audiosToUpload[i];
        final current = i + 1;
        final audioPath = localAudioPaths.firstWhere(
          (path) => _getFileNameFromPath(path) == audioName,
        );

        final audioBytes = await _getAudioBytes(audioPath);
        if (audioBytes != null) {
          onProgress?.call(current, total, 'Uploading audio $current of $total');
          await _uploadWithRetry(driveApi, audioName, audioBytes,
            onRetry: (nextAttempt, max) {
              onProgress?.call(current, total,
                'Retrying audio $current of $total (attempt $nextAttempt/$max)');
            },
          );
          AppLogger.info('Uploaded audio: $audioName');
        }
      }

      // SAFETY: never prune when we resolved zero local recordings. That state
      // is ambiguous — it happens both when the user genuinely has no audio AND
      // when [_getAllAudioPaths] swallowed a transient DB error and returned an
      // empty list. Pruning here would delete EVERY audio backup from Drive on
      // a hiccup. Skipping at worst leaves a few orphans; it can't lose data.
      if (localAudioNames.isEmpty) {
        AppLogger.warning(
          'Audio sync: 0 local recordings resolved — skipping Drive prune to '
          'avoid deleting backups. (${driveAudioNames.length} remain in Drive.)',
        );
      } else {
        final audiosToDelete = driveAudioNames.difference(localAudioNames);
        AppLogger.info('Audio files to delete from Drive: ${audiosToDelete.length}');

        for (final audioName in audiosToDelete) {
          final audioFile = driveAudios.firstWhere(
            (audio) => audio['name'] == audioName,
          );
          await DriveServiceAudioOperations.deleteAudioFromDrive(driveApi, audioFile['id'] as String);
          AppLogger.info('Deleted audio from Drive: $audioName');
        }
      }

      AppLogger.info('Audio sync completed successfully');
    } catch (e) {
      AppLogger.error('Failed to sync audio files to Drive', e);
      rethrow;
    }
  }

  static Future<void> _uploadWithRetry(
    drive.DriveApi initialDriveApi,
    String audioName,
    List<int> audioBytes, {
    int maxAttempts = 3,
    void Function(int nextAttempt, int max)? onRetry,
  }) async {
    drive.DriveApi driveApi = initialDriveApi;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await DriveServiceAudioOperations.uploadAudio(driveApi, audioName, audioBytes);
        return;
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        final delaySeconds = attempt * 2;
        AppLogger.warning(
          'Audio upload failed (attempt $attempt/$maxAttempts): $audioName. '
          'Reconnecting in ${delaySeconds}s...',
        );
        onRetry?.call(attempt + 1, maxAttempts);
        await Future.delayed(Duration(seconds: delaySeconds));
        driveApi = await DriveService.getDriveApi();
      }
    }
  }

  static Future<void> downloadAudiosFromDrive({
    void Function(int current, int total, String message)? onProgress,
  }) async {
    try {
      AppLogger.info('Starting audio download from Drive');

      final driveApi = await DriveService.getDriveApi();
      final driveAudios = await DriveServiceAudioOperations.listAudiosInFolder(driveApi);
      AppLogger.info('Found ${driveAudios.length} audio files in Drive');

      // Land downloaded audio in audio_backups/ — where measurement
      // audioFilePaths point after restore (see BackupService._restoreMeasurements).
      final directory = await AudioBackupRecorder.backupsDirectory();

      final total = driveAudios.length;
      for (int i = 0; i < total; i++) {
        final audioFile = driveAudios[i];
        final audioName = audioFile['name'] as String;
        final audioId = audioFile['id'] as String;
        final current = i + 1;

        onProgress?.call(current, total, 'Downloading audio $current of $total');
        final audioBytes = await _downloadAudioWithRetry(
          driveApi,
          audioId,
          audioName,
          onRetry: (nextAttempt, max) {
            onProgress?.call(current, total,
              'Retrying audio $current of $total (attempt $nextAttempt/$max)');
          },
        );
        if (audioBytes != null) {
          final filePath = '${directory.path}/$audioName';
          final file = File(filePath);
          await file.writeAsBytes(audioBytes);
          AppLogger.info('Downloaded and saved audio: $audioName');
        }
      }

      AppLogger.info('Audio download completed successfully');
    } catch (e) {
      AppLogger.error('Failed to download audio files from Drive', e);
      rethrow;
    }
  }

  static Future<List<int>?> _downloadAudioWithRetry(
    drive.DriveApi initialDriveApi,
    String fileId,
    String fileName, {
    int maxAttempts = 3,
    void Function(int nextAttempt, int max)? onRetry,
  }) async {
    drive.DriveApi driveApi = initialDriveApi;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await DriveServiceAudioOperations.downloadAudio(driveApi, fileId);
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        final delaySeconds = attempt * 2;
        AppLogger.warning(
          'Audio download failed (attempt $attempt/$maxAttempts): $fileName. '
          'Reconnecting in ${delaySeconds}s...',
        );
        onRetry?.call(attempt + 1, maxAttempts);
        await Future.delayed(Duration(seconds: delaySeconds));
        driveApi = await DriveService.getDriveApi();
      }
    }
    return null;
  }

  /// Every audio file referenced by a measurement OR an order. Read from each
  /// entity's stored audioFilePaths (not a folder/extension glob), so it
  /// covers the modern audio_backups/*.wav recordings and any legacy
  /// measurement_*.m4a.
  ///
  /// This set drives BOTH what gets uploaded and what gets pruned from Drive
  /// (Drive files absent here are deleted), so every entity that links audio
  /// must be included or its recordings would never sync — and could be
  /// deleted from Drive.
  static Future<List<String>> _getAllAudioPaths() async {
    try {
      final measurements =
          await RepositoryFactory.createMeasurementRepository().getAllMeasurements();
      final orders =
          await RepositoryFactory.createOrderRepository().getAllOrders();

      final paths = <String>[];
      final seen = <String>{};
      Future<void> consider(String p) async {
        if (p.trim().isEmpty) return;
        if (!seen.add(p.split('/').last)) return; // de-dupe by file name
        if (await File(p).exists()) paths.add(p);
      }

      for (final m in measurements) {
        for (final p in m.audioFilePaths) {
          await consider(p);
        }
      }
      for (final o in orders) {
        for (final p in o.audioFilePaths) {
          await consider(p);
        }
      }
      return paths;
    } catch (e) {
      AppLogger.error('Failed to get audio paths', e);
      return [];
    }
  }

  static String _getFileNameFromPath(String path) {
    return path.split('/').last;
  }

  static Future<List<int>?> _getAudioBytes(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return null;
      }
      return await file.readAsBytes();
    } catch (e) {
      AppLogger.error('Failed to read audio file: $path', e);
      return null;
    }
  }
}

