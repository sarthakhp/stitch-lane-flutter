import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../domain/state/sync_state.dart';

/// Shows [child] only when this device can write (role == writer or
/// unconfigured). In reader mode the [fallback] is shown instead, which
/// defaults to an empty box (hides the widget entirely).
///
/// Uses [context.select] so it only rebuilds when [canWrite] flips, not on
/// every [SyncState] change.
class WriterOnly extends StatelessWidget {
  final Widget child;
  final Widget? fallback;

  const WriterOnly({super.key, required this.child, this.fallback});

  @override
  Widget build(BuildContext context) {
    final canWrite = context.select<SyncState, bool>((s) => s.canWrite);
    return canWrite ? child : (fallback ?? const SizedBox.shrink());
  }
}
