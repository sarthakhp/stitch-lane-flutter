import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../backend/models/customer.dart';
import '../../../backend/models/measurement.dart';
import '../../../backend/models/order.dart';
import '../../../backend/repositories/measurement_repository.dart';
import '../../../backend/repositories/order_repository.dart';
import '../../../utils/app_logger.dart';
import '../../models/order_proposal.dart';
import '../../state/measurement_state.dart';
import '../../state/order_state.dart';
import '../measurement_service.dart';
import '../order_service.dart';
import 'order_creator_agent.dart';

/// Phase of the order-creator session, drives the screen body.
enum CreatorPhase {
  pickingCustomer,
  ready,         // customer selected, awaiting voice dump
  transcribing,  // STT in progress (set by the screen before kicking off agent)
  agentRunning,  // Gemini tool-call loop in flight
  reviewing,     // draft is non-empty, awaiting confirm/edit/feedback
  committing,    // batch save in flight
  done,
  error,
}

/// Owns the lifecycle of one "create orders for a customer" session.
///
/// All screen state is reactive on this controller; widgets are dumb shells
/// that read these getters and call the action methods.
class OrderCreatorController extends ChangeNotifier {
  final OrderState orderState;
  final OrderRepository orderRepository;
  final MeasurementState measurementState;
  final MeasurementRepository measurementRepository;
  final OrderCreatorAgent agent;

  OrderCreatorController({
    required this.orderState,
    required this.orderRepository,
    required this.measurementState,
    required this.measurementRepository,
    OrderCreatorAgent? agent,
  }) : agent = agent ?? OrderCreatorAgent();

  // ── state ────────────────────────────────────────────────────────────────

  CreatorPhase _phase = CreatorPhase.pickingCustomer;
  Customer? _customer;
  String? _audioPath;
  String? _transcript;
  OrderProposalDraft _draft = OrderProposalDraft.empty;
  final List<AgentLogEntry> _log = [];
  String? _agentCommentary;
  String? _errorMessage;
  List<Order>? _savedOrders;
  Measurement? _savedMeasurement;

  CreatorPhase get phase => _phase;
  Customer? get customer => _customer;
  String? get audioPath => _audioPath;
  String? get transcript => _transcript;
  OrderProposalDraft get draft => _draft;
  List<AgentLogEntry> get log => List.unmodifiable(_log);
  String? get agentCommentary => _agentCommentary;
  String? get errorMessage => _errorMessage;
  List<Order>? get savedOrders => _savedOrders;
  Measurement? get savedMeasurement => _savedMeasurement;

  bool get isAgentBusy =>
      _phase == CreatorPhase.transcribing ||
      _phase == CreatorPhase.agentRunning ||
      _phase == CreatorPhase.committing;

  bool get canCommit =>
      _phase == CreatorPhase.reviewing && _draft.orders.isNotEmpty;

  bool get hasUnsavedWork =>
      _draft.orders.isNotEmpty || _draft.measurements.isNotEmpty;

  // ── customer ─────────────────────────────────────────────────────────────

  void selectCustomer(Customer customer) {
    if (_customer?.id == customer.id) return;
    _customer = customer;
    if (_phase == CreatorPhase.pickingCustomer) {
      _phase = CreatorPhase.ready;
    }
    notifyListeners();
  }

  /// Reset everything tied to the previous customer. Called when the tailor
  /// switches customer mid-session.
  void resetForNewCustomer(Customer customer) {
    _customer = customer;
    _audioPath = null;
    _transcript = null;
    _draft = OrderProposalDraft.empty;
    _log.clear();
    _agentCommentary = null;
    _errorMessage = null;
    _savedOrders = null;
    _savedMeasurement = null;
    _phase = CreatorPhase.ready;
    notifyListeners();
  }

  /// Go back to the customer-picking step, clearing any in-progress draft.
  /// Used by the "Change customer" action.
  void changeCustomer() {
    _customer = null;
    _audioPath = null;
    _transcript = null;
    _draft = OrderProposalDraft.empty;
    _log.clear();
    _agentCommentary = null;
    _errorMessage = null;
    _savedOrders = null;
    _savedMeasurement = null;
    _phase = CreatorPhase.pickingCustomer;
    notifyListeners();
  }

  // ── voice dump ───────────────────────────────────────────────────────────

  /// Tailor finished recording. Stores audio path + transcript, kicks off
  /// the initial agent turn.
  Future<void> submitVoiceDump({
    required String transcript,
    String? audioPath,
  }) async {
    if (_customer == null) {
      _setError('Pick a customer first.');
      return;
    }
    final cleaned = transcript.trim();
    if (cleaned.isEmpty) {
      _setError('No transcript captured. Try recording again.');
      return;
    }
    _audioPath = audioPath;
    _transcript = cleaned;
    _errorMessage = null;
    await _runAgent(transcript: cleaned, feedback: '');
  }

  /// Tailor refining the draft via text/voice feedback after the initial
  /// proposal landed.
  Future<void> submitFeedback(String feedback) async {
    if (_customer == null) return;
    final cleaned = feedback.trim();
    if (cleaned.isEmpty) return;
    await _runAgent(transcript: '', feedback: cleaned);
  }

  Future<void> _runAgent({required String transcript, required String feedback}) async {
    final customer = _customer;
    if (customer == null) return;

    _phase = CreatorPhase.agentRunning;
    _agentCommentary = null;
    _errorMessage = null;
    _log.add(AgentLogEntry(
      kind: AgentLogKind.info,
      label: feedback.isEmpty ? 'Agent thinking…' : 'Refining draft…',
    ));
    notifyListeners();

    final result = await agent.run(
      customer: customer,
      draft: _draft,
      transcript: transcript,
      feedback: feedback,
      onLog: _appendLog,
    );

    _draft = result.draft;
    _agentCommentary = result.commentary;

    if (result.failed) {
      _phase = CreatorPhase.error;
      _errorMessage = result.errorMessage;
    } else {
      _phase = _draft.isEmpty ? CreatorPhase.error : CreatorPhase.reviewing;
      if (_draft.isEmpty) {
        _errorMessage =
            "I couldn't identify any orders from that. Try recording again or use the manual form.";
      }
    }
    notifyListeners();
  }

  void _appendLog(AgentLogEntry entry) {
    _log.add(entry);
    notifyListeners();
  }

  // ── manual edits on the draft (no AI call) ───────────────────────────────

  void editOrder(
    String id, {
    String? title,
    int? value,
    bool clearValue = false,
    DateTime? dueDate,
    String? description,
    bool clearDescription = false,
    List<String>? imagePaths,
  }) {
    final index = _draft.orders.indexWhere((o) => o.id == id);
    if (index == -1) return;
    final updated = _draft.orders[index].copyWith(
      title: title,
      value: value,
      clearValue: clearValue,
      dueDate: dueDate,
      description: description,
      clearDescription: clearDescription,
      imagePaths: imagePaths,
    );
    final list = [..._draft.orders];
    list[index] = updated;
    _draft = _draft.copyWith(orders: list);
    notifyListeners();
  }

  void removeOrder(String id) {
    final list = _draft.orders.where((o) => o.id != id).toList();
    if (list.length == _draft.orders.length) return;
    _draft = _draft.copyWith(orders: list);
    if (_draft.isEmpty) {
      _phase = CreatorPhase.ready;
    }
    notifyListeners();
  }

  void addBlankOrder() {
    final defaultDue = DateTime.now().add(const Duration(days: 7));
    final order = ProposedOrder(
      id: ProposedOrder.generateId(),
      title: null,
      value: null, // price not decided until the tailor sets it
      dueDate: DateTime(defaultDue.year, defaultDue.month, defaultDue.day),
      description: null,
    );
    _draft = _draft.copyWith(orders: [..._draft.orders, order]);
    if (_phase == CreatorPhase.ready) _phase = CreatorPhase.reviewing;
    notifyListeners();
  }

  void editMeasurement(String id, {required String description}) {
    final index = _draft.measurements.indexWhere((m) => m.id == id);
    if (index == -1) return;
    final updated =
        _draft.measurements[index].copyWith(description: description);
    final list = [..._draft.measurements];
    list[index] = updated;
    _draft = _draft.copyWith(measurements: list);
    notifyListeners();
  }

  void removeMeasurement(String id) {
    final list = _draft.measurements.where((m) => m.id != id).toList();
    if (list.length == _draft.measurements.length) return;
    _draft = _draft.copyWith(measurements: list);
    notifyListeners();
  }

  void addBlankMeasurement() {
    final m = ProposedMeasurement(
      id: ProposedMeasurement.generateId(),
      description: '',
    );
    _draft = _draft.copyWith(measurements: [..._draft.measurements, m]);
    if (_phase == CreatorPhase.ready) _phase = CreatorPhase.reviewing;
    notifyListeners();
  }

  // ── commit ───────────────────────────────────────────────────────────────

  /// Persist the draft. Orders become real Orders; the (at most one)
  /// measurement becomes a Measurement carrying the original audio path.
  /// Returns true on success.
  Future<bool> commit() async {
    final customer = _customer;
    if (customer == null) return false;
    if (_draft.orders.isEmpty) return false;

    _phase = CreatorPhase.committing;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final ordersToSave = _draft.orders.map((p) {
        return Order(
          id: const Uuid().v4(),
          customerId: customer.id,
          title: p.title?.trim().isNotEmpty == true ? p.title : null,
          description: p.description?.trim().isNotEmpty == true ? p.description : null,
          dueDate: p.dueDate,
          created: now,
          value: (p.value != null && p.value! < 0) ? 0 : p.value,
          imagePaths: p.imagePaths,
        );
      }).toList();

      final savedOrders = await OrderService.addOrders(
        orderState,
        orderRepository,
        ordersToSave,
      );

      Measurement? savedMeasurement;
      if (_draft.measurements.isNotEmpty) {
        // The model is prompted to consolidate everything into ONE
        // measurement record. If multiple slipped through, concatenate so we
        // never lose data.
        final body = _draft.measurements
            .map((m) => m.description.trim())
            .where((b) => b.isNotEmpty)
            .join('\n\n');
        if (body.isNotEmpty) {
          savedMeasurement = Measurement(
            id: const Uuid().v4(),
            customerId: customer.id,
            description: body,
            created: now,
            modified: now,
            audioFilePath: _audioPath,
          );
          await MeasurementService.addMeasurement(
            measurementState,
            measurementRepository,
            savedMeasurement,
          );
        }
      }

      _savedOrders = savedOrders;
      _savedMeasurement = savedMeasurement;
      _phase = CreatorPhase.done;
      notifyListeners();
      return true;
    } catch (e, st) {
      AppLogger.error('OrderCreatorController: commit failed', e, st);
      _errorMessage = 'Failed to save: $e';
      _phase = CreatorPhase.error;
      notifyListeners();
      return false;
    }
  }

  // ── error / reset ────────────────────────────────────────────────────────

  void _setError(String message) {
    _errorMessage = message;
    _phase = CreatorPhase.error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_phase == CreatorPhase.error) {
      _phase = _draft.isEmpty
          ? (_customer == null
              ? CreatorPhase.pickingCustomer
              : CreatorPhase.ready)
          : CreatorPhase.reviewing;
    }
    notifyListeners();
  }
}
