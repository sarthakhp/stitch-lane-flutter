import 'package:flutter/material.dart';

import '../../../config/app_config.dart';
import '../../../domain/models/order_proposal.dart';

/// Collapsible read-only view of the agent's recent actions — tool calls,
/// tool results, and the agent's commentary text. Surfacing this gives the
/// tailor a sense of *what* the AI did and is invaluable when something
/// looks off. Not the primary affordance — collapsed by default.
class AgentLogView extends StatefulWidget {
  final List<AgentLogEntry> entries;
  final bool initiallyExpanded;

  const AgentLogView({
    super.key,
    required this.entries,
    this.initiallyExpanded = false,
  });

  @override
  State<AgentLogView> createState() => _AgentLogViewState();
}

class _AgentLogViewState extends State<AgentLogView> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConfig.spacing16,
                vertical: AppConfig.spacing12,
              ),
              child: Row(
                children: [
                  Icon(Icons.smart_toy_outlined, color: colorScheme.primary),
                  const SizedBox(width: AppConfig.spacing8),
                  Expanded(
                    child: Text(
                      'AI activity (${widget.entries.length})',
                      style: textTheme.titleSmall,
                    ),
                  ),
                  Icon(_expanded
                      ? Icons.expand_less
                      : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConfig.spacing16,
                vertical: AppConfig.spacing8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.entries.map(_buildEntry).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEntry(AgentLogEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (icon, color) = _styleFor(entry.kind, colorScheme);
    final summary = _summarize(entry);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConfig.spacing4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppConfig.spacing8),
          Expanded(
            child: Text(
              summary,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontFamily: entry.kind == AgentLogKind.agentText
                    ? null
                    : 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _styleFor(AgentLogKind kind, ColorScheme cs) {
    switch (kind) {
      case AgentLogKind.toolCall:
        return (Icons.build_outlined, cs.primary);
      case AgentLogKind.toolResult:
        return (Icons.check_circle_outline, cs.tertiary);
      case AgentLogKind.agentText:
        return (Icons.chat_bubble_outline, cs.secondary);
      case AgentLogKind.info:
        return (Icons.info_outline, cs.onSurfaceVariant);
      case AgentLogKind.error:
        return (Icons.error_outline, cs.error);
    }
  }

  String _summarize(AgentLogEntry entry) {
    switch (entry.kind) {
      case AgentLogKind.toolCall:
        final argSummary = _summarizeArgs(entry.data);
        return '${entry.label}($argSummary)';
      case AgentLogKind.toolResult:
        final data = entry.data;
        if (data == null) return entry.label;
        if (data['error'] != null) return '${entry.label} → error: ${data['error']}';
        return '${entry.label} → ok';
      case AgentLogKind.agentText:
      case AgentLogKind.info:
      case AgentLogKind.error:
        return entry.label;
    }
  }

  String _summarizeArgs(Map<String, dynamic>? args) {
    if (args == null || args.isEmpty) return '';
    return args.entries
        .map((e) {
          final v = e.value;
          if (v is String && v.length > 24) {
            return '${e.key}: "${v.substring(0, 24)}…"';
          }
          return '${e.key}: $v';
        })
        .join(', ');
  }
}
