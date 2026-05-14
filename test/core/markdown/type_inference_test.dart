import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/markdown/type_inference.dart';
import 'package:my_notion/features/vault/domain/entities/frontmatter_entry.dart';

void main() {
  group('TypeInference.infer', () {
    test('detects ULID', () {
      expect(TypeInference.infer('01HX0V9R5N6E8L3P7Q8S9U2X4B'), FrontmatterType.ulid);
    });

    test('rejects 25-char strings as ULID', () {
      expect(TypeInference.infer('01HX0V9R5N6E8L3P7Q8S9U2X4'), FrontmatterType.text);
    });

    test('lowercase letters are not ULIDs', () {
      expect(TypeInference.infer('01hx0v9r5n6e8l3p7q8s9u2x4b'), FrontmatterType.text);
    });

    test('detects YYYY-MM-DD as date', () {
      expect(TypeInference.infer('2026-05-13'), FrontmatterType.date);
    });

    test('detects integers as number', () {
      expect(TypeInference.infer(420000), FrontmatterType.number);
    });

    test('detects doubles as number', () {
      expect(TypeInference.infer(3.14), FrontmatterType.number);
    });

    test('detects booleans as checkbox', () {
      expect(TypeInference.infer(true), FrontmatterType.checkbox);
      expect(TypeInference.infer(false), FrontmatterType.checkbox);
    });

    test('detects lists as multi', () {
      expect(TypeInference.infer(['logistics', 'enterprise']), FrontmatterType.multi);
    });

    test('falls back to text for other strings', () {
      expect(TypeInference.infer('Diego'), FrontmatterType.text);
    });

    test('null falls back to text', () {
      expect(TypeInference.infer(null), FrontmatterType.text);
    });
  });

  group('TypeInference helpers', () {
    test('isUlid', () {
      expect(TypeInference.isUlid('01HX0V9R5N6E8L3P7Q8S9U2X4B'), isTrue);
      expect(TypeInference.isUlid('hello'), isFalse);
    });

    test('isDate', () {
      expect(TypeInference.isDate('2026-05-13'), isTrue);
      expect(TypeInference.isDate('2026/05/13'), isFalse);
      expect(TypeInference.isDate('2026-5-13'), isFalse);
    });
  });
}
