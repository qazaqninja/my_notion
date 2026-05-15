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

  group('yamlSnakeKey', () {
    test('lowercases + snake_cases plain labels', () {
      expect(yamlSnakeKey('Foo Bar'), equals('foo_bar'));
      expect(yamlSnakeKey('AGE'), equals('age'));
      expect(yamlSnakeKey('hello world here'), equals('hello_world_here'));
    });

    test('drops every YAML structure / quote / slash glyph', () {
      expect(yamlSnakeKey('Foo: Bar'), equals('foo_bar'));
      expect(yamlSnakeKey('#Priority'), equals('priority'));
      expect(yamlSnakeKey('Tag/Stage'), equals('tag_stage'));
      expect(yamlSnakeKey('Cool [v2]'), equals('cool_v2'));
      expect(yamlSnakeKey('a | b | c'), equals('a_b_c'));
      expect(yamlSnakeKey(r'path\name'), equals('path_name'));
    });

    test('collapses repeated underscores and trims edges', () {
      expect(yamlSnakeKey('___foo___'), equals('foo'));
      expect(yamlSnakeKey('foo___bar'), equals('foo_bar'));
      expect(yamlSnakeKey(' :foo: '), equals('foo'));
    });

    test('falls back to "col" on empty / whitespace / pure punctuation',
        () {
      expect(yamlSnakeKey(''), equals('col'));
      expect(yamlSnakeKey('   '), equals('col'));
      expect(yamlSnakeKey(':::'), equals('col'));
      expect(yamlSnakeKey('___'), equals('col'));
    });

    test('round-trips through YAML as a bare key', () {
      for (final label in ['Foo Bar', '#tag', 'a [b] c', 'X: y', '']) {
        final key = yamlSnakeKey(label);
        // Emit a mapping with the normalised key and parse it back.
        final yaml = '$key: value\n';
        final parsed = loadYaml(yaml) as YamlMap;
        expect(parsed.keys, contains(key),
            reason: 'normalised key from "$label" must parse as itself');
        expect(parsed[key], equals('value'));
      }
    });
  });
}
