import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/app_config.dart';
import '../../domain/domain.dart';

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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullImageViewer(
          imagePaths: imagePaths,
          initialIndex: initialIndex,
          onDelete: (index) async {
            await _deleteImage(context, index);
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
        ),
      ),
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
            child: _buildImage(context),
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

  Widget _buildImage(BuildContext context) {
    return kIsWeb
        ? Image.network(
            imagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildErrorWidget(context),
          )
        : Image.file(
            File(imagePath),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildErrorWidget(context),
          );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Icon(
        Icons.broken_image,
        color: Theme.of(context).colorScheme.error,
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

class _FullImageViewer extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;
  final Function(int) onDelete;

  const _FullImageViewer({
    required this.imagePaths,
    required this.initialIndex,
    required this.onDelete,
  });

  @override
  State<_FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<_FullImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  ImageProvider _getImageProvider(String imagePath) {
    if (kIsWeb) {
      return NetworkImage(imagePath);
    }
    return FileImage(File(imagePath));
  }

  Future<void> _shareImage() async {
    if (kIsWeb) return;
    final imagePath = widget.imagePaths[_currentIndex];
    await SharePlus.instance.share(ShareParams(files: [XFile(imagePath)]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.imagePaths.length}'),
        actions: [
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareImage,
            ),
        ],
      ),
      body: PhotoViewGallery.builder(
        pageController: _pageController,
        itemCount: widget.imagePaths.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        builder: (context, index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: _getImageProvider(widget.imagePaths[index]),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4,
          );
        },
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}
