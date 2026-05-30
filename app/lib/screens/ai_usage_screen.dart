import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../domain/services/ai_gateway/usage_event.dart';
import '../domain/state/ai_usage_state.dart';
import '../presentation/presentation.dart';
import '../presentation/widgets/usage/usage_by_feature_card.dart';
import '../presentation/widgets/usage/usage_event_tile.dart';
import '../presentation/widgets/usage/usage_kpi_row.dart';

/// The "AI Usage & Cost" dashboard.
///
/// Lifecycle: a single [AiUsageState] is created in [initState] and disposed
/// here — the screen owns its view-model rather than going through an
/// app-wide Provider because there's no other consumer.
class AiUsageScreen extends StatefulWidget {
  const AiUsageScreen({super.key});

  @override
  State<AiUsageScreen> createState() => _AiUsageScreenState();
}

class _AiUsageScreenState extends State<AiUsageScreen> {
  late final AiUsageState _state;

  @override
  void initState() {
    super.initState();
    _state = AiUsageState();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: Text('AI Usage & Cost')),
      body: ListenableBuilder(
        listenable: _state,
        builder: (context, _) => RefreshIndicator(
          onRefresh: _state.refresh,
          child: _state.lastError != null
              ? _ErrorState(error: _state.lastError!, onRetry: _state.refresh)
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppConfig.spacing16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: _Body(state: _state),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final AiUsageState state;
  const _Body({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final hasMissingCost = state.todaySummary.eventsMissingCost > 0 ||
        state.weekSummary.eventsMissingCost > 0 ||
        state.monthSummary.eventsMissingCost > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        UsageKpiRow(
          today: state.todaySummary,
          week: state.weekSummary,
          month: state.monthSummary,
        ),
        if (hasMissingCost) ...[
          const SizedBox(height: AppConfig.spacing12),
          _PricingHealthBanner(),
        ],

        const SizedBox(height: AppConfig.spacing24),
        Text('Window', style: tt.titleSmall),
        const SizedBox(height: AppConfig.spacing8),
        _WindowSelector(
          selected: state.selectedWindow,
          onChanged: state.selectWindow,
        ),
        const SizedBox(height: AppConfig.spacing16),
        UsageByFeatureCard(byFeature: state.byFeature),

        const SizedBox(height: AppConfig.spacing24),
        Row(
          children: [
            Icon(Icons.history, size: 18, color: cs.primary),
            const SizedBox(width: AppConfig.spacing8),
            Text(
              'Recent activity',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (state.isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: AppConfig.spacing8),
        _RecentList(events: state.recent),
        const SizedBox(height: AppConfig.spacing24),
      ],
    );
  }
}

class _WindowSelector extends StatelessWidget {
  final UsageWindow selected;
  final void Function(UsageWindow) onChanged;

  const _WindowSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<UsageWindow>(
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
      segments: const [
        ButtonSegment(value: UsageWindow.today, label: Text('Today')),
        ButtonSegment(value: UsageWindow.last7Days, label: Text('7 days')),
        ButtonSegment(value: UsageWindow.last30Days, label: Text('30 days')),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
      showSelectedIcon: false,
    );
  }
}

class _RecentList extends StatelessWidget {
  final List<UsageEvent> events;
  const _RecentList({required this.events});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (events.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppConfig.spacing24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, color: cs.onSurfaceVariant),
                const SizedBox(height: AppConfig.spacing8),
                Text(
                  'No AI calls in this window yet.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++) ...[
            UsageEventTile(event: events[i]),
            if (i < events.length - 1)
              Divider(
                height: 1,
                indent: AppConfig.spacing16,
                endIndent: AppConfig.spacing16,
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}

class _PricingHealthBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      color: cs.tertiaryContainer.withValues(alpha: 0.4),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing12),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: cs.tertiary),
            const SizedBox(width: AppConfig.spacing8),
            Expanded(
              child: Text(
                'Some calls have no pricing entry — totals exclude them. '
                'Add the rate in pricing.dart to include them.',
                style: tt.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ListView(
      // ListView so RefreshIndicator's pull-to-refresh still works in the
      // error state.
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: AppConfig.spacing48),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConfig.spacing24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: cs.error),
                const SizedBox(height: AppConfig.spacing12),
                Text(
                  'Could not load usage data',
                  style: tt.titleMedium,
                ),
                const SizedBox(height: AppConfig.spacing8),
                Text(
                  '$error',
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConfig.spacing16),
                FilledButton.tonal(
                  onPressed: () => onRetry(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
