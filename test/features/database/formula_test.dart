import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/database/domain/formula/formula.dart';

void main() {
  group('formula evaluator', () {
    final row = <String, Object?>{
      'arr': '420000',
      'stage': 'pilot',
      'seats': 96,
      'active': 'true',
      'name': 'Northwind',
      'health': '',
    };

    test('numeric arithmetic with prop()', () {
      expect(evaluateFormula('prop("arr") / 12', row), closeTo(35000, 0.01));
      expect(evaluateFormula('prop("seats") * 2 + 4', row), equals(196));
    });

    test('bare identifier reads row value', () {
      expect(evaluateFormula('seats + 1', row), equals(97));
    });

    test('string concatenation with +', () {
      expect(evaluateFormula('"Hello, " + name', row), equals('Hello, Northwind'));
    });

    test('comparisons', () {
      expect(evaluateFormula('arr > 100000', row), isTrue);
      expect(evaluateFormula('stage == "pilot"', row), isTrue);
      expect(evaluateFormula('stage != "won"', row), isTrue);
    });

    test('boolean logic', () {
      expect(evaluateFormula('arr > 100 && active == true', row), isTrue);
      expect(evaluateFormula('!(arr > 100)', row), isFalse);
    });

    test('if() conditional', () {
      expect(
        evaluateFormula('if(arr > 100000, "big", "small")', row),
        equals('big'),
      );
      expect(
        evaluateFormula('if(stage == "won", 1, 0)', row),
        equals(0),
      );
    });

    test('string helpers', () {
      expect(evaluateFormula('upper(name)', row), equals('NORTHWIND'));
      expect(evaluateFormula('lower("HI")', row), equals('hi'));
      expect(evaluateFormula('length(name)', row), equals(9));
      expect(evaluateFormula('contains(name, "wind")', row), isTrue);
    });

    test('number helpers', () {
      expect(evaluateFormula('round(3.7)', row), equals(4));
      expect(evaluateFormula('floor(3.7)', row), equals(3));
      expect(evaluateFormula('ceil(3.2)', row), equals(4));
      expect(evaluateFormula('abs(-5)', row), equals(5));
      expect(evaluateFormula('min(3, 5)', row), equals(3));
      expect(evaluateFormula('max(3, 5)', row), equals(5));
    });

    test('format(n, pattern)', () {
      expect(evaluateFormula('format(3.1456, "0.00")', row), equals('3.15'));
      expect(evaluateFormula('format(3, "0")', row), equals('3'));
    });

    test('today() returns ISO date', () {
      final v = evaluateFormula('today()', row);
      expect(v, isA<String>());
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch('$v'), isTrue);
    });

    test('division by zero returns FormulaError', () {
      final v = evaluateFormula('arr / 0', row);
      expect(v, isA<FormulaError>());
      expect('$v', contains('division by zero'));
    });

    test('unknown identifier reads as null and arithmetic returns 0', () {
      expect(evaluateFormula('prop("nope") + 0', row), equals(0));
    });

    test('parse error → FormulaError', () {
      final v = evaluateFormula('prop("name"', row);
      expect(v, isA<FormulaError>());
    });

    test('operator precedence', () {
      expect(evaluateFormula('2 + 3 * 4', row), equals(14));
      expect(evaluateFormula('(2 + 3) * 4', row), equals(20));
    });

    test('empty cell coerces null', () {
      expect(evaluateFormula('health == empty', row), isTrue);
    });
  });
}
