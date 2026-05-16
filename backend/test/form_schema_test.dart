import 'package:backend/forms/form_schema.dart';
import 'package:test/test.dart';

void main() {
  group('parseFormSchema (F4)', () {
    test('no columns: block → empty schema', () {
      final s = parseFormSchema('id: x\ntitle: Customers\n');
      expect(s.fields, isEmpty);
    });

    test('basic text + number + required fields', () {
      const yaml = '''
id: cust
title: Customers
columns:
  - name: email
    type: text
    required: true
  - name: age
    type: number
''';
      final s = parseFormSchema(yaml);
      expect(s.fields.length, 2);
      expect(s.fields[0].name, 'email');
      expect(s.fields[0].type, FormFieldType.text);
      expect(s.fields[0].required, isTrue);
      expect(s.fields[1].name, 'age');
      expect(s.fields[1].type, FormFieldType.number);
      expect(s.fields[1].required, isFalse);
    });

    test('checkbox + select with inline-flow options', () {
      const yaml = '''
columns:
  - name: subscribed
    type: checkbox
  - name: plan
    type: select
    options: [free, "pro", enterprise]
''';
      final s = parseFormSchema(yaml);
      expect(s.fields[0].type, FormFieldType.checkbox);
      expect(s.fields[1].type, FormFieldType.select);
      expect(s.fields[1].options, ['free', 'pro', 'enterprise']);
    });

    test('type synonyms map to canonical types', () {
      const yaml = '''
columns:
  - name: a
    type: integer
  - name: b
    type: bool
  - name: c
    type: enum
''';
      final s = parseFormSchema(yaml);
      expect(s.fields[0].type, FormFieldType.number);
      expect(s.fields[1].type, FormFieldType.checkbox);
      expect(s.fields[2].type, FormFieldType.select);
    });

    test('unknown type defaults to text', () {
      const yaml = '''
columns:
  - name: x
    type: rocket-fuel
''';
      final s = parseFormSchema(yaml);
      expect(s.fields[0].type, FormFieldType.text);
    });

    test('quoted names + values are unwrapped', () {
      const yaml = '''
columns:
  - name: "first name"
    type: "text"
    required: "true"
''';
      final s = parseFormSchema(yaml);
      expect(s.fields[0].name, 'first name');
      expect(s.fields[0].required, isTrue);
    });

    test('top-level key after columns terminates the block', () {
      const yaml = '''
columns:
  - name: email
    type: text
title: Customers
''';
      final s = parseFormSchema(yaml);
      expect(s.fields.length, 1);
      expect(s.fields[0].name, 'email');
    });
  });

  group('validateSubmission (F4)', () {
    FormSchema schema(List<FormFieldDef> fields) =>
        FormSchema(fields: fields);

    test('Empty schema returns the raw map untouched (legacy fallback)',
        () {
      final r = validateSubmission(
        FormSchema.empty,
        const {'a': '1', 'b': 'two'},
      );
      expect(r.isValid, isTrue);
      expect(r.normalized, {'a': '1', 'b': 'two'});
    });

    test('Required field missing → errors[name]=required', () {
      final r = validateSubmission(
        schema([
          const FormFieldDef(
              name: 'email', type: FormFieldType.text, required: true),
        ]),
        const {},
      );
      expect(r.isValid, isFalse);
      expect(r.errors, {'email': 'required'});
    });

    test('Optional field missing is fine + omitted from normalized', () {
      final r = validateSubmission(
        schema([
          const FormFieldDef(name: 'note', type: FormFieldType.text),
        ]),
        const {},
      );
      expect(r.isValid, isTrue);
      expect(r.normalized, isEmpty);
    });

    test('Number coerces "42" → 42', () {
      final r = validateSubmission(
        schema([
          const FormFieldDef(name: 'age', type: FormFieldType.number),
        ]),
        const {'age': '42'},
      );
      expect(r.isValid, isTrue);
      expect(r.normalized['age'], 42);
    });

    test('Number rejects non-numeric input', () {
      final r = validateSubmission(
        schema([
          const FormFieldDef(name: 'age', type: FormFieldType.number),
        ]),
        const {'age': 'forty-two'},
      );
      expect(r.isValid, isFalse);
      expect(r.errors, {'age': 'expected_number'});
    });

    test('Checkbox accepts truthy + falsy variants', () {
      final s = schema([
        const FormFieldDef(name: 'a', type: FormFieldType.checkbox),
      ]);
      for (final t in ['true', 'on', 'yes', '1']) {
        expect(validateSubmission(s, {'a': t}).normalized['a'], isTrue);
      }
      for (final f in ['false', 'off', 'no', '0']) {
        expect(validateSubmission(s, {'a': f}).normalized['a'], isFalse);
      }
    });

    test('Checkbox rejects garbage', () {
      final r = validateSubmission(
        schema([
          const FormFieldDef(name: 'a', type: FormFieldType.checkbox),
        ]),
        const {'a': 'maybe'},
      );
      expect(r.errors, {'a': 'expected_checkbox'});
    });

    test('Select rejects values not in options list', () {
      final r = validateSubmission(
        schema([
          const FormFieldDef(
            name: 'plan',
            type: FormFieldType.select,
            options: ['free', 'pro'],
          ),
        ]),
        const {'plan': 'enterprise'},
      );
      expect(r.errors, {'plan': 'not_in_options'});
    });

    test('Multiple errors accumulate (one per field)', () {
      final r = validateSubmission(
        schema([
          const FormFieldDef(
              name: 'email', type: FormFieldType.text, required: true),
          const FormFieldDef(name: 'age', type: FormFieldType.number),
        ]),
        const {'age': 'NaN'},
      );
      expect(r.isValid, isFalse);
      expect(r.errors, {'email': 'required', 'age': 'expected_number'});
    });

    test('Unsubmitted fields outside the schema are ignored', () {
      // Lax handling — extra fields a visitor sneaks in just don't
      // make it into the normalized map; not an error.
      final r = validateSubmission(
        schema([
          const FormFieldDef(name: 'a', type: FormFieldType.text),
        ]),
        const {'a': 'hi', 'extra': 'unwanted'},
      );
      expect(r.isValid, isTrue);
      expect(r.normalized, {'a': 'hi'});
    });
  });
}
