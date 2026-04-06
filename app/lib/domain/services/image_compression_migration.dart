import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_logger.dart';
import 'image_storage_service.dart';

class ImageCompressionMigration {
  static const String _migrationKey = 'image_compression_migration_completed';

  static Future<bool> needsMigration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_migrationKey) != true;
  }

  /// Compresses all existing images in-place.
  /// Returns the number of images compressed.
  static Future<int> run({
    void Function(int current, int total)? onProgress,
  }) async {
    if (!await needsMigration()) return 0;

    final imagePaths = await ImageStorageService.getAllImagePaths();
    if (imagePaths.isEmpty) {
      await _markCompleted();
      return 0;
    }

    AppLogger.info('Image compression migration: ${imagePaths.length} images to process');
    int compressed = 0;
    int totalSavedBytes = 0;

    for (int i = 0; i < imagePaths.length; i++) {
      onProgress?.call(i + 1, imagePaths.length);

      try {
        final file = File(imagePaths[i]);
        if (!await file.exists()) continue;

        final originalBytes = await file.readAsBytes();
        final originalSize = originalBytes.length;

        final compressedBytes = await ImageStorageService.compressImageBytes(originalBytes);
        if (compressedBytes == null) continue;

        // Only write if compression actually reduced the size
        if (compressedBytes.length < originalSize) {
          await file.writeAsBytes(compressedBytes);
          final saved = originalSize - compressedBytes.length;
          totalSavedBytes += saved;
          compressed++;
          AppLogger.info(
            'Compressed ${ImageStorageService.getFileNameFromPath(imagePaths[i])}: '
            '${_formatBytes(originalSize)} -> ${_formatBytes(compressedBytes.length)} '
            '(saved ${_formatBytes(saved)})',
          );
        }
      } catch (e) {
        AppLogger.warning('Failed to compress ${imagePaths[i]}: $e');
        // Continue with next image — don't fail the whole migration
      }
    }

    await _markCompleted();
    AppLogger.info(
      'Image compression migration complete: '
      '$compressed/${imagePaths.length} images compressed, '
      'total saved: ${_formatBytes(totalSavedBytes)}',
    );
    return compressed;
  }

  static Future<void> _markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_migrationKey, true);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
