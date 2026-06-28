import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../backend/backend.dart';
import '../../utils/app_logger.dart';

class ImageStorageService {
  static const String _imagesFolderName = 'order_images';
  static const _uuid = Uuid();

  static const int _compressQuality = 80;
  static const int _maxDimension = 1200;

  static Future<Directory> _getImagesDirectory() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory imagesDir = Directory('${appDir.path}/$_imagesFolderName');

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
      AppLogger.info('Created images directory: ${imagesDir.path}');
    }

    return imagesDir;
  }

  /// The on-device images directory (created if absent). Exposed so the sync
  /// [MediaResolver] can land lazily-downloaded images alongside captured ones.
  static Future<Directory> imagesDirectory() => _getImagesDirectory();

  static Future<String> saveImage(
    Uint8List imageBytes, {
    String? extension,
    String? customFileName,
    bool compress = true,
  }) async {
    try {
      final Directory imagesDir = await _getImagesDirectory();
      final String fileName = customFileName ?? '${_uuid.v4()}${extension ?? '.jpg'}';
      final String filePath = '${imagesDir.path}/$fileName';

      Uint8List bytesToSave = imageBytes;
      if (compress) {
        bytesToSave = await compressImageBytes(imageBytes) ?? imageBytes;
      }

      final File imageFile = File(filePath);
      await imageFile.writeAsBytes(bytesToSave);

      AppLogger.info('Image saved: $filePath (${imageBytes.length} -> ${bytesToSave.length} bytes)');
      return filePath;
    } catch (e) {
      AppLogger.error('Failed to save image', e);
      throw Exception('Failed to save image: $e');
    }
  }

  static Future<Uint8List?> compressImageBytes(Uint8List imageBytes) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: _maxDimension,
        minHeight: _maxDimension,
        quality: _compressQuality,
        format: CompressFormat.jpeg,
      );
      return result;
    } catch (e) {
      AppLogger.warning('Image compression failed, using original: $e');
      return null;
    }
  }

  static Future<void> deleteImage(String imagePath) async {
    try {
      final File imageFile = File(imagePath);

      if (await imageFile.exists()) {
        await imageFile.delete();
        AppLogger.info('Image deleted: $imagePath');
      } else {
        AppLogger.warning('Image file not found: $imagePath');
      }
    } catch (e) {
      AppLogger.error('Failed to delete image', e);
      throw Exception('Failed to delete image: $e');
    }
  }

  static Future<void> deleteImages(List<String> imagePaths) async {
    for (final imagePath in imagePaths) {
      await deleteImage(imagePath);
    }
  }

  static Future<File?> getImageFile(String imagePath) async {
    try {
      final File imageFile = File(imagePath);

      if (await imageFile.exists()) {
        return imageFile;
      } else {
        AppLogger.warning('Image file not found: $imagePath');
        return null;
      }
    } catch (e) {
      AppLogger.error('Failed to get image file', e);
      return null;
    }
  }

  static Future<Uint8List?> getImageBytes(String imagePath) async {
    try {
      final File? imageFile = await getImageFile(imagePath);

      if (imageFile != null) {
        return await imageFile.readAsBytes();
      }

      return null;
    } catch (e) {
      AppLogger.error('Failed to read image bytes', e);
      return null;
    }
  }

  static Future<List<String>> getAllImagePaths() async {
    try {
      final Directory imagesDir = await _getImagesDirectory();

      if (!await imagesDir.exists()) {
        return [];
      }

      final List<FileSystemEntity> files = imagesDir.listSync();
      return files
          .whereType<File>()
          .map((file) => file.path)
          .toList();
    } catch (e) {
      AppLogger.error('Failed to get all image paths', e);
      return [];
    }
  }

  static String getFileNameFromPath(String imagePath) {
    return imagePath.split('/').last;
  }

  static Future<bool> imageExists(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      return await imageFile.exists();
    } catch (e) {
      return false;
    }
  }

  /// Logs which images are referenced by orders but missing locally.
  /// Does NOT delete anything — purely diagnostic.
  static Future<int> verifyReferencedImages(List<Order> orders) async {
    int missingCount = 0;
    for (final order in orders) {
      for (final path in order.imagePaths) {
        if (!await File(path).exists()) {
          missingCount++;
          AppLogger.warning('Image referenced but missing locally: ${path.split('/').last} (order: ${order.id})');
        }
      }
    }
    if (missingCount == 0) {
      AppLogger.info('Image verification: all referenced images present locally');
    } else {
      AppLogger.warning('Image verification: $missingCount referenced images missing locally');
    }
    return missingCount;
  }

  static Future<void> cleanupOrphanedImages(List<String> validImagePaths) async {
    try {
      final List<String> allImagePaths = await getAllImagePaths();
      final Set<String> validPathsSet = validImagePaths.toSet();

      for (final imagePath in allImagePaths) {
        if (!validPathsSet.contains(imagePath)) {
          await deleteImage(imagePath);
          AppLogger.info('Cleaned up orphaned image: $imagePath');
        }
      }
    } catch (e) {
      AppLogger.error('Failed to cleanup orphaned images', e);
    }
  }
}
