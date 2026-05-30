import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../backend/backend.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../domain/domain.dart';
import '../presentation/presentation.dart';
import '../presentation/widgets/confirmation_dialog.dart';

/// AI-driven order creator. Tailor picks a customer, voice-dumps everything
/// about a multi-item visit, the agent proposes structured orders +
/// (optionally) a measurement record, and the tailor reviews / refines
/// before a single batched commit.
class OrderCreatorScreen extends StatefulWidget {
  /// Optional customer to start with — entry points that already know who
  /// the order is for (e.g. "create order for this customer" from a customer
  /// detail screen) pass this to skip the picker step.
  final Customer? initialCustomer;

  const OrderCreatorScreen({super.key, this.initialCustomer});

  @override
  State<OrderCreatorScreen> createState() => _OrderCreatorScreenState();
}

class _OrderCreatorScreenState extends State<OrderCreatorScreen> {
  late final OrderCreatorController _controller;
  // Owns the refinement-bar's text input. AiInputArea expects the parent to
  // own the controller so the parent can clear it on send and keep it in
  // sync with any voice-input append.
  final TextEditingController _feedbackCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = OrderCreatorController(
      orderState: context.read<OrderState>(),
      orderRepository: context.read<OrderRepository>(),
      measurementState: context.read<MeasurementState>(),
      measurementRepository: context.read<MeasurementRepository>(),
    );
    if (widget.initialCustomer != null) {
      _controller.selectCustomer(widget.initialCustomer!);
    }
    _controller.addListener(_onPhaseChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onPhaseChanged);
    _controller.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  /// Pops back to the previous screen on a successful commit so the tailor
  /// lands in the orders list with the new entries already visible.
  void _onPhaseChanged() {
    if (_controller.phase == CreatorPhase.done && mounted) {
      final count = _controller.savedOrders?.length ?? 0;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          count == 1
              ? 'Created 1 order'
              : 'Created $count orders',
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return PopScope(
          canPop: !_controller.hasUnsavedWork && !_controller.isAgentBusy,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final confirm = await ConfirmationDialog.show(
              context: context,
              title: 'Discard draft?',
              content:
                  'Your draft will be lost. Are you sure you want to leave?',
            );
            if (!context.mounted) return;
            if (confirm) Navigator.of(context).pop();
          },
          child: Scaffold(
            appBar: CustomAppBar(
              title: const Text('Create orders'),
              actions: [
                TextButton(
                  onPressed: _controller.isAgentBusy
                      ? null
                      : _openManualForm,
                  child: const Text('Manual'),
                ),
              ],
            ),
            body: _buildBody(),
            bottomNavigationBar: _buildBottomBar(),
          ),
        );
      },
    );
  }

  // ── body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CustomerPickerRow(controller: _controller),
            const SizedBox(height: AppConfig.spacing16),
            Expanded(child: _buildPhaseBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseBody() {
    switch (_controller.phase) {
      case CreatorPhase.pickingCustomer:
        // When there are no customers yet, the search dropdown (which holds
        // "Create new customer") never opens, so surface a create button here.
        return Consumer<CustomerState>(
          builder: (context, customerState, _) {
            if (customerState.customers.isEmpty) {
              return _buildNoCustomersHint();
            }
            return _buildHint(
              icon: Icons.person_outline,
              text: 'Pick a customer above to start.',
            );
          },
        );
      case CreatorPhase.ready:
        return _buildReady();
      case CreatorPhase.transcribing:
      case CreatorPhase.agentRunning:
        return _buildAgentBusy();
      case CreatorPhase.reviewing:
        return _buildReview();
      case CreatorPhase.committing:
        return _buildHint(
          icon: Icons.save_outlined,
          text: 'Saving orders…',
          showSpinner: true,
        );
      case CreatorPhase.done:
        return const SizedBox.shrink();
      case CreatorPhase.error:
        return _buildError();
    }
  }

  Widget _buildReady() {
    final theme = Theme.of(context);
    // LayoutBuilder + minHeight=viewport keeps the hero block vertically
    // centered when there's room (the common case), but lets it scroll when
    // the keyboard slides up and shrinks the available space — otherwise the
    // fixed-height Column overflows the parent Expanded and Flutter paints
    // the yellow/black hazard stripes we were seeing.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic_none,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: AppConfig.spacing16),
                Text(
                  'Record everything about this customer\'s visit',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConfig.spacing8),
                Text(
                  'Items to be stitched, prices, due dates, measurements — '
                  'speak naturally. The AI will split it into orders.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConfig.spacing24),
                FilledButton.icon(
                  icon: const Icon(Icons.mic),
                  label: const Text('Start recording'),
                  onPressed: _recordInitialDump,
                ),
                const SizedBox(height: AppConfig.spacing12),
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Or build the draft manually'),
                  onPressed: _controller.addBlankOrder,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAgentBusy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: AppConfig.spacing16),
        Expanded(
          child: SingleChildScrollView(
            child: AgentLogView(
              entries: _controller.log,
              initiallyExpanded: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReview() {
    final draft = _controller.draft;
    final theme = Theme.of(context);
    return Column(
      children: [
        // ── Scrollable content ──
        // Everything that isn't the refine bar lives here. Pulling the refine
        // bar out of the scroll view means the tailor doesn't have to scroll
        // past the orders / measurements / activity log every time she wants
        // to type a correction.
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_controller.agentCommentary != null) ...[
                  _CommentaryBanner(text: _controller.agentCommentary!),
                  const SizedBox(height: AppConfig.spacing12),
                ],
                _SectionHeader(label: 'Orders (${draft.orders.length})'),
                const SizedBox(height: AppConfig.spacing8),
                for (final order in draft.orders) ...[
                  ProposedOrderCard(
                    key: ValueKey(order.id),
                    order: order,
                    enabled: !_controller.isAgentBusy,
                    onEdit: ({
                      title,
                      value,
                      clearValue = false,
                      dueDate,
                      description,
                      clearDescription = false,
                      imagePaths,
                    }) =>
                        _controller.editOrder(
                      order.id,
                      title: title,
                      value: value,
                      clearValue: clearValue,
                      dueDate: dueDate,
                      description: description,
                      clearDescription: clearDescription,
                      imagePaths: imagePaths,
                    ),
                    onRemove: () => _controller.removeOrder(order.id),
                  ),
                  const SizedBox(height: AppConfig.spacing8),
                ],
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add order'),
                  onPressed: _controller.isAgentBusy
                      ? null
                      : _controller.addBlankOrder,
                ),
                const SizedBox(height: AppConfig.spacing16),
                if (draft.measurements.isNotEmpty) ...[
                  const _SectionHeader(label: 'Measurements'),
                  const SizedBox(height: AppConfig.spacing8),
                  for (final m in draft.measurements) ...[
                    ProposedMeasurementCard(
                      key: ValueKey(m.id),
                      measurement: m,
                      enabled: !_controller.isAgentBusy,
                      onEdit: (v) =>
                          _controller.editMeasurement(m.id, description: v),
                      onRemove: () => _controller.removeMeasurement(m.id),
                    ),
                    const SizedBox(height: AppConfig.spacing8),
                  ],
                ] else ...[
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add measurement'),
                    onPressed: _controller.isAgentBusy
                        ? null
                        : _controller.addBlankMeasurement,
                  ),
                ],
                const SizedBox(height: AppConfig.spacing16),
                if (_controller.transcript != null) ...[
                  _TranscriptPreview(text: _controller.transcript!),
                  const SizedBox(height: AppConfig.spacing12),
                ],
                AgentLogView(entries: _controller.log),
                const SizedBox(height: AppConfig.spacing16),
              ],
            ),
          ),
        ),

        // ── Pinned refine bar ──
        // Sits between the scrolling content above and the "Create N orders"
        // CTA in the bottom-nav slot. Subtle top divider separates it from
        // the scroll area so the boundary is visible when the content above
        // is mid-scroll.
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          padding: const EdgeInsets.only(top: AppConfig.spacing12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConfig.spacing4,
                ),
                child: Text(
                  'Refine',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppConfig.spacing4),
              // Same visuals as the AI chat input. The mic opens a
              // bottom-sheet recorder rather than swapping the bar into
              // voice mode inline — the order creator already has the
              // "Create N orders" sticky CTA below; the inline voice UI's
              // Done/Send buttons would land behind it.
              AiInputBar(
                controller: _feedbackCtrl,
                isLoading: _controller.isAgentBusy,
                inline: true,
                hintText: 'Refine the draft…',
                onSend: _submitFeedback,
                onMicTap: _recordFeedbackViaSheet,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: theme.colorScheme.error),
            const SizedBox(height: AppConfig.spacing12),
            Text(
              _controller.errorMessage ?? 'Something went wrong.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConfig.spacing24),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              onPressed: () {
                _controller.clearError();
                if (_controller.transcript == null) {
                  _recordInitialDump();
                }
              },
            ),
            const SizedBox(height: AppConfig.spacing8),
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Continue in manual form'),
              onPressed: _openManualForm,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCustomersHint() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_add_alt_1_outlined,
              size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: AppConfig.spacing12),
          Text(
            'No customers yet.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConfig.spacing16),
          FilledButton.icon(
            icon: const Icon(Icons.person_add),
            label: const Text('Create new customer'),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppConstants.customerFormRoute),
          ),
        ],
      ),
    );
  }

  Widget _buildHint({
    required IconData icon,
    required String text,
    bool showSpinner = false,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: AppConfig.spacing12),
          Text(
            text,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (showSpinner) ...[
            const SizedBox(height: AppConfig.spacing16),
            const CircularProgressIndicator(),
          ],
        ],
      ),
    );
  }

  // ── bottom bar (commit button) ────────────────────────────────────────────

  Widget? _buildBottomBar() {
    if (_controller.phase != CreatorPhase.reviewing) return null;
    final count = _controller.draft.orders.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing12),
        child: FilledButton.icon(
          icon: const Icon(Icons.check),
          label: Text(count == 1 ? 'Create 1 order' : 'Create $count orders'),
          onPressed: _controller.canCommit ? _commit : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
      ),
    );
  }

  // ── actions ───────────────────────────────────────────────────────────────

  Future<void> _recordInitialDump() async {
    final result = await StreamingVoiceBottomSheet.show(context);
    if (!mounted) return;
    if (result == null || result.text.trim().isEmpty) return;
    await _controller.submitVoiceDump(
      transcript: result.text,
      audioPath: result.audioWavPath,
    );
  }


  /// Triggered when the refinement bar's mic button is tapped. Pops the
  /// shared voice bottom sheet (same one the initial dump uses), then
  /// resolves the result with the smart-Done-on-empty rule:
  ///   - empty text field → send transcript straight to the agent
  ///   - non-empty text field → append, let the tailor review and tap Send
  Future<void> _recordFeedbackViaSheet() async {
    final result = await StreamingVoiceBottomSheet.show(context);
    if (!mounted) return;
    if (result == null) return;
    final captured = result.text.trim();
    if (captured.isEmpty) return;

    if (_feedbackCtrl.text.trim().isEmpty) {
      _controller.submitFeedback(captured);
    } else {
      _feedbackCtrl.text = '${_feedbackCtrl.text.trim()} $captured';
      _feedbackCtrl.selection =
          TextSelection.collapsed(offset: _feedbackCtrl.text.length);
    }
  }

  /// Send handler for the refinement bar's text mode (also triggered via the
  /// keyboard's Send action). Trims, clears the field, and forwards to the
  /// agent.
  void _submitFeedback(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _feedbackCtrl.clear();
    _controller.submitFeedback(trimmed);
  }

  Future<void> _commit() async {
    await _controller.commit();
  }

  void _openManualForm() {
    Navigator.of(context).pushReplacementNamed(
      AppConstants.orderFormRoute,
      arguments: {
        'customer': _controller.customer,
        if (_controller.transcript != null)
          'initialDescription': _controller.transcript,
      },
    );
  }
}

// ── helper widgets ──────────────────────────────────────────────────────────

class _CustomerPickerRow extends StatelessWidget {
  final OrderCreatorController controller;

  const _CustomerPickerRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerState>(
      builder: (context, customerState, _) {
        return CustomerAutocompleteField(
          customers: customerState.customers,
          selectedCustomer: controller.customer,
          enabled: !controller.isAgentBusy,
          autofocus: true,
          onCustomerSelected: (customer) => _onCustomerChosen(context, customer),
          onCustomerCleared: () {},
          onCreateNewCustomer: () =>
              Navigator.of(context).pushNamed(AppConstants.customerFormRoute),
        );
      },
    );
  }

  Future<void> _onCustomerChosen(BuildContext context, Customer chosen) async {
    final previous = controller.customer;
    if (previous == null || previous.id == chosen.id) {
      controller.selectCustomer(chosen);
      return;
    }
    if (!controller.hasUnsavedWork) {
      controller.selectCustomer(chosen);
      return;
    }
    final confirm = await ConfirmationDialog.show(
      context: context,
      title: 'Switch customer?',
      content:
          'Switching will clear the current draft. Are you sure you want to switch to ${chosen.name}?',
    );
    if (!confirm) return;
    controller.resetForNewCustomer(chosen);
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _CommentaryBanner extends StatelessWidget {
  final String text;
  const _CommentaryBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome, color: cs.onPrimaryContainer),
            const SizedBox(width: AppConfig.spacing8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranscriptPreview extends StatefulWidget {
  final String text;
  const _TranscriptPreview({required this.text});

  @override
  State<_TranscriptPreview> createState() => _TranscriptPreviewState();
}

class _TranscriptPreviewState extends State<_TranscriptPreview> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppConfig.spacing12),
              child: Row(
                children: [
                  Icon(Icons.subject, color: theme.colorScheme.primary),
                  const SizedBox(width: AppConfig.spacing8),
                  Expanded(
                    child: Text('Voice transcript',
                        style: theme.textTheme.titleSmall),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppConfig.spacing12),
              child: Text(
                widget.text,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
