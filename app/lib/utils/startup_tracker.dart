import 'app_logger.dart';

/// Pure-instrumentation helper for measuring cold-start performance.
///
/// Usage:
/// 1. Call [start] as the first line of `main()` — that's our T=0.
///    (Note: the Flutter engine has already been running for tens of ms by
///    the time Dart `main` executes, so this captures Dart-side latency,
///    not OS-icon-tap latency. Add the native splash delta separately when
///    interpreting results.)
/// 2. Sprinkle [mark] calls at boundaries between init phases.
/// 3. Call [finish] once the home screen is fully interactive (i.e.
///    initial data is loaded and visible).
///
/// All marks log via [AppLogger.info] with a consistent `STARTUP:` prefix,
/// so you can grep one run cleanly out of the device log:
/// ```
/// adb logcat | grep STARTUP
/// ```
class StartupTracker {
  StartupTracker._();
  static final StartupTracker instance = StartupTracker._();

  final Stopwatch _sw = Stopwatch();
  final List<_Mark> _marks = [];
  final Set<String> _onceLabels = {};
  bool _finished = false;

  /// Call as the first line of `main()`.
  void start() {
    if (_sw.isRunning) return; // idempotent — main() should only run once
    _sw.start();
    _marks.add(const _Mark('main_start', 0));
    AppLogger.info('STARTUP: main_start @ 0ms');
  }

  /// Record a checkpoint with a short snake_case label. Cheap (microseconds)
  /// so it's fine to sprinkle liberally.
  void mark(String label) {
    if (_finished) return;
    final ms = _sw.elapsedMilliseconds;
    final last = _marks.isNotEmpty ? _marks.last.ms : 0;
    final delta = ms - last;
    _marks.add(_Mark(label, ms));
    AppLogger.info('STARTUP: $label @ ${ms}ms (+${delta}ms)');
  }

  /// Like [mark] but no-ops after the first call for a given label. Use
  /// from places that get rebuilt repeatedly (auth gates, build methods).
  void markOnce(String label) {
    if (_finished) return;
    if (!_onceLabels.add(label)) return;
    mark(label);
  }

  /// Final summary line. Call once when the home screen is interactive
  /// (initial data loaded + first paint of home content).
  void finish() {
    if (_finished) return;
    _finished = true;
    final total = _sw.elapsedMilliseconds;
    _marks.add(_Mark('home_interactive', total));
    _sw.stop();

    final phases = StringBuffer();
    for (var i = 0; i < _marks.length; i++) {
      final m = _marks[i];
      final prev = i == 0 ? 0 : _marks[i - 1].ms;
      if (i > 0) phases.write(', ');
      phases.write('${m.label}=${m.ms - prev}ms');
    }

    AppLogger.info('STARTUP: home_interactive @ ${total}ms (+'
        '${total - _marks[_marks.length - 2].ms}ms)');
    AppLogger.info('STARTUP_SUMMARY: total=${total}ms; phases: $phases');
  }

  /// True after [finish] has been called — guards re-entrant marking when
  /// the home screen rebuilds.
  bool get isFinished => _finished;
}

class _Mark {
  final String label;
  final int ms;
  const _Mark(this.label, this.ms);
}
