import 'package:flutter/foundation.dart';

/// Mixin for [ChangeNotifier]s whose state is mutated from async callbacks that
/// can resolve *after* the owner has been disposed — e.g. the voice
/// controllers, whose `start()` / `stop()` await microphone & network I/O while
/// the widget may be torn down mid-flight.
///
/// Without this, a late `notifyListeners()` throws
/// "A <Controller> was used after being disposed".
///
/// Usage:
///  - call [safeNotify] instead of [notifyListeners];
///  - check [isDisposed] right after an `await` before touching more state.
mixin DisposeSafeNotifier on ChangeNotifier {
  bool _isDisposed = false;

  /// True once [dispose] has run. Guard async continuations with this.
  bool get isDisposed => _isDisposed;

  /// [notifyListeners], but a no-op once disposed.
  void safeNotify() {
    if (_isDisposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
