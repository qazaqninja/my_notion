import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/text/strip_bom.dart';

void main() {
  group('stripBom', () {
    test('strips a leading U+FEFF', () {
      expect(stripBom('﻿hello'), equals('hello'));
    });

    test('only strips ONE leading marker — interior BOMs survive', () {
      // Some tooling pastes a BOM into the middle of a file; that's a
      // separate (rare) bug and we don't want to mangle the rest of the
      // string while fixing the common header case.
      expect(stripBom('﻿a﻿b'), equals('a﻿b'));
    });

    test('no-op when there is no BOM', () {
      expect(stripBom(''), equals(''));
      expect(stripBom('hello'), equals('hello'));
      expect(stripBom('﻿hello'.substring(1)),
          equals('hello'),
          reason: 'pre-stripped input should pass through unchanged');
    });

    test('handles empty string without throwing', () {
      expect(stripBom(''), equals(''));
    });

    test('CSV first-cell content survives the strip', () {
      // A bommed CSV is `﻿title,name,age\n...`. The CSV parser
      // captures `﻿title` as cell[0][0]. We want stripBom to
      // produce the clean string a downstream comparison expects.
      const bomedHeader = '﻿title';
      expect(stripBom(bomedHeader), equals('title'));
    });

    test('stripBom is idempotent', () {
      const once = '﻿foo';
      final stripped = stripBom(once);
      expect(stripBom(stripped), equals('foo'),
          reason: 'calling twice must not under-strip or over-strip');
    });
  });
}
