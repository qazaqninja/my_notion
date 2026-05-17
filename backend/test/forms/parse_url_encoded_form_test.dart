import 'package:backend/forms/routes.dart';
import 'package:test/test.dart';

/// M1483 — direct unit tests for the form-urlencoded body parser
/// extracted from `routes.dart`. The repeated-key join is the
/// wire-format contract that M1482's `FormFieldType.multi` relies
/// on; orchestrator's TS-01 gate at M1482 flagged that the join
/// wasn't covered by a dedicated test. This file fills that gap.
void main() {
  group('parseUrlEncodedForm', () {
    group('single-key happy path', () {
      test('a single key=value pair surfaces as one map entry', () {
        expect(parseUrlEncodedForm('name=alice'), {'name': 'alice'});
      });

      test('multiple distinct keys each surface independently', () {
        expect(
            parseUrlEncodedForm('name=alice&email=a%40example.com'),
            {'name': 'alice', 'email': 'a@example.com'});
      });

      test('empty body produces an empty map', () {
        expect(parseUrlEncodedForm(''), <String, String>{});
      });
    });

    group('repeated-key join (M1482 multi-select contract)', () {
      test('two repeats of the same key join with `,`', () {
        expect(parseUrlEncodedForm('tag=a&tag=b'), {'tag': 'a,b'});
      });

      test('three repeats join in submission order', () {
        expect(parseUrlEncodedForm('tag=a&tag=b&tag=c'),
            {'tag': 'a,b,c'});
      });

      test('mixed single + repeated keys keep their own join state',
          () {
        expect(
            parseUrlEncodedForm('name=alice&tag=a&tag=b'),
            {'name': 'alice', 'tag': 'a,b'});
      });

      test('values are decoded before joining', () {
        // a%20space + a%2Ccomma → "a space" + "a,comma"
        // Joined that becomes "a space,a,comma". Acceptable here:
        // the comma inside the second value can collide with the
        // join delimiter, which is a known limitation documented
        // at the schema layer (callers should not allow commas in
        // multi-select option labels).
        expect(parseUrlEncodedForm('tag=a%20b&tag=c'),
            {'tag': 'a b,c'});
      });
    });

    group('malformed input', () {
      test('pair without `=` is skipped', () {
        expect(parseUrlEncodedForm('alone&name=alice'),
            {'name': 'alice'});
      });

      test('empty key is skipped', () {
        expect(parseUrlEncodedForm('=value&name=alice'),
            {'name': 'alice'});
      });

      test('bad percent-encoding skips that pair, others continue',
          () {
        // `%ZZ` is not valid hex; the pair is dropped without
        // throwing.
        expect(parseUrlEncodedForm('bad=%ZZ&name=alice'),
            {'name': 'alice'});
      });
    });
  });
}
