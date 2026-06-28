import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/services/sync/sync_role.dart';
import '../../../domain/state/sync_state.dart';
import 'reader_mode_banner.dart';

/// Wraps the whole app so the read-only strip shows on *every* screen (the
/// shell and any pushed detail route), not just the home shell.
///
/// In reader mode it pins the banner below the status bar and strips the top
/// inset from the wrapped content, so each screen's own AppBar sits flush under
/// the banner instead of reserving the status-bar gap twice. In any other role
/// the child is returned untouched — zero layout change off the mirror path.
class ReaderModeOverlay extends StatelessWidget {
  const ReaderModeOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isReader = context.select<SyncState, bool>(
      (state) => state.role == SyncRole.reader,
    );
    if (!isReader) return child;

    return Column(
      children: [
        const SafeArea(bottom: false, child: ReaderModeBanner()),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
