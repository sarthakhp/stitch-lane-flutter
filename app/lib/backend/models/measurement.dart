import 'dart:convert';

import '../util/audio_path_list.dart';

class Measurement {
  final String id;

  final String customerId;

  final String description;

  final DateTime created;

  final DateTime modified;

  /// Voice dictations linked to this measurement, in capture order. A single
  /// measurement can be built from several dictations (Top, then Blouse, then
  /// a correction), so every recording is kept rather than the last winning.
  final List<String> audioFilePaths;

  /// Parsed sections + per-field values + per-section notes. Null for
  /// pre-feature measurements (they only have [description] markdown).
  /// Shape: `{ "sections": [ { heading, values: {label: value}, notes } ] }`.
  final Map<String, dynamic>? structuredData;

  Measurement({
    required this.id,
    required this.customerId,
    required this.description,
    required this.created,
    required this.modified,
    this.audioFilePaths = const [],
    this.structuredData,
  });

  /// First linked recording, for the few spots that only need one.
  String? get primaryAudioFilePath =>
      audioFilePaths.isEmpty ? null : audioFilePaths.first;

  Measurement copyWith({
    String? id,
    String? customerId,
    String? description,
    DateTime? created,
    DateTime? modified,
    List<String>? audioFilePaths,
    Map<String, dynamic>? structuredData,
    bool clearStructuredData = false,
  }) {
    return Measurement(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      description: description ?? this.description,
      created: created ?? this.created,
      modified: modified ?? this.modified,
      audioFilePaths: audioFilePaths ?? this.audioFilePaths,
      structuredData: clearStructuredData
          ? null
          : (structuredData ?? this.structuredData),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'description': description,
      'created': created.toIso8601String(),
      'modified': modified.toIso8601String(),
      'audioFilePaths': audioFilePaths,
      'structuredData': structuredData,
    };
  }

  factory Measurement.fromJson(Map<String, dynamic> json) {
    final raw = json['structuredData'];
    Map<String, dynamic>? structured;
    if (raw is Map) {
      structured = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        structured = Map<String, dynamic>.from(decoded);
      }
    }
    return Measurement(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      description: json['description'] as String,
      created: DateTime.parse(json['created'] as String),
      modified: DateTime.parse(json['modified'] as String),
      audioFilePaths: AudioPathList.read(
        json['audioFilePaths'],
        legacySingle: json['audioFilePath'],
      ),
      structuredData: structured,
    );
  }

  @override
  String toString() {
    return 'Measurement(id: $id, customerId: $customerId, description: $description, created: $created, modified: $modified, audioFilePaths: $audioFilePaths, structuredData: $structuredData)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Measurement && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
