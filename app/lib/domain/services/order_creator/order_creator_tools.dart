import 'package:langchain/langchain.dart';

import '../../models/order_proposal.dart';

/// Tool schemas for the order-creator agent, plus the per-invocation
/// dispatcher that applies tool calls to a mutable draft.
///
/// The agent calls these tools to ADD/UPDATE/REMOVE entries on the running
/// draft. Each call returns a small JSON payload the model can read back
/// (`{"ok": true, "id": "..."}` on success, `{"error": "..."}` on failure).
///
/// Adding a new tool = (1) declare in [specs], (2) handle in [dispatch].
class OrderCreatorTools {
  static const _addOrder = 'add_order';
  static const _updateOrder = 'update_order';
  static const _removeOrder = 'remove_order';
  static const _addMeasurement = 'add_measurement';
  static const _updateMeasurement = 'update_measurement';
  static const _removeMeasurement = 'remove_measurement';

  /// LangChain [ToolSpec]s, fed into the model's tool list at request time.
  static const List<ToolSpec> specs = [
    ToolSpec(
      name: _addOrder,
      description: 'Add a new draft order for the current customer. '
          'Returns the id of the created order.',
      inputJsonSchema: {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description':
                'Short garment label (e.g. "Blouse", "Kurti", "Pant").',
          },
          'value': {
            'type': 'integer',
            'description':
                'Price in rupees. Use 0 if the customer has not decided yet.',
          },
          'due_date': {
            'type': 'string',
            'description': 'ISO date "YYYY-MM-DD". Required.',
          },
          'description': {
            'type': 'string',
            'description':
                'Garment-specific notes (fabric, style, customization). '
                'MUST NOT contain body measurements.',
          },
        },
        'required': ['title', 'value', 'due_date'],
      },
    ),
    ToolSpec(
      name: _updateOrder,
      description: 'Patch fields on an existing draft order. Only the fields '
          'passed are changed; omit fields you want to leave alone.',
      inputJsonSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string'},
          'title': {'type': 'string'},
          'value': {'type': 'integer'},
          'due_date': {'type': 'string'},
          'description': {'type': 'string'},
        },
        'required': ['id'],
      },
    ),
    ToolSpec(
      name: _removeOrder,
      description: 'Remove a draft order by id.',
      inputJsonSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string'},
        },
        'required': ['id'],
      },
    ),
    ToolSpec(
      name: _addMeasurement,
      description: 'Add the customer\'s measurement record. Call at most '
          'once per session; use update_measurement if a record exists.',
      inputJsonSchema: {
        'type': 'object',
        'properties': {
          'description': {
            'type': 'string',
            'description':
                'Markdown body consolidating all body measurements mentioned '
                'in the dump. Use headings (e.g. "### Blouse") to separate '
                'per-garment measurements within this single record.',
          },
        },
        'required': ['description'],
      },
    ),
    ToolSpec(
      name: _updateMeasurement,
      description: 'Replace the body of an existing measurement record.',
      inputJsonSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string'},
          'description': {'type': 'string'},
        },
        'required': ['id', 'description'],
      },
    ),
    ToolSpec(
      name: _removeMeasurement,
      description: 'Remove the measurement record by id.',
      inputJsonSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string'},
        },
        'required': ['id'],
      },
    ),
  ];

  /// Names of all declared tools — used to short-circuit unknown calls in
  /// the executor without a hardcoded switch.
  static Set<String> get knownNames => specs.map((t) => t.name).toSet();

  // ── dispatcher ────────────────────────────────────────────────────────────

  OrderProposalDraft _draft;

  OrderCreatorTools({OrderProposalDraft initial = OrderProposalDraft.empty})
      : _draft = initial;

  OrderProposalDraft get draft => _draft;

  /// Run one tool call against the draft. Always returns a small JSON-shaped
  /// map (caller encodes it). Validation failures come back as
  /// `{"error": "..."}` so the model can self-correct on the next turn.
  Map<String, dynamic> dispatch(String name, Map<String, dynamic> args) {
    try {
      switch (name) {
        case _addOrder:
          return _handleAddOrder(args);
        case _updateOrder:
          return _handleUpdateOrder(args);
        case _removeOrder:
          return _handleRemoveOrder(args);
        case _addMeasurement:
          return _handleAddMeasurement(args);
        case _updateMeasurement:
          return _handleUpdateMeasurement(args);
        case _removeMeasurement:
          return _handleRemoveMeasurement(args);
      }
    } catch (e) {
      return {'error': 'Tool $name failed: $e'};
    }
    return {
      'error': 'Unknown tool "$name". Known tools: ${knownNames.join(', ')}.',
    };
  }

  // ── handlers ──────────────────────────────────────────────────────────────

  Map<String, dynamic> _handleAddOrder(Map<String, dynamic> args) {
    final title = _requireString(args, 'title');
    final value = _requireInt(args, 'value');
    final dueDate = _requireDate(args, 'due_date');
    final description = _optionalString(args, 'description');

    final order = ProposedOrder(
      id: ProposedOrder.generateId(),
      title: title,
      value: value < 0 ? 0 : value,
      dueDate: dueDate,
      description: description,
    );
    _draft = _draft.copyWith(orders: [..._draft.orders, order]);
    return {'ok': true, 'id': order.id};
  }

  Map<String, dynamic> _handleUpdateOrder(Map<String, dynamic> args) {
    final id = _requireString(args, 'id');
    final index = _draft.orders.indexWhere((o) => o.id == id);
    if (index == -1) {
      return {'error': 'No draft order with id "$id".'};
    }
    final current = _draft.orders[index];
    final updated = current.copyWith(
      title: args.containsKey('title')
          ? _optionalString(args, 'title')
          : null,
      value: args.containsKey('value') ? _requireInt(args, 'value') : null,
      dueDate:
          args.containsKey('due_date') ? _requireDate(args, 'due_date') : null,
      description: args.containsKey('description')
          ? _optionalString(args, 'description')
          : null,
      clearDescription: args.containsKey('description') &&
          _optionalString(args, 'description') == null,
    );
    final newOrders = [..._draft.orders];
    newOrders[index] = updated;
    _draft = _draft.copyWith(orders: newOrders);
    return {'ok': true, 'id': id};
  }

  Map<String, dynamic> _handleRemoveOrder(Map<String, dynamic> args) {
    final id = _requireString(args, 'id');
    final before = _draft.orders.length;
    final newOrders = _draft.orders.where((o) => o.id != id).toList();
    if (newOrders.length == before) {
      return {'error': 'No draft order with id "$id".'};
    }
    _draft = _draft.copyWith(orders: newOrders);
    return {'ok': true, 'id': id};
  }

  Map<String, dynamic> _handleAddMeasurement(Map<String, dynamic> args) {
    final description = _requireString(args, 'description');
    final measurement = ProposedMeasurement(
      id: ProposedMeasurement.generateId(),
      description: description,
    );
    _draft = _draft.copyWith(
      measurements: [..._draft.measurements, measurement],
    );
    return {'ok': true, 'id': measurement.id};
  }

  Map<String, dynamic> _handleUpdateMeasurement(Map<String, dynamic> args) {
    final id = _requireString(args, 'id');
    final description = _requireString(args, 'description');
    final index = _draft.measurements.indexWhere((m) => m.id == id);
    if (index == -1) {
      return {'error': 'No draft measurement with id "$id".'};
    }
    final updated = _draft.measurements[index].copyWith(description: description);
    final newList = [..._draft.measurements];
    newList[index] = updated;
    _draft = _draft.copyWith(measurements: newList);
    return {'ok': true, 'id': id};
  }

  Map<String, dynamic> _handleRemoveMeasurement(Map<String, dynamic> args) {
    final id = _requireString(args, 'id');
    final before = _draft.measurements.length;
    final newList = _draft.measurements.where((m) => m.id != id).toList();
    if (newList.length == before) {
      return {'error': 'No draft measurement with id "$id".'};
    }
    _draft = _draft.copyWith(measurements: newList);
    return {'ok': true, 'id': id};
  }

  // ── arg coercion ──────────────────────────────────────────────────────────

  String _requireString(Map<String, dynamic> args, String key) {
    final raw = args[key];
    if (raw is! String || raw.trim().isEmpty) {
      throw ArgumentError('Missing or empty "$key".');
    }
    return raw.trim();
  }

  String? _optionalString(Map<String, dynamic> args, String key) {
    final raw = args[key];
    if (raw == null) return null;
    if (raw is! String) return raw.toString();
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int _requireInt(Map<String, dynamic> args, String key) {
    final raw = args[key];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null) return parsed;
    }
    throw ArgumentError('"$key" must be an integer (got: $raw).');
  }

  DateTime _requireDate(Map<String, dynamic> args, String key) {
    final raw = args[key];
    if (raw is! String || raw.trim().isEmpty) {
      throw ArgumentError('"$key" must be an ISO date string (YYYY-MM-DD).');
    }
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) {
      throw ArgumentError(
          '"$key" must be a valid ISO date (got: "$raw").');
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
}
