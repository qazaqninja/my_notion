/// Exercises EditorBloc's private _stampAuthor pure function via a test
/// shim. The bloc class exposes it through a public accessor for tests
/// only — keeping the logic verifiable without spinning up the full
/// bloc + file I/O.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/presentation/bloc/editor_bloc.dart';
import 'package:my_notion/features/vault/domain/entities/frontmatter.dart';
import 'package:my_notion/features/vault/domain/entities/frontmatter_entry.dart';

Frontmatter _fmWith(Map<String, String> kv) {
  return Frontmatter(entries: [
    for (final e in kv.entries)
      FrontmatterEntry(
        key: e.key,
        rawScalar: e.value,
        type: FrontmatterType.text,
        value: e.value,
      ),
  ]);
}

String? _read(Frontmatter fm, String key) {
  for (final e in fm.entries) {
    if (e.key == key) return '${e.value}';
  }
  return null;
}

void main() {
  group('EditorBloc.stampAuthor', () {
    test('adds both created_by and last_edited_by on a virgin page', () {
      final out = EditorBloc.stampAuthor(_fmWith({}), 'Alice');
      expect(_read(out, 'last_edited_by'), 'Alice');
      expect(_read(out, 'created_by'), 'Alice');
      // M317: last_edited_at is also stamped as ISO date.
      expect(_read(out, 'last_edited_at'),
          matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    test('preserves an existing created_by, updates last_edited_by', () {
      final fm = _fmWith({'created_by': 'Bob', 'last_edited_by': 'Bob'});
      final out = EditorBloc.stampAuthor(fm, 'Alice');
      expect(_read(out, 'created_by'), 'Bob');
      expect(_read(out, 'last_edited_by'), 'Alice');
    });

    test('updates last_edited_by even when created_by is missing', () {
      final fm = _fmWith({'last_edited_by': 'Bob'});
      final out = EditorBloc.stampAuthor(fm, 'Alice');
      expect(_read(out, 'last_edited_by'), 'Alice');
      // created_by gets backfilled to the same author.
      expect(_read(out, 'created_by'), 'Alice');
    });

    test('does not duplicate keys when last_edited_by is already present',
        () {
      final fm = _fmWith({
        'last_edited_by': 'Bob',
        'created_by': 'Bob',
      });
      final out = EditorBloc.stampAuthor(fm, 'Alice');
      final last =
          out.entries.where((e) => e.key == 'last_edited_by').toList();
      final created =
          out.entries.where((e) => e.key == 'created_by').toList();
      expect(last.length, 1);
      expect(created.length, 1);
    });
  });
}
