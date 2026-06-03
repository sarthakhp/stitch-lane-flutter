import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_config.dart';
import '../../domain/domain.dart';
import 'common/full_image_viewer.dart';
import 'common/local_image.dart';

/// Logical width to decode grid thumbnails at; scaled by DPR inside [LocalImage].
const double _kThumbnailDecodeWidth = 300;

class OrderImagesSection extends StatelessWidget {
  final List<String> imagePaths;
  final Function(List<String>) onImagesChanged;

  const OrderImagesSection({
    super.key,
    required this.imagePaths,
    required this.onImagesChanged,
  });

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final extension = image.path.split('.').last;
        final savedPath = await ImageStorageService.saveImage(
          bytes,
          extension: '.$extension',
        );

        final updatedPaths = [...imagePaths, savedPath];
        onImagesChanged(updatedPaths);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image added successfully'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add image: $e')),
        );
      }
    }
  }

  Future<void> _deleteImage(BuildContext context, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to delete this image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final imagePath = imagePaths[index];
      await ImageStorageService.deleteImage(imagePath);

      final updatedPaths = List<String>.from(imagePaths)..removeAt(index);
      onImagesChanged(updatedPaths);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image deleted'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete image: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(context, ImageSource.gallery);
              },
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(context, ImageSource.camera);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Images',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showImageSourceDialog(context),
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (imagePaths.isEmpty) ...[
              const SizedBox(height: AppConfig.spacing16),
              Center(
                child: Text(
                  'No images added',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ] else ...[
              const SizedBox(height: AppConfig.spacing16),
              _buildImageGrid(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppConfig.spacing8,
        mainAxisSpacing: AppConfig.spacing8,
      ),
      itemCount: imagePaths.length,
      itemBuilder: (context, index) {
        return _buildImageThumbnail(context, index);
      },
    );
  }

  Widget _buildImageThumbnail(BuildContext context, int index) {
    final imagePath = imagePaths[index];

    return _ImageThumbnail(
      imagePath: imagePath,
      onTap: () => _showFullImage(context, index),
      onDelete: () => _deleteImage(context, index),
    );
  }

  void _showFullImage(BuildContext context, int initialIndex) {
    FullImageViewer.show(
      context,
      imagePaths: imagePaths,
      initialIndex: initialIndex,
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final String imagePath;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ImageThumbnail({
    required this.imagePath,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConfig.spacing8),
            child: LocalImage(
              path: imagePath,
              decodeWidth: _kThumbnailDecodeWidth,
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: _DeleteButton(onDelete: onDelete),
          ),
        ],
      ),
    );
  }

}

class _DeleteButton extends StatelessWidget {
  final VoidCallback onDelete;

  const _DeleteButton({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDelete,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.close,
            size: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

