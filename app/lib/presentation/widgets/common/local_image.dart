import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../utils/app_logger.dart';

/// Displays a local file (or web) image, decoding it at roughly the size it is
/// shown rather than at full camera resolution.
///
/// Pass [decodeWidth] (logical px) for thumbnails and grids — it is scaled by
/// the device pixel ratio so output stays crisp while memory stays bounded. A
/// single 12 MP photo decoded full-size is ~48 MB in RAM; a grid of them will
/// stutter or OOM a low-end phone. Omit [decodeWidth] for full-screen views
/// that need every pixel (e.g. pinch-to-zoom).
class LocalImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final double? decodeWidth;

  const LocalImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.decodeWidth,
  });

  int? _cacheWidth(BuildContext context) {
    if (decodeWidth == null) return null;
    return (decodeWidth! * MediaQuery.devicePixelRatioOf(context)).round();
  }

  Widget _onError(BuildContext context, Object error, StackTrace? _) {
    AppLogger.error('Image load failed: $path', error);
    return Container(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Icon(
        Icons.broken_image,
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cacheWidth = _cacheWidth(context);
    return kIsWeb
        ? Image.network(
            path,
            fit: fit,
            cacheWidth: cacheWidth,
            errorBuilder: _onError,
          )
        : Image.file(
            File(path),
            fit: fit,
            cacheWidth: cacheWidth,
            errorBuilder: _onError,
          );
  }
}
