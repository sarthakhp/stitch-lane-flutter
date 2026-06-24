import 'dart:convert';

/// A single measurement field in the global, flat list (e.g. "Full Bust").
///
/// Fields are garment-agnostic. The AI matches transcribed labels against
/// [label] and [aliases] (case-insensitive) and emits the canonical [label]
/// for the value; unmatched lines go to per-section notes instead.
class MeasurementField {
  final String id;
  final String label;
  final List<String> aliases;
  final int sortOrder;

  MeasurementField({
    required this.id,
    required this.label,
    this.aliases = const [],
    required this.sortOrder,
  });

  MeasurementField copyWith({
    String? id,
    String? label,
    List<String>? aliases,
    int? sortOrder,
  }) {
    return MeasurementField(
      id: id ?? this.id,
      label: label ?? this.label,
      aliases: aliases ?? this.aliases,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'aliases': aliases,
        'sortOrder': sortOrder,
      };

  factory MeasurementField.fromJson(Map<String, dynamic> json) {
    final rawAliases = json['aliases'];
    List<String> aliases;
    if (rawAliases is List) {
      aliases = rawAliases.map((e) => e.toString()).toList();
    } else if (rawAliases is String && rawAliases.isNotEmpty) {
      final decoded = jsonDecode(rawAliases);
      aliases = decoded is List ? decoded.map((e) => e.toString()).toList() : const [];
    } else {
      aliases = const [];
    }
    return MeasurementField(
      id: json['id'] as String,
      label: json['label'] as String,
      aliases: aliases,
      sortOrder: (json['sortOrder'] ?? json['sort_order']) as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MeasurementField && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
