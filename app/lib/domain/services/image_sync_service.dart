import 'dart:typed_data';
import 'package:googleapis/drive/v3.dart' as drive;
import '../../backend/backend.dart';
import '../../utils/app_logger.dart';
import 'image_storage_service.dart';
import 'drive_service.dart';

class ImageSyncService {
  static Future<void> syncImagesToDrive({
    void Function(int current, int total, String message)? onProgress,
    required OrderRepository orderRepository,
  }) async {
    try {
      AppLogger.info('Starting image sync to Drive');

      final driveApi = await DriveService.getDriveApi();
      final localImagePaths = await ImageStorageService.getAllImagePaths();
      AppLogger.info('Found ${localImagePaths.length} local images');

      final driveImages = await DriveServiceImageOperations.listImagesInFolder(driveApi);
      final driveImageNames = driveImages.map((img) => img['name'] as String).toSet();
      AppLogger.info('Found ${driveImageNames.length} images in Drive');

      final localImageNames = localImagePaths
          .map((path) => ImageStorageService.getFileNameFromPath(path))
          .toSet();

      final imagesToUpload = localImageNames.difference(driveImageNames).toList();
      final total = imagesToUpload.length;
      AppLogger.info('Images to upload (diff): $total');

      for (int i = 0; i < total; i++) {
        final imageName = imagesToUpload[i];
        final current = i + 1;
        final imagePath = localImagePaths.firstWhere(
          (path) => ImageStorageService.getFileNameFromPath(path) == imageName,
        );

        final imageBytes = await ImageStorageService.getImageBytes(imagePath);
        if (imageBytes != null) {
          onProgress?.call(current, total, 'Uploading image $current of $total');
          await _uploadWithRetry(driveApi, imageName, imageBytes,
            onRetry: (nextAttempt, max) {
              onProgress?.call(current, total,
                'Retrying image $current of $total (attempt $nextAttempt/$max)');
            },
          );
          AppLogger.info('Uploaded image: $imageName');
        }
      }

      // Only delete Drive images that are NOT referenced by any order in the DB
      final imagesToDelete = driveImageNames.difference(localImageNames);
      AppLogger.info('Images on Drive but not local: ${imagesToDelete.length}');

      if (imagesToDelete.isNotEmpty) {
        final allOrders = await orderRepository.getAllOrders();
        final referencedFileNames = allOrders
            .expand((o) => o.imagePaths)
            .map((path) => path.split('/').last)
            .toSet();

        for (final imageName in imagesToDelete) {
          if (referencedFileNames.contains(imageName)) {
            AppLogger.warning('Skipping Drive delete (still referenced in DB): $imageName');
            continue;
          }
          final imageFile = driveImages.firstWhere(
            (img) => img['name'] == imageName,
          );
          await DriveServiceImageOperations.deleteImageFromDrive(driveApi, imageFile['id'] as String);
          AppLogger.info('Deleted orphaned image from Drive: $imageName');
        }
      }

      AppLogger.info('Image sync completed successfully');
    } catch (e) {
      AppLogger.error('Failed to sync images to Drive', e);
      rethrow;
    }
  }

  static Future<void> _uploadWithRetry(
    drive.DriveApi initialDriveApi,
    String imageName,
    Uint8List imageBytes, {
    int maxAttempts = 3,
    void Function(int nextAttempt, int max)? onRetry,
  }) async {
    drive.DriveApi driveApi = initialDriveApi;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await DriveServiceImageOperations.uploadImage(driveApi, imageName, imageBytes);
        return;
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        final delaySeconds = attempt * 2;
        AppLogger.warning(
          'Image upload failed (attempt $attempt/$maxAttempts): $imageName. '
          'Reconnecting in ${delaySeconds}s...',
        );
        onRetry?.call(attempt + 1, maxAttempts);
        await Future.delayed(Duration(seconds: delaySeconds));
        driveApi = await DriveService.getDriveApi();
      }
    }
  }

  static Future<void> downloadImagesFromDrive({
    void Function(int current, int total, String message)? onProgress,
  }) async {
    try {
      AppLogger.info('Starting image download from Drive');

      final driveApi = await DriveService.getDriveApi();
      final driveImages = await DriveServiceImageOperations.listImagesInFolder(driveApi);
      AppLogger.info('Found ${driveImages.length} images in Drive');

      final total = driveImages.length;
      for (int i = 0; i < total; i++) {
        final imageFile = driveImages[i];
        final imageName = imageFile['name'] as String;
        final imageId = imageFile['id'] as String;
        final current = i + 1;

        onProgress?.call(current, total, 'Downloading image $current of $total');
        final imageBytes = await _downloadImageWithRetry(
          driveApi,
          imageId,
          imageName,
          onRetry: (nextAttempt, max) {
            onProgress?.call(current, total,
              'Retrying image $current of $total (attempt $nextAttempt/$max)');
          },
        );
        if (imageBytes != null) {
          final extension = imageName.contains('.')
              ? '.${imageName.split('.').last}'
              : '.jpg';

          await ImageStorageService.saveImage(
            Uint8List.fromList(imageBytes),
            extension: extension,
            customFileName: imageName,
            compress: false,
          );
          AppLogger.info('Downloaded and saved image: $imageName');
        }
      }

      AppLogger.info('Image download completed successfully');
    } catch (e) {
      AppLogger.error('Failed to download images from Drive', e);
      rethrow;
    }
  }

  static Future<List<int>?> _downloadImageWithRetry(
    drive.DriveApi initialDriveApi,
    String fileId,
    String fileName, {
    int maxAttempts = 3,
    void Function(int nextAttempt, int max)? onRetry,
  }) async {
    drive.DriveApi driveApi = initialDriveApi;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await DriveServiceImageOperations.downloadImage(driveApi, fileId);
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        final delaySeconds = attempt * 2;
        AppLogger.warning(
          'Image download failed (attempt $attempt/$maxAttempts): $fileName. '
          'Reconnecting in ${delaySeconds}s...',
        );
        onRetry?.call(attempt + 1, maxAttempts);
        await Future.delayed(Duration(seconds: delaySeconds));
        driveApi = await DriveService.getDriveApi();
      }
    }
    return null;
  }
}

