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
      // Count the audio files referenced by measurements AND orders (matches
      // what the upload sends), covering audio_backups/*.wav + legacy m4a.
      final measurements =
          await RepositoryFactory.createMeasurementRepository().getAllMeasurements();
      final orders =
          await RepositoryFactory.createOrderRepository().getAllOrders();
      final names = <String>{};
      Future<void> consider(String p) async {
        if (p.trim().isEmpty) return;
        if (await File(p).exists()) names.add(p.split('/').last);
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
      return names.length;
    } catch (_) {
      return 0;
    }
  }
}
