import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
        crossAxisCount: 3,
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

    return GestureDetector(
      onTap: () => _showFullImage(context, index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: kIsWeb
                ? Image.network(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Icon(
                          Icons.broken_image,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      );
                    },
                  )
                : Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Icon(
                          Icons.broken_image,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      );
                    },
                  ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () => _deleteImage(context, index),
                icon: const Icon(Icons.delete, size: 18),
                iconSize: 18,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.imagePaths.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => widget.onDelete(_currentIndex),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imagePaths.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final imagePath = widget.imagePaths[index];
          return InteractiveViewer(
            child: Center(
              child: kIsWeb
                  ? Image.network(imagePath)
                  : Image.file(File(imagePath)),
            ),
          );
        },
      ),
    );
  }
}
