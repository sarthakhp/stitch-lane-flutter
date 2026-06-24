import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../backend/backend.dart';
import '../../constants/app_constants.dart';
import '../../utils/app_logger.dart';
import 'audio_backup_recorder.dart';
import 'image_storage_service.dart';

class BackupImportResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? metadata;

  BackupImportResult._({required this.success, this.error, this.metadata});

  factory BackupImportResult.success(Map<String, dynamic> metadata) =>
      BackupImportResult._(success: true, metadata: metadata);

  factory BackupImportResult.failed(String error) =>
      BackupImportResult._(success: false, error: error);

  factory BackupImportResult.cancelled() =>
      BackupImportResult._(success: false, error: null);
}

/// Holds pre-validated zip contents ready to be imported.
/// This is extracted and validated BEFORE any existing data is touched.
class _ValidatedZipContents {
  final String backupJson;
  final Map<String, dynamic> metadata;
  final Map<String, List<int>> imageFiles; // filename -> bytes
  final Map<String, List<int>> audioFiles; // filename -> bytes

  _ValidatedZipContents({
    required this.backupJson,
    required this.metadata,
    required this.imageFiles,
    required this.audioFiles,
  });
}

class BackupImportService {

  /// Rewrites a media path stored on the (possibly different) source device to
  /// this device's [dir], keyed by file name — so images and audio restore
  /// correctly regardless of the original install's absolute paths.
  static String localMediaPath(String dir, String storedPath) =>
      '$dir/${storedPath.split('/').last}';

  /// Step 1: Pick a zip file. Returns null if user cancels.
  static Future<String?> pickZipFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    return result?.files.single.path;
  }

  /// Step 2: Validate the zip and extract metadata (without touching any app data).
  /// Returns metadata for the confirmation dialog.
  static Future<BackupImportResult> validateZip(String zipPath) async {
    try {
      final contents = await _extractAndValidate(zipPath);
      return BackupImportResult.success(contents.metadata);
    } catch (e) {
      return BackupImportResult.failed(e.toString());
    }
  }

  /// Step 3: Perform the actual import. This is called after user confirms.
  /// Safety: backs up current data in memory first. If import fails, rolls back.
  static Future<BackupImportResult> importFromZip(
    String zipPath, {
    required CustomerRepository customerRepository,
    required OrderRepository orderRepository,
    required MeasurementRepository measurementRepository,
    required SettingsRepository settingsRepository,
    void Function(String status)? onProgress,
  }) async {
    // 1. Extract and validate zip (no data touched yet)
    onProgress?.call('Validating backup file...');
    final _ValidatedZipContents contents;
    try {
      contents = await _extractAndValidate(zipPath);
    } catch (e) {
      return BackupImportResult.failed('Invalid backup file: $e');
    }

    // 2. Backup current data in memory (safety net for rollback)
    onProgress?.call('Preparing safe import...');
    final currentCustomers = await customerRepository.getAllCustomers();
    final currentOrders = await orderRepository.getAllOrders();
    final currentMeasurements = await measurementRepository.getAllMeasurements();
    final currentSettings = await settingsRepository.getSettings();

    AppLogger.info(
      'BackupImport: Current data backed up in memory: '
      '${currentCustomers.length} customers, ${currentOrders.length} orders, '
      '${currentMeasurements.length} measurements',
    );

    try {
      Future<BackupImportResult> doImport() async {
        // 3. Clear existing data (order matters for FK, but we disable FK anyway)
        onProgress?.call('Clearing existing data...');
        await orderRepository.clearAll();
        await measurementRepository.clearAll();
        await customerRepository.clearAll();

        // 4. Restore data from zip JSON
        onProgress?.call('Restoring data...');
        final backupData = jsonDecode(contents.backupJson) as Map<String, dynamic>;
        final boxes = backupData['boxes'] as Map<String, dynamic>;

        final customersList = boxes['customers'] as List?;
        if (customersList != null) {
          for (var json in customersList) {
            final customer = Customer.fromJson(json as Map<String, dynamic>);
            await customerRepository.addCustomer(customer);
          }
        }

        final ordersList = boxes['orders'] as List?;
        if (ordersList != null) {
          final appDir = await getApplicationDocumentsDirectory();
          final localImagesDir = '${appDir.path}/${AppConstants.imagesFolderName}';
          final orderAudioDir = (await AudioBackupRecorder.backupsDirectory()).path;

          for (var json in ordersList) {
            var order = Order.fromJson(json as Map<String, dynamic>);
            // Fix image paths to point to current device's directory.
            if (order.imagePaths.isNotEmpty) {
              order = order.copyWith(
                imagePaths: order.imagePaths
                    .map((p) => localMediaPath(localImagesDir, p))
                    .toList(),
              );
            }
            // Same for linked audio recordings.
            if (order.audioFilePaths.isNotEmpty) {
              order = order.copyWith(
                audioFilePaths: order.audioFilePaths
                    .map((p) => localMediaPath(orderAudioDir, p))
                    .toList(),
              );
            }
            await orderRepository.addOrder(order);
          }
        }

        final measurementsList = boxes['measurements'] as List?;
        if (measurementsList != null) {
          // Audio is restored into audio_backups/; rewrite each measurement's
          // recordings to point there on THIS device (same idea as images).
          final audioDir = (await AudioBackupRecorder.backupsDirectory()).path;
          for (var json in measurementsList) {
            var measurement = Measurement.fromJson(json as Map<String, dynamic>);
            if (measurement.audioFilePaths.isNotEmpty) {
              measurement = measurement.copyWith(
                audioFilePaths: measurement.audioFilePaths
                    .map((p) => localMediaPath(audioDir, p))
                    .toList(),
              );
            }
            await measurementRepository.addMeasurement(measurement);
          }
        }

        final settingsJson = boxes['settings'] as Map<String, dynamic>?;
        if (settingsJson != null) {
          final settings = AppSettings.fromJson(settingsJson);
          final safeSettings = settings.copyWith(autoBackupEnabled: false);
          await settingsRepository.saveSettings(safeSettings);
        }

        // 5. Write image files to local storage
        if (contents.imageFiles.isNotEmpty) {
          onProgress?.call('Restoring ${contents.imageFiles.length} images...');
          final appDir = await getApplicationDocumentsDirectory();
          final imagesDir = Directory('${appDir.path}/${AppConstants.imagesFolderName}');
          if (!await imagesDir.exists()) {
            await imagesDir.create(recursive: true);
          }
          for (final entry in contents.imageFiles.entries) {
            final file = File('${imagesDir.path}/${entry.key}');
            await file.writeAsBytes(entry.value);
          }
          AppLogger.info('BackupImport: Restored ${contents.imageFiles.length} images');
        }

        // 6. Write audio files into audio_backups/ — the same directory the
        // measurement audioFilePaths were rewritten to point at above.
        if (contents.audioFiles.isNotEmpty) {
          onProgress?.call('Restoring ${contents.audioFiles.length} audio files...');
          final audioDir = (await AudioBackupRecorder.backupsDirectory()).path;
          for (final entry in contents.audioFiles.entries) {
            final file = File('$audioDir/${entry.key}');
            await file.writeAsBytes(entry.value);
          }
          AppLogger.info('BackupImport: Restored ${contents.audioFiles.length} audio files');
        }

        // Verify: log any images referenced by orders but missing locally.
        // Restore never deletes local image files.
        final restoredOrders = await orderRepository.getAllOrders();
        await ImageStorageService.verifyReferencedImages(restoredOrders);

        AppLogger.info('BackupImport: Import completed successfully');
        return BackupImportResult.success(contents.metadata);
      }

      return await SqliteDatabase.withForeignKeysDisabled(doImport);
    } catch (e) {
      // ROLLBACK: Restore original data from memory
      AppLogger.error('BackupImport: Import failed, rolling back...', e);
      onProgress?.call('Import failed, restoring previous data...');

      try {
        Future<void> doRollback() async {
          await orderRepository.clearAll();
          await measurementRepository.clearAll();
          await customerRepository.clearAll();

          for (final customer in currentCustomers) {
            await customerRepository.addCustomer(customer);
          }
          for (final order in currentOrders) {
            await orderRepository.addOrder(order);
          }
          for (final measurement in currentMeasurements) {
            await measurementRepository.addMeasurement(measurement);
          }
          await settingsRepository.saveSettings(currentSettings);
        }

        await SqliteDatabase.withForeignKeysDisabled(doRollback);

        AppLogger.info('BackupImport: Rollback successful');
      } catch (rollbackError) {
        AppLogger.error('BackupImport: Rollback also failed!', rollbackError);
      }

      return BackupImportResult.failed('Import failed: $e');
    }
  }

  /// Extracts zip and validates contents WITHOUT touching any app data.
  static Future<_ValidatedZipContents> _extractAndValidate(String zipPath) async {
    final file = File(zipPath);
    if (!await file.exists()) {
      throw Exception('File not found: $zipPath');
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Find backup JSON
    final jsonFile = archive.files.where(
      (f) => f.name == AppConstants.backupFileName || f.name.endsWith('/${AppConstants.backupFileName}'),
    ).firstOrNull;

    if (jsonFile == null) {
      throw Exception('No ${AppConstants.backupFileName} found in zip');
    }

    final backupJson = utf8.decode(jsonFile.content as List<int>);

    // Validate JSON structure
    final backupData = jsonDecode(backupJson) as Map<String, dynamic>;
    if (!backupData.containsKey('version')) {
      throw Exception('Invalid backup: missing version');
    }
    if (!backupData.containsKey('boxes')) {
      throw Exception('Invalid backup: missing data');
    }
    final version = backupData['version'] as String;
    if (version != '1.0.0') {
      throw Exception('Incompatible backup version: $version');
    }

    // Extract metadata
    final metadata = backupData['metadata'] as Map<String, dynamic>? ?? {};
    final enrichedMetadata = {
      'version': backupData['version'],
      'timestamp': backupData['timestamp'],
      'customerCount': metadata['customerCount'] ?? 0,
      'orderCount': metadata['orderCount'] ?? 0,
      'measurementCount': metadata['measurementCount'] ?? 0,
    };

    // Log all files in archive for debugging
    AppLogger.info(
      'BackupImport: Zip contains ${archive.files.length} entries: '
      '${archive.files.map((f) => '${f.name} (isFile=${f.isFile}, size=${f.size})').join(', ')}',
    );

    // Extract image files (handle wrapper folder: images/x.jpg or folder/images/x.jpg)
    final Map<String, List<int>> imageFiles = {};
    for (final archiveFile in archive.files) {
      if (!archiveFile.isFile) continue;
      final imagesIdx = archiveFile.name.indexOf('images/');
      if (imagesIdx != -1) {
        final fileName = archiveFile.name.substring(imagesIdx + 'images/'.length);
        if (fileName.isNotEmpty && !fileName.startsWith('.')) {
          imageFiles[fileName] = archiveFile.content as List<int>;
        }
      }
    }
    enrichedMetadata['imageCount'] = imageFiles.length;

    // Extract audio files (handle wrapper folder: audios/x.m4a or folder/audios/x.m4a)
    final Map<String, List<int>> audioFiles = {};
    for (final archiveFile in archive.files) {
      if (!archiveFile.isFile) continue;
      final audiosIdx = archiveFile.name.indexOf('audios/');
      if (audiosIdx != -1) {
        final fileName = archiveFile.name.substring(audiosIdx + 'audios/'.length);
        if (fileName.isNotEmpty && !fileName.startsWith('.')) {
          audioFiles[fileName] = archiveFile.content as List<int>;
        }
      }
    }
    enrichedMetadata['audioCount'] = audioFiles.length;

    AppLogger.info(
      'BackupImport: Validated zip - ${enrichedMetadata['customerCount']} customers, '
      '${enrichedMetadata['orderCount']} orders, ${enrichedMetadata['measurementCount']} measurements, '
      '${imageFiles.length} images, ${audioFiles.length} audio files',
    );

    return _ValidatedZipContents(
      backupJson: backupJson,
      metadata: enrichedMetadata,
      imageFiles: imageFiles,
      audioFiles: audioFiles,
    );
  }
}
