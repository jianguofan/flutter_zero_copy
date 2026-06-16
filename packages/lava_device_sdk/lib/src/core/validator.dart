import 'package:lava_device_sdk/src/core/field_definition.dart';

class ValidationError {
  final String key;
  final String message;

  const ValidationError(this.key, this.message);

  @override
  String toString() => 'ValidationError($key: $message)';
}

class Validator {
  /// Validate a value against its field definition.
  /// Returns null if valid, or a ValidationError if invalid.
  static ValidationError? validate(FieldDefinition field, dynamic value) {
    if (value == null) {
      return null; // nulls pass through (use "required" for mandatory)
    }

    switch (field.type) {
      case FieldType.string:
        if (value is! String) {
          return ValidationError(field.key, 'Expected string, got ${value.runtimeType}');
        }
        break;
      case FieldType.number:
        if (value is! num) {
          return ValidationError(field.key, 'Expected number, got ${value.runtimeType}');
        }
        final numVal = value;
        if (field.min != null && numVal < field.min!) {
          return ValidationError(field.key, 'Value $numVal is below minimum ${field.min}');
        }
        if (field.max != null && numVal > field.max!) {
          return ValidationError(field.key, 'Value $numVal is above maximum ${field.max}');
        }
        break;
      case FieldType.boolean:
        if (value is! bool) {
          return ValidationError(field.key, 'Expected boolean, got ${value.runtimeType}');
        }
        break;
      case FieldType.array:
        if (value is! List) {
          return ValidationError(field.key, 'Expected array, got ${value.runtimeType}');
        }
        break;
      case FieldType.object:
        if (value is! Map) {
          return ValidationError(field.key, 'Expected object, got ${value.runtimeType}');
        }
        break;
      case FieldType.enum_:
        if (field.enumValues != null && !field.enumValues!.contains(value.toString())) {
          return ValidationError(
            field.key,
            'Value "$value" not in allowed values: ${field.enumValues!.join(", ")}',
          );
        }
        break;
    }

    return null;
  }
}
