import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../domain/services/sync/media_resolver.dart';
import '../../../utils/app_logger.dart';

/// Displays a local file (or web) image, decoding it at roughly the size it is
/// shown rather than at full camera resolution.
///
/// Pass [decodeWidth] (logical px) for thumbnails and grids — it is scaled by
/// the device pixel ratio so output stays crisp while memory stays bounded. A
/// single 12 MP photo decoded full-size is ~48 MB in RAM; a grid of them will
/// stutter or OOM a low-end phone. Omit [decodeWidth] for full-screen views
/// that need every pixel (e.g. pinch-to-zoom).
///
/// On a reader the stored [path] is the writer's device-absolute path and won't
/// exist locally; we resolve it by basename and lazy-download from Drive via
/// [MediaResolver]. When the file is already present (writer / single device /
/// previously downloaded) we render it synchronously with no flicker and no
/// network call — identical to before.
class LocalImage extends StatefulWidget {
  final String path;
  final BoxFit fit;
  final double? decodeWidth;

  const LocalImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.decodeWidth,
  });

  @override
  State<LocalImage> createState() => _LocalImageState();
}

class _LocalImageState extends State<LocalImage> {
  // Set only when the file isn't already on disk — kicks off the lazy download.
  Future<File?>? _resolve;

  @override
  void initState() {
    super.initState();
    _maybeResolve();
  }

  @override
  void didUpdateWidget(LocalImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _resolve = null;
      _maybeResolve();
    }
  }

  void _maybeResolve() {
    if (kIsWeb) return;
    if (File(widget.path).existsSync()) return; // fast path handled in build()
    _resolve = MediaResolver.resolveImage(widget.path);
  }

  int? _cacheWidth(BuildContext context) {
    if (widget.decodeWidth == null) return null;
    return (widget.decodeWidth! * MediaQuery.devicePixelRatioOf(context)).round();
  }

  Widget _image(File file, int? cacheWidth) => Image.file(
        file,
        fit: widget.fit,
        cacheWidth: cacheWidth,
        errorBuilder: _onError,
      );

  Widget _onError(BuildContext context, Object error, StackTrace? _) {
    AppLogger.error('Image load failed: ${widget.path}', error);
    return _placeholder(context, Icons.broken_image, Theme.of(context).colorScheme.error);
  }

  // Media not available on this device yet and not downloadable (offline /
  // not on Drive). Expected on a reader — degrade quietly, don't log an error.
  Widget _unavailable(BuildContext context) => _placeholder(
        context,
        Icons.image_not_supported_outlined,
        Theme.of(context).colorScheme.onSurfaceVariant,
      );

  Widget _placeholder(BuildContext context, IconData icon, Color color) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(icon, color: color),
    );
  }

  Widget _loading(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cacheWidth = _cacheWidth(context);

    if (kIsWeb) {
      return Image.network(
        widget.path,
        fit: widget.fit,
        cacheWidth: cacheWidth,
        errorBuilder: _onError,
      );
    }

    final direct = File(widget.path);
    if (direct.existsSync()) return _image(direct, cacheWidth);

    final future = _resolve;
    if (future == null) return _unavailable(context);
    return FutureBuilder<File?>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _loading(context);
        }
        final file = snap.data;
        if (file == null) return _unavailable(context);
        return _image(file, cacheWidth);
      },
    );
  }
}
