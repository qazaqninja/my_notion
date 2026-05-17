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

  // M1479-added date support, organised under the canonical
  // parse/validate group names (per TS-04: nest by method/feature
  // under test, not by milestone tag).
  group('parseFormSchema date types', () {
    test('"date" parses to FormFieldType.date', () {
      const src = '''
columns:
  - name: due_by
    type: date
''';
      final s = parseFormSchema(src);
      expect(s.fields.single.type, FormFieldType.date);
    });

    test('"datetime" alias parses to FormFieldType.date', () {
      const src = '''
columns:
  - name: scheduled_at
    type: datetime
''';
      final s = parseFormSchema(src);
      expect(s.fields.single.type, FormFieldType.date);
    });

    test('valid ISO YYYY-MM-DD round-trips into normalized', () {
      final r = validateSubmission(
        const FormSchema(fields: [
          FormFieldDef(name: 'due_by', type: FormFieldType.date),
        ]),
        const {'due_by': '2026-05-17'},
      );
      expect(r.isValid, isTrue);
      // DateTime.parse normalises to a full ISO 8601 timestamp.
      expect(r.normalized['due_by'], startsWith('2026-05-17'));
    });

    test('valid datetime-local round-trips into normalized', () {
      final r = validateSubmission(
        const FormSchema(fields: [
          FormFieldDef(name: 'when', type: FormFieldType.date),
        ]),
        const {'when': '2026-05-17T14:30'},
      );
      expect(r.isValid, isTrue);
      expect(r.normalized['when'], startsWith('2026-05-17T14:30'));
    });

    test('garbage input surfaces expected_date error', () {
      final r = validateSubmission(
        const FormSchema(fields: [
          FormFieldDef(name: 'due_by', type: FormFieldType.date),
        ]),
        const {'due_by': 'tomorrow'},
      );
      expect(r.isValid, isFalse);
      expect(r.errors, {'due_by': 'expected_date'});
    });

    test('missing required date errors with required (not expected_date)',
        () {
      final r = validateSubmission(
        const FormSchema(fields: [
          FormFieldDef(
              name: 'due_by', type: FormFieldType.date, required: true),
        ]),
        const {},
      );
      expect(r.errors, {'due_by': 'required'});
    });

    test('missing optional date is skipped entirely', () {
      final r = validateSubmission(
        const FormSchema(fields: [
          FormFieldDef(name: 'due_by', type: FormFieldType.date),
        ]),
        const {},
      );
      expect(r.isValid, isTrue);
      expect(r.normalized, isEmpty);
    });
  });

  // M1482-added multi-select support. Same TS-04 convention as the
  // M1479 date group above.
  group('parseFormSchema multi types', () {
    test('"multi" parses to FormFieldType.multi', () {
      const src = '''
columns:
  - name: tags
    type: multi
    options: [a, b, c]
''';
      final s = parseFormSchema(src);
      expect(s.fields.single.type, FormFieldType.multi);
      expect(s.fields.single.options, ['a', 'b', 'c']);
    });

    test('"multi_select" alias parses to FormFieldType.multi', () {
      const src = '''
columns:
  - name: tags
    type: multi_select
''';
      expect(parseFormSchema(src).fields.single.type, FormFieldType.multi);
    });

    test('"multiselect" alias parses to FormFieldType.multi', () {
      const src = '''
columns:
  - name: tags
    type: multiselect
''';
      expect(parseFormSchema(src).fields.single.type, FormFieldType.multi);
    });

    test('comma-joined picks all in options → normalized to List<String>',
        () {
      final r = validateSubmission(
        const FormSchema(fields: [
          FormFieldDef(
              name: 'tags',
              type: FormFieldType.multi,
              options: ['red', 'green', 'blue']),
        ]),
        const {'tags': 'red,blue'},
      );
      expect(r.isValid, isTrue);
      expect(r.normalized['tags'], ['red', 'blue']);
    });

    test('any pick outside options surfaces not_in_options', () {
      final r = validateSubmission(
        const FormSchema(fields: [
          FormFieldDef(
              name: 'tags',
              type: FormFieldType.multi,
              options: ['red', 'green', 'blue']),
        ]),
        const {'tags': 'red,purple'},
      );
      expect(r.isValid, isFalse);
      expect(r.errors, {'tags': 'not_in_options'});
    });

    test('whitespace-padded picks are trimmed', () {
      final r = validateSubmission(
        const FormSchema(fields: [
          FormFieldDef(
              name: 'tags',
              type: FormFieldType.multi,
              options: ['red', 'green']),
        ]),
        const {'tags': '  red ,green  '},
      );
      expect(r.isValid, isTrue);
      expect(r.normalized['tags'], ['red', 'green']);
    });

    test('missing required multi errors with required', () {
      final r = validateSubmission(
        const FormSchema(fields: [
          FormFieldDef(
              name: 'tags',
              type: FormFieldType.multi,
              required: true,
              options: ['a', 'b']),
        ]),
        const {},
      );
      expect(r.errors, {'tags': 'required'});
    });

    test('missing optional multi is skipped entirely', () {
      final r = validateSubmission(
        const FormSchema(fields: [
          FormFieldDef(
              name: 'tags',
              type: FormFieldType.multi,
              options: ['a', 'b']),
        ]),
        const {},
      );
      expect(r.isValid, isTrue);
      expect(r.normalized, isEmpty);
    });

    test('single pick still normalizes to a one-element list', () {
      final r = validateSubmission(
        const FormSchema(fields: [
          FormFieldDef(
              name: 'tags',
              type: FormFieldType.multi,
              options: ['a', 'b']),
        ]),
        const {'tags': 'a'},
      );
      expect(r.isValid, isTrue);
      expect(r.normalized['tags'], ['a']);
    });
  });
}
