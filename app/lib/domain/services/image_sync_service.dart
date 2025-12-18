import 'dart:typed_data';
import '../../utils/app_logger.dart';
import 'image_storage_service.dart';
import 'drive_service.dart';

class ImageSyncService {
  static Future<void> syncImagesToDrive() async {
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

      final imagesToUpload = localImageNames.difference(driveImageNames);
      AppLogger.info('Images to upload: ${imagesToUpload.length}');

      for (final imageName in imagesToUpload) {
        final imagePath = localImagePaths.firstWhere(
          (path) => ImageStorageService.getFileNameFromPath(path) == imageName,
        );

        final imageBytes = await ImageStorageService.getImageBytes(imagePath);
        if (imageBytes != null) {
          await DriveServiceImageOperations.uploadImage(driveApi, imageName, imageBytes);
          AppLogger.info('Uploaded image: $imageName');
        }
      }

      final imagesToDelete = driveImageNames.difference(localImageNames);
      AppLogger.info('Images to delete from Drive: ${imagesToDelete.length}');

      for (final imageName in imagesToDelete) {
        final imageFile = driveImages.firstWhere(
          (img) => img['name'] == imageName,
        );
        await DriveServiceImageOperations.deleteImageFromDrive(driveApi, imageFile['id'] as String);
        AppLogger.info('Deleted image from Drive: $imageName');
      }

      AppLogger.info('Image sync completed successfully');
    } catch (e) {
      AppLogger.error('Failed to sync images to Drive', e);
      rethrow;
    }
  }

  static Future<void> downloadImagesFromDrive() async {
    try {
      AppLogger.info('Starting image download from Drive');

      final driveApi = await DriveService.getDriveApi();
      final driveImages = await DriveServiceImageOperations.listImagesInFolder(driveApi);
      AppLogger.info('Found ${driveImages.length} images in Drive');

      for (final imageFile in driveImages) {
        final imageName = imageFile['name'] as String;
        final imageId = imageFile['id'] as String;

        final imageBytes = await DriveServiceImageOperations.downloadImage(driveApi, imageId);
        if (imageBytes != null) {
          final extension = imageName.contains('.')
              ? '.${imageName.split('.').last}'
              : '.jpg';

          await ImageStorageService.saveImage(
            Uint8List.fromList(imageBytes),
            extension: extension,
            customFileName: imageName,
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
}

