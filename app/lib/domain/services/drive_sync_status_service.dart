import 'dart:io';
import '../../backend/backend.dart';
import 'backup_service.dart';
import 'drive_service.dart';
import 'image_storage_service.dart';

class DriveSyncCounts {
  final int localCustomers;
  final int driveCustomers;
  final int localOrders;
  final int driveOrders;
  final int localMeasurements;
  final int driveMeasurements;
  final int localImages;
  final int driveImages;
  final int localAudio;
  final int driveAudio;

  const DriveSyncCounts({
    required this.localCustomers,
    required this.driveCustomers,
    required this.localOrders,
    required this.driveOrders,
    required this.localMeasurements,
    required this.driveMeasurements,
    required this.localImages,
    required this.driveImages,
    required this.localAudio,
    required this.driveAudio,
  });

  bool get isFullySynced =>
      localCustomers == driveCustomers &&
      localOrders == driveOrders &&
      localMeasurements == driveMeasurements &&
      localImages == driveImages &&
      localAudio == driveAudio;
}

class DriveSyncStatusService {
  static Future<DriveSyncCounts> checkSyncStatus({
    required CustomerRepository customerRepository,
    required OrderRepository orderRepository,
    required MeasurementRepository measurementRepository,
  }) async {
    // Start local counts and Drive backup JSON download in parallel
    final localCountsFuture = Future.wait([
      customerRepository.getAllCustomers().then((l) => l.length),
      orderRepository.getAllOrders().then((l) => l.length),
      measurementRepository.getAllMeasurements().then((l) => l.length),
      ImageStorageService.getAllImagePaths().then((l) => l.length),
      _getLocalAudioCount(),
    ]);

    final backupJsonFuture = DriveService.downloadBackup();

    final localCounts = await localCountsFuture;
    final backupJson = await backupJsonFuture;

    if (backupJson == null) {
      throw Exception('No backup found on Drive');
    }

    final metadata = BackupService.getBackupMetadata(backupJson);

    final driveApi = await DriveService.getDriveApi();
    final driveImages =
        await DriveServiceImageOperations.listImagesInFolder(driveApi);
    final driveAudio =
        await DriveServiceAudioOperations.listAudiosInFolder(driveApi);

    return DriveSyncCounts(
      localCustomers: localCounts[0],
      driveCustomers: (metadata['customerCount'] as num).toInt(),
      localOrders: localCounts[1],
      driveOrders: (metadata['orderCount'] as num).toInt(),
      localMeasurements: localCounts[2],
      driveMeasurements: (metadata['measurementCount'] as num).toInt(),
      localImages: localCounts[3],
      driveImages: driveImages.length,
      localAudio: localCounts[4],
      driveAudio: driveAudio.length,
    );
  }

  static Future<int> _getLocalAudioCount() async {
    try {
      // Count the audio files actually referenced by measurements (matches
      // what the upload sends), covering audio_backups/*.wav + legacy m4a.
      final repo = RepositoryFactory.createMeasurementRepository();
      final measurements = await repo.getAllMeasurements();
      final names = <String>{};
      for (final m in measurements) {
        final p = m.audioFilePath;
        if (p == null || p.trim().isEmpty) continue;
        if (await File(p).exists()) names.add(p.split('/').last);
      }
      return names.length;
    } catch (_) {
      return 0;
    }
  }
}
