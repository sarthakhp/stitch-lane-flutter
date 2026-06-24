import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import '../../backend/backend.dart';
import '../../constants/app_constants.dart';
import '../../utils/app_logger.dart';
import 'backup_service.dart';
import 'drive_service.dart';
import 'image_storage_service.dart';

class BackupExportService {
  static Future<void> exportDriveBackupAsZip({
    void Function(String status)? onProgress,
  }) async {
    final archive = Archive();

    // 1. Download backup JSON
    onProgress?.call('Downloading backup data...');
    final backupJson = await DriveService.downloadBackup();
    if (backupJson == null) {
      throw Exception('No backup found on Google Drive');
    }
    archive.addFile(ArchiveFile(
      AppConstants.backupFileName,
      utf8.encode(backupJson).length,
      utf8.encode(backupJson),
    ));
    AppLogger.info('BackupExport: Added backup JSON');

    // 2. Download images
    final driveApi = await DriveService.getDriveApi();
    final images = await DriveServiceImageOperations.listImagesInFolder(driveApi);
    onProgress?.call('Downloading ${images.length} images...');

    for (int i = 0; i < images.length; i++) {
      final image = images[i];
      final fileId = image['id'] as String?;
      final fileName = image['name'] as String? ?? 'image_$i';
      if (fileId == null) continue;

      onProgress?.call('Downloading image ${i + 1}/${images.length}...');
      final bytes = await DriveServiceImageOperations.downloadImage(driveApi, fileId);
      if (bytes != null) {
        archive.addFile(ArchiveFile('images/$fileName', bytes.length, bytes));
      }
    }
    AppLogger.info('BackupExport: Added ${images.length} images');

    // 3. Download audio files
    final audios = await DriveServiceAudioOperations.listAudiosInFolder(driveApi);
    onProgress?.call('Downloading ${audios.length} audio files...');

    for (int i = 0; i < audios.length; i++) {
      final audio = audios[i];
      final fileId = audio['id'] as String?;
      final fileName = audio['name'] as String? ?? 'audio_$i.m4a';
      if (fileId == null) continue;

      onProgress?.call('Downloading audio ${i + 1}/${audios.length}...');
      final bytes = await DriveServiceAudioOperations.downloadAudio(driveApi, fileId);
      if (bytes != null) {
        archive.addFile(ArchiveFile('audios/$fileName', bytes.length, bytes));
      }
    }
    AppLogger.info('BackupExport: Added ${audios.length} audio files');

    // 4. Encode zip
    onProgress?.call('Creating zip file...');
    final zipData = ZipEncoder().encode(archive);
    AppLogger.info('BackupExport: Zip created (${zipData.length} bytes)');

    // 5. Save to device via system file picker
    onProgress?.call('Saving...');
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;

    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Backup',
      fileName: '${AppConstants.backupZipPrefix}_$timestamp.zip',
      bytes: Uint8List.fromList(zipData),
    );

    if (savedPath == null) {
      throw Exception('Save cancelled');
    }

    AppLogger.info('BackupExport: Drive backup saved to $savedPath');
  }

  static Future<void> exportLocalBackupAsZip({
    required CustomerRepository customerRepository,
    required OrderRepository orderRepository,
    required MeasurementRepository measurementRepository,
    required SettingsRepository settingsRepository,
    MeasurementFieldRepository? measurementFieldRepository,
    void Function(String status)? onProgress,
  }) async {
    final archive = Archive();

    // 1. Create backup JSON from local DB
    onProgress?.call('Reading local data...');
    final backupJson = await BackupService.createBackup(
      customerRepository: customerRepository,
      orderRepository: orderRepository,
      measurementRepository: measurementRepository,
      settingsRepository: settingsRepository,
      measurementFieldRepository: measurementFieldRepository,
    );
    final jsonBytes = utf8.encode(backupJson);
    archive.addFile(ArchiveFile(AppConstants.backupFileName, jsonBytes.length, jsonBytes));
    AppLogger.info('BackupExport: Added local backup JSON');

    // 2. Read local images
    final imagePaths = await ImageStorageService.getAllImagePaths();
    onProgress?.call('Adding ${imagePaths.length} images...');
    for (int i = 0; i < imagePaths.length; i++) {
      final path = imagePaths[i];
      final fileName = path.split('/').last;
      onProgress?.call('Adding image ${i + 1}/${imagePaths.length}...');
      final bytes = await ImageStorageService.getImageBytes(path);
      if (bytes != null) {
        archive.addFile(ArchiveFile('images/$fileName', bytes.length, bytes));
      }
    }
    AppLogger.info('BackupExport: Added ${imagePaths.length} local images');

    // 3. Read the audio files referenced by measurements. We read each
    // measurement's stored audioFilePath directly (rather than globbing one
    // folder/extension), so this covers BOTH the modern audio_backups/*.wav
    // recordings and any legacy measurement_*.m4a.
    final measurements = await measurementRepository.getAllMeasurements();
    final seenAudio = <String>{};
    var audioAdded = 0;
    for (final m in measurements) {
      for (final audioPath in m.audioFilePaths) {
        if (audioPath.trim().isEmpty) continue;
        final fileName = audioPath.split('/').last;
        if (!seenAudio.add(fileName)) continue; // de-dupe by file name
        final file = File(audioPath);
        if (!await file.exists()) {
          AppLogger.warning('BackupExport: audio missing, skipping: $audioPath');
          continue;
        }
        onProgress?.call('Adding audio ${audioAdded + 1}...');
        final bytes = await file.readAsBytes();
        archive.addFile(ArchiveFile('audios/$fileName', bytes.length, bytes));
        audioAdded++;
      }
    }
    AppLogger.info('BackupExport: Added $audioAdded measurement audio files');

    // 4. Encode zip
    onProgress?.call('Creating zip file...');
    final zipData = ZipEncoder().encode(archive);
    AppLogger.info('BackupExport: Local zip created (${zipData.length} bytes)');

    // 5. Save to device
    onProgress?.call('Saving...');
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Local Backup',
      fileName: '${AppConstants.backupZipPrefix}_local_$timestamp.zip',
      bytes: Uint8List.fromList(zipData),
    );

    if (savedPath == null) throw Exception('Save cancelled');
    AppLogger.info('BackupExport: Local backup saved to $savedPath');
  }
}
