import 'package:lava_device_sdk/src/core/field_definition.dart';
import 'package:lava_device_sdk/src/core/validator.dart';

class SchemaError {
  final String message;
  const SchemaError(this.message);
  @override
  String toString() => 'SchemaError: $message';
}

class DeviceSchema {
  final Map<String, FieldDefinition> _fields;
  final Map<String, dynamic> _rawDataSource;

  DeviceSchema._(this._fields, this._rawDataSource);

  factory DeviceSchema.fromJson(Map<String, dynamic> json) {
    final fieldsJson = json['fields'] as Map<String, dynamic>?;
    if (fieldsJson == null) {
      throw ArgumentError('Schema JSON must contain a "fields" key');
    }

    final fields = <String, FieldDefinition>{};
    for (final entry in fieldsJson.entries) {
      final key = entry.key;
      final fieldJson = entry.value as Map<String, dynamic>;
      fields[key] = FieldDefinition.fromJson(key, fieldJson);
    }

    return DeviceSchema._(fields, json['dataSource'] as Map<String, dynamic>? ?? {});
  }

  /// Look up a field definition by dotted key (e.g., "toolhead.position").
  FieldDefinition? lookup(String dottedKey) {
    return _fields[dottedKey];
  }

  /// Get all field keys that match a prefix.
  /// "print_stats.*" — matches "print_stats.state", "print_stats.filename", etc.
  /// "temp" — matches all keys starting with "temp" (e.g., "temperature")
  /// "*" — matches all fields.
  List<String> keysByPrefix(String prefix) {
    if (prefix == '*') {
      return _fields.keys.toList();
    }

    if (prefix.endsWith('.*')) {
      final category = prefix.substring(0, prefix.length - 2);
      return _fields.keys.where((k) => k.startsWith('$category.')).toList();
    }

    // Exact match
    if (_fields.containsKey(prefix)) {
      return [prefix];
    }

    // Fallback: prefix match (e.g., "temp" → "temperature", "target")
    return _fields.keys.where((k) => k.startsWith(prefix)).toList();
  }

  /// Get the raw dataSource configuration for the adapter.
  Map<String, dynamic> get dataSource => Map.unmodifiable(_rawDataSource);

  /// All field keys.
  Iterable<String> get keys => _fields.keys;

  /// All field definitions.
  Iterable<FieldDefinition> get definitions => _fields.values;

  /// Validate schema self-consistency. Returns list of errors (empty = valid).
  List<SchemaError> validate() {
    final errors = <SchemaError>[];

    for (final field in _fields.values) {
      // Check that enum fields have enum values
      if (field.type == FieldType.enum_) {
        if (field.enumValues == null || field.enumValues!.isEmpty) {
          errors.add(SchemaError(
            'Field "${field.key}" is type enum but has no enum values',
          ));
        }
      }

      // Check that min <= max
      if (field.min != null && field.max != null && field.min! > field.max!) {
        errors.add(SchemaError(
          'Field "${field.key}": min (${field.min}) > max (${field.max})',
        ));
      }

      // Check default value type matches
      final defaultVal = field.defaultValue;
      if (defaultVal != null) {
        final err = Validator.validate(field, defaultVal);
        if (err != null) {
          errors.add(SchemaError(
            'Field "${field.key}": default value "$defaultVal" fails validation: ${err.message}',
          ));
        }
      }
    }

    return errors;
  }
}
