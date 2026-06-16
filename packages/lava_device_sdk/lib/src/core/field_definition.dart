/// Update strategy applied when a field receives new data.
enum UpdateStrategy {
  replace,
  max,
  min,
  first,
  merge,
  append,
  increment,
}

/// The data type of a field value.
enum FieldType {
  string,
  number,
  boolean,
  array,
  object,
  enum_,
}

/// Schema definition for a single field in the state tree.
class FieldDefinition {
  final String key;
  final FieldType type;
  final dynamic defaultValue;
  final bool readonly;
  final UpdateStrategy strategy;
  final List<String>? enumValues;
  final num? min;
  final num? max;

  const FieldDefinition({
    required this.key,
    required this.type,
    required this.defaultValue,
    this.readonly = false,
    this.strategy = UpdateStrategy.replace,
    this.enumValues,
    this.min,
    this.max,
  });

  factory FieldDefinition.fromJson(String key, Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    FieldType type;
    switch (typeStr) {
      case 'string':
        type = FieldType.string;
        break;
      case 'number':
        type = FieldType.number;
        break;
      case 'boolean':
        type = FieldType.boolean;
        break;
      case 'array':
        type = FieldType.array;
        break;
      case 'object':
        type = FieldType.object;
        break;
      case 'enum':
        type = FieldType.enum_;
        break;
      default:
        throw ArgumentError('Unknown field type: $typeStr');
    }

    UpdateStrategy strategy = UpdateStrategy.replace;
    final strategyStr = json['strategy'] as String?;
    if (strategyStr != null) {
      switch (strategyStr) {
        case 'replace':
          strategy = UpdateStrategy.replace;
          break;
        case 'max':
          strategy = UpdateStrategy.max;
          break;
        case 'min':
          strategy = UpdateStrategy.min;
          break;
        case 'first':
          strategy = UpdateStrategy.first;
          break;
        case 'merge':
          strategy = UpdateStrategy.merge;
          break;
        case 'append':
          strategy = UpdateStrategy.append;
          break;
        case 'increment':
          strategy = UpdateStrategy.increment;
          break;
        default:
          throw ArgumentError('Unknown update strategy: $strategyStr');
      }
    }

    final validate = json['validate'] as Map<String, dynamic>?;

    return FieldDefinition(
      key: key,
      type: type,
      defaultValue: json['default'] ?? _defaultForType(type),
      readonly: json['readonly'] == true,
      strategy: strategy,
      enumValues: (json['enum'] as List<dynamic>?)?.cast<String>(),
      min: validate?['min'] as num?,
      max: validate?['max'] as num?,
    );
  }

  static dynamic _defaultForType(FieldType type) {
    switch (type) {
      case FieldType.string:
        return '';
      case FieldType.number:
        return 0;
      case FieldType.boolean:
        return false;
      case FieldType.array:
        return <dynamic>[];
      case FieldType.object:
        return <String, dynamic>{};
      case FieldType.enum_:
        return '';
    }
  }
}
