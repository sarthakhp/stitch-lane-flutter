import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/services/sync/sync_role.dart';
import '../../../domain/state/sync_state.dart';

/// A slim, non-intrusive strip shown at the top of the shell when this device
/// is in read-only (mirror) mode. Self-hides for any other role.
class ReaderModeBanner extends StatelessWidget {
  const ReaderModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isReader = context.select<SyncState, bool>(
      (state) => state.role == SyncRole.reader,
    );
    if (!isReader) return const SizedBox.shrink();
    return const _ReaderModeStrip();
  }
}

/// Pure presentation: a slim, single-line "Read-only" strip. Kept separate from
/// the role gating so the layout has no dependency on sync state.
class _ReaderModeStrip extends StatelessWidget {
  const _ReaderModeStrip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 14, color: scheme.onSecondaryContainer),
            const SizedBox(width: 6),
            Text(
              'Read-only',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
