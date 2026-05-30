import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../backend/repositories/ai_usage_repository.dart';
import '../../utils/app_logger.dart';
import '../services/ai_gateway/usage_event.dart';
import '../services/ai_gateway/usage_recorder.dart';
// AppLogger is imported above; kept because refresh() still logs failures
// (cheap, useful breadcrumb for future debugging via the Developer screen).

/// Which time-window the dashboard's secondary section is showing.
enum UsageWindow {
  today,
  last7Days,
  last30Days;

  /// Range from window-start to now. Today snaps to the local-time midnight.
  /// Returned as a record so this file doesn't have to depend on Flutter's
  /// material.dart for [DateTimeRange] — keeps state importable from tests.
  ({DateTime start, DateTime end}) range() {
    final now = DateTime.now();
    switch (this) {
      case UsageWindow.today:
        return (start: DateTime(now.year, now.month, now.day), end: now);
      case UsageWindow.last7Days:
        return (start: now.subtract(const Duration(days: 7)), end: now);
      case UsageWindow.last30Days:
        return (start: now.subtract(const Duration(days: 30)), end: now);
    }
  }

  String get label {
    switch (this) {
      case UsageWindow.today:
        return 'Today';
      case UsageWindow.last7Days:
        return '7 days';
      case UsageWindow.last30Days:
        return '30 days';
    }
  }
}

/// View-model for [AiUsageScreen]. Owns:
///   - "hero" KPI numbers (Today / 7-day / 30-day cost + event counts)
///   - the selected secondary window
///   - breakdown by feature for that window
///   - a recent-events list for that window
///
/// Refreshes the secondary window whenever [selectWindow] is called, and
/// refreshes everything on each new [UsageEvent] coming through the
/// [UsageRecorder] broadcast stream (so the screen is live without polling).
class AiUsageState extends ChangeNotifier {
  final AiUsageRepository _repo;
  StreamSubscription<UsageEvent>? _sub;

  // ── Hero numbers (always all three windows so the top row is stable) ──
  UsageSummary todaySummary = UsageSummary.zero;
  UsageSummary weekSummary = UsageSummary.zero;
  UsageSummary monthSummary = UsageSummary.zero;

  // ── Secondary section: the user-selected window ──
  UsageWindow selectedWindow = UsageWindow.today;
  Map<String, UsageSummary> byFeature = const {};
  List<UsageEvent> recent = const [];

  bool isLoading = true;
  Object? lastError;

  AiUsageState({AiUsageRepository? repo})
      : _repo = repo ?? AiUsageRepository() {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await refresh();
    try {
      _sub = UsageRecorder.instance.events.listen(
        (_) => refresh(),
        onError: (_) {},
      );
    } catch (e, st) {
      // Subscription failures are non-fatal — the screen still has its
      // initial data from refresh(). Worth logging because it means live
      // updates won't work for this screen instance.
      AppLogger.error(
        'AiUsageState: failed to subscribe to UsageRecorder',
        e,
        st,
      );
    }
  }

  /// Refetches all four data slices in parallel. Cheap — every query hits
  /// a small SQLite aggregate.
  Future<void> refresh() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = now.subtract(const Duration(days: 7));
    final monthStart = now.subtract(const Duration(days: 30));
    final selected = selectedWindow.range();

    try {
      final results = await Future.wait([
        _repo.summarize(from: todayStart, to: now),
        _repo.summarize(from: weekStart, to: now),
        _repo.summarize(from: monthStart, to: now),
        _repo.summarizeByCallerTag(from: selected.start, to: selected.end),
        _repo.queryRange(
          from: selected.start,
          to: selected.end,
          limit: 100,
        ),
      ]);

      todaySummary = results[0] as UsageSummary;
      weekSummary = results[1] as UsageSummary;
      monthSummary = results[2] as UsageSummary;
      byFeature = results[3] as Map<String, UsageSummary>;
      recent = results[4] as List<UsageEvent>;
      lastError = null;
    } catch (e, st) {
      AppLogger.error('AiUsageState.refresh: failed', e, st);
      lastError = e;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectWindow(UsageWindow window) {
    if (window == selectedWindow) return;
    selectedWindow = window;
    isLoading = true;
    notifyListeners();
    refresh();
  }

  UsageSummary get selectedSummary {
    switch (selectedWindow) {
      case UsageWindow.today:
        return todaySummary;
      case UsageWindow.last7Days:
        return weekSummary;
      case UsageWindow.last30Days:
        return monthSummary;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
