class StatePatch {
  /// Dotted path to the changed field or category.
  final String path;

  /// Changed values, keyed by dotted path.
  final Map<String, dynamic> values;

  /// When the patch was created.
  final DateTime timestamp;

  const StatePatch({
    required this.path,
    required this.values,
    required this.timestamp,
  });

  /// Convenience: get a single value if the patch is for one field.
  dynamic get value => values.length == 1 ? values.values.first : null;

  /// Convenience: get the single key if the patch is for one field.
  String get singleKey => values.length == 1 ? values.keys.first : '';

  @override
  String toString() => 'StatePatch($path, ${values.length} fields, $timestamp)';
}
