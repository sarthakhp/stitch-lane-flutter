import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';

/// Read-only, full-screen, zoomable image gallery. Open it with [show].
///
/// Reusable across the app wherever images just need to be viewed (paging,
/// pinch-zoom, optional share) — e.g. order detail and the AI action cards.
class FullImageViewer extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;

  /// Show a share action in the app bar (native platforms only).
  final bool showShare;

  const FullImageViewer({
    super.key,
    required this.imagePaths,
    this.initialIndex = 0,
    this.showShare = true,
  });

  /// Pushes the viewer as a full-screen route.
  static Future<void> show(
    BuildContext context, {
    required List<String> imagePaths,
    int initialIndex = 0,
    bool showShare = true,
  }) {
    if (imagePaths.isEmpty) return Future.value();
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullImageViewer(
          imagePaths: imagePaths,
          initialIndex: initialIndex,
          showShare: showShare,
        ),
      ),
    );
  }

  @override
  State<FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<FullImageViewer> {
  late final PageController _pageController;
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

  ImageProvider _provider(String path) =>
      kIsWeb ? NetworkImage(path) : FileImage(File(path)) as ImageProvider;

  Future<void> _share() async {
    if (kIsWeb) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(widget.imagePaths[_currentIndex])]),
    );
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
          if (widget.showShare && !kIsWeb)
            IconButton(icon: const Icon(Icons.share), onPressed: _share),
        ],
      ),
      body: PhotoViewGallery.builder(
        pageController: _pageController,
        itemCount: widget.imagePaths.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        builder: (context, index) => PhotoViewGalleryPageOptions(
          imageProvider: _provider(widget.imagePaths[index]),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4,
        ),
      ),
    );
  }
}
