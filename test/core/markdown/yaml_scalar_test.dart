import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/markdown/yaml_scalar.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('yamlSafeScalar', () {
    test('returns plain scalars unchanged', () {
      expect(yamlSafeScalar('foo'), equals('foo'));
      expect(yamlSafeScalar('hello world'), equals('hello world'));
      expect(yamlSafeScalar('1234'), equals('1234'));
      expect(yamlSafeScalar('with-dashes_and.dots'),
          equals('with-dashes_and.dots'));
    });

    test('empty stays empty (no surrounding quotes)', () {
      expect(yamlSafeScalar(''), equals(''));
    });

    test('quotes colon', () {
      expect(yamlSafeScalar('foo: bar'), equals('"foo: bar"'));
    });

    test('quotes hash', () {
      expect(yamlSafeScalar('important #1'), equals('"important #1"'));
    });

    test('quotes leading and trailing whitespace', () {
      expect(yamlSafeScalar(' leading'), equals('" leading"'));
      expect(yamlSafeScalar('trailing '), equals('"trailing "'));
    });

    test('escapes embedded double quotes', () {
      expect(yamlSafeScalar('she said "hi"'),
          equals(r'"she said \"hi\""'));
    });

    test('escapes embedded backslashes', () {
      expect(yamlSafeScalar(r'C:\path: notes'),
          equals(r'"C:\\path: notes"'));
    });

    test('round-trips through package:yaml back to the input', () {
      for (final original in [
        'plain',
        'foo: bar',
        '#tag',
        'with "quotes"',
        r'win\path',
        '  padded  ',
        '[draft]',
        'pipe | separated',
      ]) {
        final emitted = 'value: ${yamlSafeScalar(original)}';
        final parsed = loadYaml(emitted) as YamlMap;
        expect(parsed['value'], equals(original),
            reason: 'round-trip failed for "$original"');
      }
    });
  });

  group('yamlFlowItem', () {
    test('plain word unchanged', () {
      expect(yamlFlowItem('tag'), equals('tag'));
    });

    test('empty string becomes ""', () {
      expect(yamlFlowItem(''), equals('""'));
    });

    test('quotes comma so flow list doesn\'t split', () {
      expect(yamlFlowItem('high, priority'), equals('"high, priority"'));
    });

    test('quotes brackets', () {
      expect(yamlFlowItem('[draft]'), equals('"[draft]"'));
    });

    test('round-trips through a YAML flow list', () {
      const inputs = [
        'plain',
        'with: colon',
        'with,comma',
        '#hash',
        '[brackets]',
        'has "quotes"',
      ];
      final emitted =
          'tags: [${inputs.map(yamlFlowItem).join(', ')}]';
      final parsed = loadYaml(emitted) as YamlMap;
      final tags = (parsed['tags'] as YamlList).map((e) => '$e').toList();
      expect(tags, equals(inputs));
    });
  });
}
