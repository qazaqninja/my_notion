/// Locking is a pure-function check on the EditorLoaded state — easy to
/// exercise without spinning up the bloc.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/presentation/bloc/editor_bloc.dart';
import 'package:my_notion/features/editor/presentation/bloc/editor_state.dart';
import 'package:my_notion/features/vault/domain/entities/frontmatter.dart';
import 'package:my_notion/features/vault/domain/entities/frontmatter_entry.dart';
import 'package:my_notion/features/vault/domain/entities/page.dart';

void main() {
  EditorLoaded build(Frontmatter fm) {
    return EditorLoaded(
      page: Page(
        ulid: '01HX0V9R5N6E8L3P7Q8S9U2X4B',
        relativePath: 'p.md',
        title: 'P',
        frontmatter: fm,
        body: '',
      ),
      mode: EditorMode.rendered,
      dirty: false,
      saving: false,
    );
  }

  test('isLocked: missing key → false', () {
    expect(EditorBloc.isLocked(build(const Frontmatter(entries: []))), isFalse);
  });

  test('isLocked: bool true → true', () {
    final loaded = build(const Frontmatter(entries: [
      FrontmatterEntry(
          key: 'locked',
          rawScalar: 'true',
          type: FrontmatterType.checkbox,
          value: true),
    ]));
    expect(EditorBloc.isLocked(loaded), isTrue);
  });

  test('isLocked: string "true" → true', () {
    final loaded = build(const Frontmatter(entries: [
      FrontmatterEntry(
          key: 'locked',
          rawScalar: 'true',
          type: FrontmatterType.text,
          value: 'true'),
    ]));
    expect(EditorBloc.isLocked(loaded), isTrue);
  });

  test('isLocked: bool false → false', () {
    final loaded = build(const Frontmatter(entries: [
      FrontmatterEntry(
          key: 'locked',
          rawScalar: 'false',
          type: FrontmatterType.checkbox,
          value: false),
    ]));
    expect(EditorBloc.isLocked(loaded), isFalse);
  });
}
