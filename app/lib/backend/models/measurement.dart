class Measurement {
  final String id;

  final String customerId;

  final String description;

  final DateTime created;

  final DateTime modified;

  final String? audioFilePath;

  Measurement({
    required this.id,
    required this.customerId,
    required this.description,
    required this.created,
    required this.modified,
    this.audioFilePath,
  });

  Measurement copyWith({
    String? id,
    String? customerId,
    String? description,
    DateTime? created,
    DateTime? modified,
    String? audioFilePath,
  }) {
    return Measurement(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      description: description ?? this.description,
      created: created ?? this.created,
      modified: modified ?? this.modified,
      audioFilePath: audioFilePath ?? this.audioFilePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'description': description,
      'created': created.toIso8601String(),
      'modified': modified.toIso8601String(),
      'audioFilePath': audioFilePath,
    };
  }

  factory Measurement.fromJson(Map<String, dynamic> json) {
    return Measurement(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      description: json['description'] as String,
      created: DateTime.parse(json['created'] as String),
      modified: DateTime.parse(json['modified'] as String),
      audioFilePath: json['audioFilePath'] as String?,
    );
  }

  @override
  String toString() {
    return 'Measurement(id: $id, customerId: $customerId, description: $description, created: $created, modified: $modified, audioFilePath: $audioFilePath)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Measurement && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

