import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../backend/repositories/sync_outbox.dart';
import '../backend/repositories/sync_quarantine.dart';
import '../domain/services/sync/sync_coordinator.dart';
import '../domain/services/sync/sync_enable_service.dart';
import '../domain/services/sync/sync_handoff_service.dart';
import '../domain/services/sync/sync_role.dart';
import '../domain/state/sync_state.dart';
import '../presentation/presentation.dart';
import '../presentation/widgets/confirmation_dialog.dart';

/// Control surface for multi-device sync: shows this device's role and lets the
/// user enable sync (as primary or mirror), hand off / force-take the primary
/// role, and review any changes that couldn't sync.
class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  bool _busy = false;
  int _pending = 0;
  int _quarantined = 0;

  @override
  void initState() {
    super.initState();
    _refreshCounts();
  }

  Future<void> _refreshCounts() async {
    final pending = await SyncOutbox.count();
    final quarantined = await SyncQuarantine.count();
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _quarantined = quarantined;
    });
  }

  SyncCoordinator get _coordinator => context.read<SyncCoordinator>();

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      // Last-resort guard: a control-plane action must never crash the app
      // (e.g. a transient Firestore error mid-handoff). Surface it as a
      // retryable message instead of letting it become an unhandled exception.
      _snack('Something went wrong. Please check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refreshCounts();
    }
  }

  // ── actions ───────────────────────────────────────────────────────────────

  Future<void> _enableAsPrimary() async {
    final name = await _promptDeviceName('Name this device', 'Shop tablet');
    if (name == null) return;
    EnableOutcome? outcome;
    await _run(() async {
      outcome = await _coordinator.enableAsPrimary(deviceName: name);
    });
    if (outcome == null) return; // _run already surfaced an error.
    // The account already has a primary recorded in the cloud. If that device
    // is genuinely gone (lost / sold / reset / reinstalled), offer a takeover —
    // otherwise the user is stuck with no way to reclaim primary on this device.
    if (outcome == EnableOutcome.otherDeviceIsPrimary) {
      await _offerTakeover(name);
      return;
    }
    _snack(_enableMessage(outcome!, primary: true));
  }

  Future<void> _offerTakeover(String deviceName) async {
    final other = await _coordinator.currentPrimaryName() ?? 'Another device';
    if (!mounted) return;
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Take over as primary?',
      content: '"$other" is currently set as the primary device. If that device '
          'is gone — lost, sold, reset, or reinstalled — this device can take '
          'over and become the primary. Any changes on "$other" that never '
          'synced will be set aside for review. A rollback snapshot is taken '
          'first. Continue?',
    );
    if (!confirmed) return;
    await _run(() async {
      final outcome =
          await _coordinator.forceEnableAsPrimary(deviceName: deviceName);
      _snack(_enableMessage(outcome, primary: true));
    });
  }

  Future<void> _enableAsReader() async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Mirror an existing device',
      content: 'This device will mirror your primary device. Its current local '
          'data will be replaced by the synced copy. A rollback snapshot is '
          'taken first. Continue?',
    );
    if (!confirmed) return;
    final name = await _promptDeviceName('Name this device', 'My phone');
    if (name == null) return;
    await _run(() async {
      final outcome = await _coordinator.enableAsReader(deviceName: name);
      _snack(_enableMessage(outcome, primary: false));
    });
  }

  Future<void> _disable() async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Turn off sync on this device',
      content: 'This device will stop syncing and work from its local data '
          'only. Other devices keep syncing. Continue?',
    );
    if (!confirmed) return;
    await _run(() async {
      await _coordinator.disableSync();
      _snack('Sync turned off on this device.');
    });
  }

  Future<void> _syncNow() => _run(() async {
        await _coordinator.drainNow();
        _snack('Synced.');
      });

  Future<void> _handoff() => _run(() async {
        final status = await _coordinator.requestHandoff();
        _snack(_handoffMessage(status));
      });

  Future<void> _forceTakeover(String writerName) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Force takeover',
      content: 'Use this only if "$writerName" is lost or broken. This device '
          'becomes the primary. Any changes on "$writerName" that never synced '
          'will be set aside there for review. A rollback snapshot is taken '
          'first. Continue?',
    );
    if (!confirmed) return;
    await _run(() async {
      final status = await _coordinator.requestForceTakeover();
      _snack(_handoffMessage(status));
    });
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncState>();
    return Scaffold(
      appBar: const CustomAppBar(title: Text('Multi-device Sync')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppConfig.spacing16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _statusCard(sync),
                    const SizedBox(height: AppConfig.spacing24),
                    if (sync.role == SyncRole.unconfigured)
                      _setupCard()
                    else
                      _activeCard(sync),
                    if (_quarantined > 0) ...[
                      const SizedBox(height: AppConfig.spacing24),
                      _quarantineCard(),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _statusCard(SyncState sync) {
    final (icon, title, subtitle) = switch (sync.role) {
      SyncRole.writer => (
          Icons.edit_note,
          'This is the primary device',
          'Your changes here sync to your other devices.'
        ),
      SyncRole.reader => (
          Icons.lock_outline,
          'Read-only mirror',
          '${sync.writerDeviceName ?? 'Another device'} is the primary device.'
        ),
      SyncRole.unconfigured => (
          Icons.devices_other,
          'Sync is off',
          'This device works from its own local data.'
        ),
    };
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _setupCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Set up sync',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppConfig.spacing8),
            const Text(
              'Pick ONE device to be the primary (it owns the data). Every other '
              'device mirrors it read-only.',
            ),
            const SizedBox(height: AppConfig.spacing16),
            FilledButton.icon(
              onPressed: _enableAsPrimary,
              icon: const Icon(Icons.star_outline),
              label: const Text('Make this the primary device'),
            ),
            const SizedBox(height: AppConfig.spacing12),
            OutlinedButton.icon(
              onPressed: _enableAsReader,
              icon: const Icon(Icons.devices),
              label: const Text('Mirror an existing device'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeCard(SyncState sync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sync.role == SyncRole.writer) ...[
              Text('Pending changes: $_pending',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppConfig.spacing12),
              OutlinedButton.icon(
                onPressed: _syncNow,
                icon: const Icon(Icons.sync),
                label: const Text('Sync now'),
              ),
            ],
            if (sync.role == SyncRole.reader) ...[
              FilledButton.icon(
                onPressed: _handoff,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Make this the primary device'),
              ),
              const SizedBox(height: AppConfig.spacing12),
              OutlinedButton.icon(
                onPressed: () =>
                    _forceTakeover(sync.writerDeviceName ?? 'the primary'),
                icon: const Icon(Icons.warning_amber),
                label: const Text('Force takeover'),
              ),
            ],
            const SizedBox(height: AppConfig.spacing12),
            TextButton.icon(
              onPressed: _disable,
              icon: const Icon(Icons.sync_disabled),
              label: const Text('Turn off sync on this device'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quarantineCard() {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: const Icon(Icons.report_problem_outlined),
        title: Text('Changes that couldn\'t sync ($_quarantined)'),
        subtitle: const Text('Tap to review.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            Navigator.pushNamed(context, AppConstants.syncQuarantineRoute)
                .then((_) => _refreshCounts()),
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  Future<String?> _promptDeviceName(String title, String hint) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _DeviceNameDialog(title: title, hint: hint),
    );
    if (name == null || name.isEmpty) return null;
    return name;
  }

  String _enableMessage(EnableOutcome outcome, {required bool primary}) {
    switch (outcome) {
      case EnableOutcome.success:
        return primary
            ? 'This device is now the primary. Existing data is publishing.'
            : 'Mirroring started.';
      case EnableOutcome.notSignedIn:
        return 'Sign in first to enable sync.';
      case EnableOutcome.otherDeviceIsPrimary:
        return 'Another device is already the primary. '
            'Use "Mirror an existing device" instead.';
      case EnableOutcome.raced:
        return 'Another device changed the role just now. Try again.';
      case EnableOutcome.snapshotFailed:
        return 'Could not take a safety snapshot — nothing changed.';
      case EnableOutcome.unavailable:
        return 'Could not reach the server. Check your connection and try again.';
    }
  }

  String _handoffMessage(HandoffStatus status) {
    switch (status) {
      case HandoffStatus.success:
        return 'This device is now the primary.';
      case HandoffStatus.offline:
        return 'You need to be online to change the primary device.';
      case HandoffStatus.noControl:
        return 'No primary set yet — use "Make this the primary device".';
      case HandoffStatus.alreadyWriter:
        return 'This device is already the primary.';
      case HandoffStatus.writerHasPending:
        return 'The current primary still has unsynced changes. '
            'Wait until it finishes, or use force takeover.';
      case HandoffStatus.raced:
        return 'Another device changed the role just now. Try again.';
      case HandoffStatus.snapshotFailed:
        return 'Could not take a safety snapshot — takeover cancelled.';
    }
  }
}

/// Device-name prompt. Owns its own [TextEditingController] and disposes it in
/// [State.dispose] — i.e. only after the dialog route is fully gone. Disposing
/// the controller right after `await showDialog` (while the close animation is
/// still rebuilding the TextField) throws "used after being disposed".
class _DeviceNameDialog extends StatefulWidget {
  const _DeviceNameDialog({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  State<_DeviceNameDialog> createState() => _DeviceNameDialogState();
}

class _DeviceNameDialogState extends State<_DeviceNameDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
