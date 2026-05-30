import 'package:flutter/material.dart';
import '../../../config/app_config.dart';
import '../../../domain/services/ai_gateway/usage_event.dart';
import '../../../domain/services/ai_gateway/usage_formatters.dart';

/// One row in the "Recent activity" list. Compact: icon, label + time, a
/// row of info chips (model · tokens or audio · duration), cost on the right.
/// An error tag replaces the chips when the call failed.
class UsageEventTile extends StatelessWidget {
  final UsageEvent event;

  const UsageEventTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = UsageFormatters.callerColor(event.callerTag, cs);
    final hasError = event.errorCode != null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacing16,
        vertical: AppConfig.spacing12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              UsageFormatters.callerIcon(event.callerTag),
              size: 16,
              color: accent,
            ),
          ),
          const SizedBox(width: AppConfig.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        UsageFormatters.callerLabel(event.callerTag),
                        style: tt.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppConfig.spacing8),
                    Text(
                      UsageFormatters.relativeTime(event.occurredAt),
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (hasError)
                  _Chip(
                    label: 'Error: ${event.errorCode}',
                    color: cs.error,
                    icon: Icons.warning_amber_outlined,
                  )
                else
                  Wrap(
                    spacing: AppConfig.spacing8,
                    runSpacing: 4,
                    children: _buildChips(event, cs),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppConfig.spacing12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                UsageFormatters.inr(event.estimatedCostUsd),
                style: tt.bodyMedium?.copyWith(
                  color: hasError ? cs.error : cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                UsageFormatters.usd(event.estimatedCostUsd),
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChips(UsageEvent e, ColorScheme cs) {
    final chips = <Widget>[];

    // Provider + model packed into one chip so the dashboard reads "this
    // call went to Sarvam, model bulbul:v3" at a glance. Cheaper than a
    // separate provider chip — the line gets crowded with tokens / duration.
    chips.add(_Chip(
      label: '${UsageFormatters.providerName(e.provider.name)} · ${e.model}',
      color: cs.onSurfaceVariant,
      icon: Icons.memory,
    ));

    if (e.totalTokens != null && e.totalTokens! > 0) {
      chips.add(_Chip(
        label: '${UsageFormatters.tokens(e.totalTokens)} tokens',
        color: cs.onSurfaceVariant,
        icon: Icons.token_outlined,
      ));
    }
    if (e.audioInputMs != null && e.audioInputMs! > 0) {
      chips.add(_Chip(
        label: UsageFormatters.audioMs(e.audioInputMs),
        color: cs.onSurfaceVariant,
        icon: Icons.mic_outlined,
      ));
    }
    if (e.inputChars != null && e.inputChars! > 0) {
      chips.add(_Chip(
        label: '${e.inputChars} chars',
        color: cs.onSurfaceVariant,
        icon: Icons.text_fields_outlined,
      ));
    }
    chips.add(_Chip(
      label: UsageFormatters.duration(e.durationMs),
      color: cs.onSurfaceVariant,
      icon: Icons.timer_outlined,
    ));

    return chips;
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Chip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: tt.labelSmall?.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
