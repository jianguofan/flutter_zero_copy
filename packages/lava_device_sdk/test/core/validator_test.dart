import 'package:lava_device_sdk/src/core/field_definition.dart';
import 'package:lava_device_sdk/src/core/validator.dart';
import 'package:test/test.dart';

FieldDefinition field(String key, FieldType type, {dynamic min, dynamic max, List<String>? enumValues}) {
  return FieldDefinition(
    key: key,
    type: type,
    defaultValue: null,
    min: min as num?,
    max: max as num?,
    enumValues: enumValues,
  );
}

void main() {
  group('Validator type checking', () {
    test('string accepts string', () {
      expect(Validator.validate(field('x', FieldType.string), 'hello'), isNull);
    });

    test('string rejects number', () {
      final err = Validator.validate(field('x', FieldType.string), 123);
      expect(err, isNotNull);
      expect(err!.message, contains('Expected string'));
    });

    test('number accepts int', () {
      expect(Validator.validate(field('x', FieldType.number), 42), isNull);
    });

    test('number accepts double', () {
      expect(Validator.validate(field('x', FieldType.number), 3.14), isNull);
    });

    test('number rejects string', () {
      final err = Validator.validate(field('x', FieldType.number), 'not_a_number');
      expect(err, isNotNull);
      expect(err!.message, contains('Expected number'));
    });

    test('boolean accepts bool', () {
      expect(Validator.validate(field('x', FieldType.boolean), true), isNull);
      expect(Validator.validate(field('x', FieldType.boolean), false), isNull);
    });

    test('boolean rejects int', () {
      final err = Validator.validate(field('x', FieldType.boolean), 1);
      expect(err, isNotNull);
      expect(err!.message, contains('Expected boolean'));
    });

    test('array accepts list', () {
      expect(Validator.validate(field('x', FieldType.array), [1, 2, 3]), isNull);
    });

    test('array rejects string', () {
      final err = Validator.validate(field('x', FieldType.array), 'not_a_list');
      expect(err, isNotNull);
    });

    test('object accepts map', () {
      expect(Validator.validate(field('x', FieldType.object), {'a': 1}), isNull);
    });

    test('object rejects list', () {
      final err = Validator.validate(field('x', FieldType.object), [1, 2]);
      expect(err, isNotNull);
    });

    test('enum accepts listed value', () {
      expect(
        Validator.validate(
          field('x', FieldType.enum_, enumValues: ['a', 'b', 'c']),
          'a',
        ),
        isNull,
      );
    });

    test('enum rejects unlisted value', () {
      final err = Validator.validate(
        field('x', FieldType.enum_, enumValues: ['a', 'b', 'c']),
        'z',
      );
      expect(err, isNotNull);
      expect(err!.message, contains('not in allowed values'));
    });

    test('null passes through any type', () {
      expect(Validator.validate(field('x', FieldType.number), null), isNull);
      expect(Validator.validate(field('x', FieldType.string), null), isNull);
    });
  });

  group('Validator range checking', () {
    test('value within range passes', () {
      expect(
        Validator.validate(field('x', FieldType.number, min: 0, max: 100), 50),
        isNull,
      );
    });

    test('value below min fails', () {
      final err = Validator.validate(field('x', FieldType.number, min: 0), -1);
      expect(err, isNotNull);
      expect(err!.message, contains('below minimum'));
    });

    test('value above max fails', () {
      final err = Validator.validate(field('x', FieldType.number, max: 100), 101);
      expect(err, isNotNull);
      expect(err!.message, contains('above maximum'));
    });

    test('value at boundary passes', () {
      expect(
        Validator.validate(field('x', FieldType.number, min: 0, max: 100), 0),
        isNull,
      );
      expect(
        Validator.validate(field('x', FieldType.number, min: 0, max: 100), 100),
        isNull,
      );
    });

    test('negative values validated correctly', () {
      expect(
        Validator.validate(field('x', FieldType.number, min: -50, max: 50), -49),
        isNull,
      );
      final err = Validator.validate(field('x', FieldType.number, min: -50, max: 50), -51);
      expect(err, isNotNull);
      expect(err!.message, contains('below minimum'));
    });
  });
}
