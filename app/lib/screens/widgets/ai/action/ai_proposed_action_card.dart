import 'package:flutter/material.dart';

import '../../../../config/app_config.dart';
import '../../../../domain/services/ai_action/action_labels.dart';
import '../../../../domain/services/ai_action/proposed_action.dart';
import 'ai_action_candidate_tile.dart';

typedef ConfirmActionCallback = Future<void> Function(
    ProposedAction action, List<String> orderIds);

/// Renders a staged [ProposedAction] in the chat. The user ticks one or many
/// orders and Confirm applies the change to all ticked ones (a single
/// candidate is pre-ticked, so the common case is one tap). Once executed it
/// shows a ✓ result with the affected orders highlighted (or an error + retry).
class AiProposedActionCard extends StatefulWidget {
  final ProposedAction action;
  final ConfirmActionCallback onConfirm;
  final void Function(ProposedAction action) onCancel;
  final void Function(String orderId) onOpen;

  const AiProposedActionCard({
    super.key,
    required this.action,
    required this.onConfirm,
    required this.onCancel,
    required this.onOpen,
  });

  @override
  State<AiProposedActionCard> createState() => _AiProposedActionCardState();
}

class _AiProposedActionCardState extends State<AiProposedActionCard> {
  final Set<String> _selected = {};
  bool _running = false;

  @override
  void initState() {
    super.initState();
    // Pre-tick when there's exactly one order, so it stays a single Confirm tap.
    if (widget.action.candidates.length == 1) {
      _selected.add(widget.action.candidates.first.orderId);
    }
  }

  @override
  void didUpdateWidget(AiProposedActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action.status != widget.action.status) {
      _running = false;
    }
  }

  void _toggle(String orderId) {
    setState(() {
      if (!_selected.remove(orderId)) _selected.add(orderId);
    });
  }

  Future<void> _confirm() async {
    if (_selected.isEmpty || _running) return;
    setState(() => _running = true);
    await widget.onConfirm(widget.action, _selected.toList());
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (widget.action.status) {
      case ActionStatus.done:
        return _resolvedCard(
          context,
          icon: Icons.check_circle,
          iconColor: Colors.green.shade600,
          header: widget.action.resultMessage ??
              '${ActionLabels.changeSummary(widget.action)} — done.',
          highlightOrderIds: widget.action.executedOrderIds.toSet(),
        );
      case ActionStatus.cancelled:
        return _resolvedCard(
          context,
          icon: Icons.cancel_outlined,
          iconColor: colorScheme.onSurfaceVariant,
          header: '${ActionLabels.changeSummary(widget.action)} — Cancelled',
          highlightOrderIds: const {},
        );
      case ActionStatus.failed:
      case ActionStatus.proposed:
        return _proposeCard(context);
    }
  }

  Widget _proposeCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final action = widget.action;
    final multi = action.candidates.length > 1;
    final failed = action.status == ActionStatus.failed;

    return _shell(
      context,
      borderColor: failed ? colorScheme.error : colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, size: 18, color: colorScheme.primary),
              const SizedBox(width: AppConfig.spacing4),
              Expanded(
                child: Text(
                  ActionLabels.changeSummary(action),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConfig.spacing8),
          Text(
            multi ? 'Pick the orders, then Confirm.' : 'Tap Confirm to apply.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppConfig.spacing8),
          for (final candidate in action.candidates)
            Padding(
              padding: const EdgeInsets.only(bottom: AppConfig.spacing8),
              child: AiActionCandidateTile(
                candidate: candidate,
                selected: _selected.contains(candidate.orderId),
                onTap: () => _toggle(candidate.orderId),
                onOpen: () => widget.onOpen(candidate.orderId),
              ),
            ),
          if (failed && action.resultMessage != null) ...[
            Text(
              action.resultMessage!,
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
            const SizedBox(height: AppConfig.spacing8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _running ? null : () => widget.onCancel(action),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AppConfig.spacing8),
              FilledButton(
                onPressed:
                    (_selected.isNotEmpty && !_running) ? _confirm : null,
                child: _running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(failed ? 'Try again' : 'Confirm'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Card for a finished action (done or cancelled): a status header plus the
  /// options that were shown, read-only. Orders in [highlightOrderIds] (the
  /// ones the change was applied to) are highlighted.
  Widget _resolvedCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String header,
    required Set<String> highlightOrderIds,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return _shell(
      context,
      borderColor: colorScheme.outlineVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: AppConfig.spacing8),
              Expanded(
                child: Text(
                  header,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          for (final candidate in widget.action.candidates)
            Padding(
              padding: const EdgeInsets.only(top: AppConfig.spacing8),
              child: AiActionCandidateTile(
                candidate: candidate,
                selected: highlightOrderIds.contains(candidate.orderId),
                showSelection: false,
                onTap: () {},
                onOpen: () => widget.onOpen(candidate.orderId),
              ),
            ),
        ],
      ),
    );
  }

  Widget _shell(BuildContext context,
      {required Color borderColor, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        top: AppConfig.spacing8,
        left: 16.0 + AppConfig.spacing4,
      ),
      padding: const EdgeInsets.all(AppConfig.spacing12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: child,
    );
  }
}
