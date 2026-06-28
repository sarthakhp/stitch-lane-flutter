enum DocChangeKind { added, modified, removed }

class DocChange {
  final DocChangeKind kind;
  final String id;

  /// Populated for [DocChangeKind.added] and [DocChangeKind.modified].
  /// Null only for [DocChangeKind.removed].
  final Map<String, dynamic>? data;

  const DocChange({required this.kind, required this.id, this.data});
}
