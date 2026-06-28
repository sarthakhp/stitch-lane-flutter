import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../backend/repositories/sync_quarantine.dart';
import '../presentation/presentation.dart';
import '../presentation/widgets/confirmation_dialog.dart';

/// Lists writes that were set aside because this device lost the primary role
/// while it had un-pushed changes (the fence quarantines them so nothing is
/// lost silently). The user reviews them and discards once handled.
class SyncQuarantineScreen extends StatefulWidget {
  const SyncQuarantineScreen({super.key});

  @override
  State<SyncQuarantineScreen> createState() => _SyncQuarantineScreenState();
}

class _SyncQuarantineScreenState extends State<SyncQuarantineScreen> {
  late Future<List<QuarantineRow>> _rows;

  @override
  void initState() {
    super.initState();
    _rows = SyncQuarantine.all();
  }

  void _reload() => setState(() => _rows = SyncQuarantine.all());

  Future<void> _discardAll() async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Discard set-aside changes',
      content: 'These changes were not synced because another device became '
          'the primary. Discard them permanently?',
    );
    if (!confirmed) return;
    await SyncQuarantine.clear();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: const Text("Changes that couldn't sync"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Discard all',
            onPressed: _discardAll,
          ),
        ],
      ),
      body: FutureBuilder<List<QuarantineRow>>(
        future: _rows,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data ?? const [];
          if (rows.isEmpty) {
            return const Center(child: Text('Nothing set aside.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppConfig.spacing16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _tile(rows[i]),
          );
        },
      ),
    );
  }

  Widget _tile(QuarantineRow row) {
    final when = DateTime.fromMillisecondsSinceEpoch(row.quarantinedAt);
    final isDelete = row.op == 'delete';
    return ListTile(
      leading: Icon(isDelete ? Icons.delete_outline : Icons.edit_outlined),
      title: Text('${_label(row.collection)} · ${isDelete ? 'deletion' : 'edit'}'),
      subtitle: Text(
        '${row.reason}\n${DateFormat('MMM d, y · h:mm a').format(when)}',
      ),
      isThreeLine: true,
    );
  }

  String _label(String collection) {
    switch (collection) {
      case 'customers':
        return 'Customer';
      case 'orders':
        return 'Order';
      case 'measurements':
        return 'Measurement';
      default:
        return collection;
    }
  }
}
