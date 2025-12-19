import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../utils/app_logger.dart';
import 'drive_service.dart';

class AudioSyncService {
  static Future<void> syncAudiosToDrive() async {
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

      final audiosToUpload = localAudioNames.difference(driveAudioNames);
      AppLogger.info('Audio files to upload: ${audiosToUpload.length}');

      for (final audioName in audiosToUpload) {
        final audioPath = localAudioPaths.firstWhere(
          (path) => _getFileNameFromPath(path) == audioName,
        );

        final audioBytes = await _getAudioBytes(audioPath);
        if (audioBytes != null) {
          await DriveServiceAudioOperations.uploadAudio(driveApi, audioName, audioBytes);
          AppLogger.info('Uploaded audio: $audioName');
        }
      }

      final audiosToDelete = driveAudioNames.difference(localAudioNames);
      AppLogger.info('Audio files to delete from Drive: ${audiosToDelete.length}');

      for (final audioName in audiosToDelete) {
        final audioFile = driveAudios.firstWhere(
          (audio) => audio['name'] == audioName,
        );
        await DriveServiceAudioOperations.deleteAudioFromDrive(driveApi, audioFile['id'] as String);
        AppLogger.info('Deleted audio from Drive: $audioName');
      }

      AppLogger.info('Audio sync completed successfully');
    } catch (e) {
      AppLogger.error('Failed to sync audio files to Drive', e);
      rethrow;
    }
  }

  static Future<void> downloadAudiosFromDrive() async {
    try {
      AppLogger.info('Starting audio download from Drive');

      final driveApi = await DriveService.getDriveApi();
      final driveAudios = await DriveServiceAudioOperations.listAudiosInFolder(driveApi);
      AppLogger.info('Found ${driveAudios.length} audio files in Drive');

      final directory = await getApplicationDocumentsDirectory();

      for (final audioFile in driveAudios) {
        final audioName = audioFile['name'] as String;
        final audioId = audioFile['id'] as String;

        final audioBytes = await DriveServiceAudioOperations.downloadAudio(driveApi, audioId);
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

  static Future<List<String>> _getAllAudioPaths() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dir = Directory(directory.path);
      
      if (!await dir.exists()) {
        return [];
      }

      final files = await dir.list().toList();
      return files
          .whereType<File>()
          .where((file) => file.path.endsWith('.m4a') && file.path.contains('measurement_'))
          .map((file) => file.path)
          .toList();
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

