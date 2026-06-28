import 'package:flutter/foundation.dart';

/// App-wide guard that keeps at most one audio source playing at a time.
///
/// Each player widget owns its own [AudioPlayer], so without coordination two
/// can play at once. A widget [claim]s playback when it starts; the previously
/// active claimant is asked to pause via the callback it registered. When a
/// widget stops on its own (pause / complete / dispose) it [release]s its claim
/// so a stale callback is never invoked.
class AudioPlaybackCoordinator {
  AudioPlaybackCoordinator._();

  static final AudioPlaybackCoordinator instance = AudioPlaybackCoordinator._();

  Object? _activeOwner;
  VoidCallback? _pauseActive;

  /// Mark [owner] as the playing source, pausing whichever was playing before.
  /// [pause] is invoked later if another source claims playback.
  void claim(Object owner, VoidCallback pause) {
    if (_activeOwner != null && !identical(_activeOwner, owner)) {
      _pauseActive?.call();
    }
    _activeOwner = owner;
    _pauseActive = pause;
  }

  /// Drop [owner]'s claim, but only if it still holds it — so a newer claimant
  /// that already took over is left untouched.
  void release(Object owner) {
    if (identical(_activeOwner, owner)) {
      _activeOwner = null;
      _pauseActive = null;
    }
  }
}
